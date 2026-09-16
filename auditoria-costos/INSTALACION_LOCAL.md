# INSTALACIÓN LOCAL — Cómo correr Costos TEMPO contra una base propia

Estado auditado: rama `pre-auditoria-costos` (commit `54a62eb`).

> Esta guía **no modifica el sistema**. Describe qué hace falta y en qué orden.
> El paso 5 (apuntar la aplicación a la base local) **sí requiere tocar código** y queda
> explícitamente fuera de esta auditoría: se indica qué habría que cambiar, no se cambia.

---

## 1. Qué se necesita

### 1.1 Lo mínimo, para consultar los datos en una base local

| Componente | Versión | Para qué |
|---|---|---|
| **PostgreSQL** | 14 o superior | El motor. Es el mismo que usa Supabase hoy, así que no hay cambio de tecnología |
| `psql` | la que traiga PostgreSQL | Crear el esquema y cargar los CSV |

Con esto ya se puede cargar `ESQUEMA.sql` + los CSV de `datos/` y consultar, reportar y
auditar. **No hace falta nada más para eso.**

### 1.2 Si además se quiere correr la aplicación contra esa base

| Componente | Versión | Para qué |
|---|---|---|
| Un servidor web estático | cualquiera | `index.html` necesita servirse por `http://`, no abrirse como `file://` (la autenticación y `fetch` no funcionan con `file://`) |
| **Supabase self-hosted** *(opción A)* | Docker Compose oficial | Es lo único que funciona **sin tocar el código**: la aplicación habla PostgREST + GoTrue + Storage |
| **o** un backend propio *(opción B)* | — | Habría que reescribir las ~15 llamadas de red del archivo. Ver §5.2 |

Para la opción A: **Docker** y **Docker Compose**.

### 1.3 Dependencias de la aplicación

**Ninguna.** No hay `package.json`, ni `node_modules`, ni build, ni framework. `index.html`
es un archivo autocontenido de 2.784 líneas con todo adentro: HTML, CSS y JavaScript.

Las únicas dependencias externas en tiempo de ejecución son los tres servicios de Supabase:

| Servicio | Endpoint que usa | Línea |
|---|---|---|
| Auth (GoTrue) | `/auth/v1/token`, `/auth/v1/user` | 1774, 1814 |
| REST (PostgREST) | `/rest/v1/<tabla>` | 1783, 1786, 1791 |
| Storage | `/storage/v1/object/cst-fotos/…` | 1930, 1933 |

> **Node.js no hace falta para correr la aplicación.** Solo lo usé para generar los CSV de
> `datos/` a partir del archivo (ver `datos/LEEME.md`).

---

## 2. Instalación paso a paso

### Paso 1 · Instalar PostgreSQL

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y postgresql postgresql-client

# macOS
brew install postgresql@16 && brew services start postgresql@16

# Windows: instalador oficial de postgresql.org, o
winget install PostgreSQL.PostgreSQL.16
```

Comprobar:

```bash
psql --version
```

### Paso 2 · Crear la base y el usuario

```bash
sudo -u postgres psql
```

```sql
CREATE ROLE costos_app WITH LOGIN PASSWORD 'cambiar_esta_clave';
CREATE DATABASE costos_tempo OWNER costos_app ENCODING 'UTF8'
  LC_COLLATE 'es_EC.UTF-8' LC_CTYPE 'es_EC.UTF-8' TEMPLATE template0;
\q
```

> Si el sistema no tiene la configuración regional `es_EC.UTF-8`, sirve cualquier
> `*.UTF-8`. Lo importante es **UTF-8**: los datos tienen tildes y `Ñ`
> (`'Niño'`, `'PUÑOS TEJIDOS'`, `'MOÑO BORDADO'`).

### Paso 3 · Crear la estructura

```bash
psql -U costos_app -d costos_tempo -f auditoria-costos/ESQUEMA.sql
```

Esto crea el esquema `costos` con:
- **PARTE 1** — las 10 tablas tal como existen hoy en la nube (`id` + `data` JSON),
  para poder volcar los datos actuales sin perder nada;
- **PARTE 2** — el modelo normalizado y tipado, con claves foráneas y restricciones;
- **PARTE 4** — las vistas que reproducen `calc()` y `plCalc()` en SQL, más las vistas
  de control de calidad (`qc_*`).

La **PARTE 3** (carga de los CSV) viene comentada a propósito: se ejecuta en el paso 4.

### Paso 4 · Cargar los datos

#### Opción A — cargar los CSV de esta auditoría (estado de la semilla del repositorio)

```bash
cd auditoria-costos
psql -U costos_app -d costos_tempo
```

Dentro de `psql`, descomentar y ejecutar el bloque de la PARTE 3 de `ESQUEMA.sql`, o
pegarlo tal cual. Los `\copy` son relativos a la carpeta desde la que se abrió `psql`,
por eso hay que estar en `auditoria-costos/`.

Comprobación rápida:

```sql
SET search_path TO costos, public;
SELECT count(*) FROM producto;          -- esperado: 38
SELECT count(*) FROM material;          -- esperado: 140
SELECT count(*) FROM ficha_linea;       -- esperado: 216
SELECT count(*) FROM qc_material_sin_precio;  -- esperado: 69  ← ver REGLAS_NEGOCIO H-2
SELECT round(sum(costo_total_usd),2) FROM v_costo_unitario;  -- esperado: 18.91
```

Si el último número da **18,91**, la vista SQL reproduce exactamente `calc()`.

> ⚠️ **Estos CSV son la semilla del repositorio, no la producción.** Ver `datos/LEEME.md`
> y `SUPUESTOS.md` §2. Para los datos reales, usar la opción B o la C.

#### Opción B — traer los datos reales desde Supabase (recomendado)

La forma **más segura y sin instalar nada**, porque la hace la propia aplicación:

1. Entrar a la aplicación con un usuario **admin**.
2. Ir a *Centros y tarifas* → tarjeta **Respaldo** → **Descargar respaldo**
   (`respaldo()`, `index.html:2179`).
3. Se baja un `Costos_TEMPO_respaldo_AAAA-MM-DD.json` con `REFS`, `FICHAS`, `CAT`, `CEN`,
   `CLI` y `FOTO`.

> ⚠️ Ese respaldo **no incluye `MARCAS`, `TEMPORADAS` ni `PANTONES`**
> (`estado()`, `index.html:1997`). Ver `VALORES_FIJOS.md` B-11. Hay que exportarlas aparte
> con la opción C, o volver a capturarlas.

Cargar ese JSON a PostgreSQL:

```sql
-- Volcar el respaldo entero en una tabla de trabajo
CREATE TEMP TABLE _respaldo (doc jsonb);
\set contenido `cat Costos_TEMPO_respaldo_2026-09-16.json`
INSERT INTO _respaldo VALUES (:'contenido'::jsonb);

-- Productos
INSERT INTO costos.producto (referencia, nombre, categoria, tipo_producto,
                             marca, departamento, anio, temporada, archivado, orden)
SELECT x->>'r', x->>'n', x->>'cat', x->>'sub',
       NULLIF(x->>'marca',''), NULLIF(x->>'dep',''),
       NULLIF(x->>'anio',''),  NULLIF(x->>'temporada',''),
       COALESCE((x->>'arch')::boolean,false), ord
FROM _respaldo, jsonb_array_elements(doc->'REFS') WITH ORDINALITY AS t(x, ord);

-- Materiales
INSERT INTO costos.material (codigo, descripcion, tipo, unidad_medida,
                             costo_unitario, fecha_costo_texto, fecha_costo, familia)
SELECT x->>'c', x->>'d', x->>'k', x->>'um',
       COALESCE((x->>'p')::numeric,0), x->>'f',
       costos.fecha_es(x->>'f'), NULLIF(x->>'fam','')
FROM _respaldo, jsonb_array_elements(doc->'CAT') AS x;

-- Líneas de ficha
INSERT INTO costos.ficha_linea (referencia, linea, codigo_material,
                                consumo, desperdicio_pct, precio_servicio, pantone)
SELECT f.key, ord, l->>'c',
       COALESCE((l->>'q')::numeric,0), COALESCE((l->>'d')::numeric,0),
       (l->>'p')::numeric, NULLIF(l->>'pan','')
FROM _respaldo,
     jsonb_each(doc->'FICHAS') AS f,
     jsonb_array_elements(f.value->'lines') WITH ORDINALITY AS t(l, ord);

-- Tiempos por centro
INSERT INTO costos.ficha_centro (referencia, centro_id, activo, valor)
SELECT f.key, c.key,
       COALESCE((c.value->>'on')::boolean,false),
       COALESCE((c.value->>'val')::numeric,0)
FROM _respaldo,
     jsonb_each(doc->'FICHAS') AS f,
     jsonb_each(f.value->'cen') AS c;
```

Los centros (`CEN`), clientes (`CLI`) y el estado de cada ficha (`ver`, `saved`, `fecha`)
se cargan con el mismo patrón.

#### Opción C — copiar las tablas directamente desde Supabase

Desde un equipo con acceso a la nube, usando la cadena de conexión de PostgreSQL del panel
de Supabase (*Project settings → Database → Connection string*):

```bash
pg_dump "postgresql://postgres:<clave>@db.<proyecto>.supabase.co:5432/postgres" \
  --data-only --table=public.cst_productos --table=public.cst_materiales \
  --table=public.cst_centros --table=public.cst_clientes --table=public.cst_fichas \
  --table=public.cst_marcas --table=public.cst_pantones --table=public.cst_temporadas \
  --table=public.cst_versiones --table=public.perfiles \
  > costos_tempo_datos.sql

psql -U costos_app -d costos_tempo -c "SET search_path TO costos;" -f costos_tempo_datos.sql
```

Esto llena las tablas de la **PARTE 1** del esquema (las de `id` + `data`). Para pasar de
ahí al modelo normalizado de la PARTE 2, las consultas de desempaquetado son las mismas de
la opción B, cambiando `_respaldo` por `cst_productos`, `cst_materiales`, etc.

> Esta opción es la única que trae **`cst_versiones`** (el histórico) y **`perfiles`**
> (los usuarios y sus roles).
>
> Las fotos no vienen en el volcado: viven en el bucket de Storage `cst-fotos`. Hay que
> bajarlas aparte con el CLI de Supabase o desde el panel.

### Paso 5 · Comprobar que la base reproduce el cálculo de la aplicación

Antes de confiar en la base local, hay que verificar que da lo mismo que la aplicación:

```sql
SET search_path TO costos, public;

-- Costo por referencia: debe coincidir con lo que muestra la pantalla Productos
SELECT referencia, nombre, mp_usd, insumos_usd, servicios_usd,
       mod_usd, moi_usd, costo_total_usd, minutos_sam
FROM v_costo_unitario ORDER BY referencia;

-- Precios por cliente: deben coincidir con la Lista de precios
SELECT referencia, cliente, round(pvp,2) FROM v_precio_venta ORDER BY referencia, cliente;
```

Y pasar los controles de calidad, que es de donde salen los problemas reales:

```sql
SELECT * FROM qc_material_sin_precio;             -- materiales con costo 0
SELECT * FROM qc_ficha_sin_materiales;            -- fichas sin una sola línea
SELECT * FROM qc_ficha_sin_tiempos;               -- fichas sin ningún centro activo
SELECT * FROM qc_ficha_con_costo_material_cero;   -- costo 100 % mano de obra
SELECT * FROM qc_material_prefijo_incoherente;    -- código MP- clasificado como insumo
SELECT * FROM qc_posible_doble_conteo_tintura;    -- tela tinturada + servicio de tintura
SELECT * FROM qc_cliente_sin_base;                -- ningún cliente (o más de uno) marcado base
SELECT * FROM qc_version_desfasada;               -- versiones cerradas cuyo costo ya cambió
```

---

## 3. Servir la aplicación en local

```bash
cd /ruta/al/repositorio
python3 -m http.server 8080
# abrir http://localhost:8080/index.html
```

Cualquier servidor estático sirve (`npx serve`, `nginx`, `caddy`). Lo que **no** funciona
es abrir el archivo con doble clic: con `file://`, la autenticación y `fetch` fallan.

Servido así, la aplicación sigue hablando con **la nube de producción**
(`SB_URL`, `index.html:1756`). Para apuntarla a la base local hace falta el paso 4.

---

## 4. Apuntar la aplicación a la base local *(requiere tocar código — fuera de esta auditoría)*

### 4.1 Opción A — Supabase self-hosted (sin reescribir la aplicación)

Es la única ruta que **no obliga a reescribir el código**, porque la aplicación habla los
protocolos de Supabase, no SQL.

```bash
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env     # definir POSTGRES_PASSWORD, JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY
docker compose up -d
```

Después:

1. Crear el esquema y cargar los datos en ese PostgreSQL (pasos 3 y 4).
2. Crear el bucket **público** `cst-fotos` en Storage.
3. Crear la tabla `perfiles` y dar de alta los usuarios con su rol.
4. Definir las políticas RLS. **Esto es indispensable:** `SB_KEY` (`index.html:1757`) es
   una clave *publishable*, pensada para estar a la vista en el navegador. **Toda la
   seguridad real está en las políticas RLS**, que viven en Supabase y **no están en este
   repositorio**, así que esta auditoría no las pudo revisar. Al montar la base local hay
   que **rehacerlas**, no darlas por hechas.
5. Cambiar dos líneas de `index.html`:

```js
// index.html:1756-1757
const SB_URL='http://localhost:8000';          // antes: https://oepsutldxratrvozpulq.supabase.co
const SB_KEY='<ANON_KEY del .env local>';
```

> Recomendación: en vez de editar el literal, leerlo de un `config.js` aparte o de un
> `<meta>`, para que el mismo `index.html` sirva en local y en producción.

### 4.2 Opción B — backend propio

Hay que reimplementar los endpoints que la aplicación consume. Todos los puntos a tocar:

| Función | Qué llama | Línea |
|---|---|---|
| `sbAuth()` | `POST /auth/v1/token?grant_type=password` y `…=refresh_token` | 1773-1776 |
| `cambiarClave()` | `PUT /auth/v1/user` | 1814 |
| `sbGet()` | `GET /rest/v1/<t>?select=id,data` | 1783 |
| `sbUpsert()` | `POST /rest/v1/<t>` con `Prefer: resolution=merge-duplicates` | 1784-1789 |
| `sbDelete()` | `DELETE /rest/v1/<t>?id=eq.<id>` | 1790-1794 |
| `sbGetConFecha()` | `GET /rest/v1/<t>?select=id,actualizado` | 2104-2109 |
| `perfil()` | `GET /rest/v1/perfiles?select=nombre,rol&id=eq.<uid>` | 1826 |
| `rowsUsr()` | `GET /rest/v1/perfiles?select=id,email,nombre,rol&order=creado` | 2465 |
| `setRol()` | `PATCH /rest/v1/perfiles?id=eq.<id>` | 2475 |
| `subirFotoNube()` | `POST /storage/v1/object/cst-fotos/<path>` con `x-upsert` | 1930 |

Son unas 15 llamadas concentradas en un solo bloque del archivo (líneas 1755-1993), así
que el trabajo está acotado. **El `upsert` con `merge-duplicates` es el que hay que
respetar con más cuidado**: `syncPush()` (`1942`) depende de que un `POST` sobre una clave
existente la reemplace en vez de fallar.

---

## 5. Antes de dar la migración por buena

Lista de comprobación, con la referencia al problema que cubre cada punto:

| ✓ | Comprobación | Referencia |
|---|---|---|
| ☐ | `SELECT round(sum(costo_total_usd),2) FROM v_costo_unitario` coincide con la aplicación | — |
| ☐ | `qc_material_sin_precio` está vacía, o cada caso está justificado por escrito | `REGLAS_NEGOCIO` H-2 |
| ☐ | `qc_ficha_sin_tiempos` y `qc_ficha_sin_materiales` están vacías o justificadas | `VALORES_FIJOS` B-3 |
| ☐ | `qc_material_prefijo_incoherente` está vacía | `REGLAS_NEGOCIO` R-4 |
| ☐ | `qc_cliente_sin_base` está vacía (exactamente un cliente base) | `VALORES_FIJOS` A.3 |
| ☐ | Todas las fechas se convirtieron: `SELECT count(*) FROM material WHERE fecha_costo IS NULL AND fecha_costo_texto <> 'provisional'` da 0 | `VALORES_FIJOS` A.9 |
| ☐ | Se exportaron y recargaron `MARCAS`, `TEMPORADAS` y `PANTONES` (el respaldo **no** las trae) | `VALORES_FIJOS` B-11 |
| ☐ | Se conservaron `anio`, `temporada` y `arch` de cada producto (el respaldo **no** los trae) | `VALORES_FIJOS` B-12 |
| ☐ | Se bajaron las fotos del bucket `cst-fotos` | — |
| ☐ | Se trajo `cst_versiones` (solo la opción C la incluye) | `PERSISTENCIA` §2.3 |
| ☐ | Se rehicieron las políticas RLS en la base local | §4.1 punto 4 |
| ☐ | Se decidió qué hacer con el congelamiento de costos **antes** de migrar | `REGLAS_NEGOCIO` H-1 |

> El último punto es el importante: **si se migra tal cual, se migra el problema.** Que los
> costos no queden congelados al cerrar una versión es una decisión del cálculo, no del
> almacenamiento, y cambiar de base de datos no la arregla sola.
