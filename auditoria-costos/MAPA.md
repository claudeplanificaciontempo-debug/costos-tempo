# MAPA — De dónde viene cada dato y cómo se calcula el costo

Auditoría del sistema **Costos TEMPO**.
Estado congelado en la rama `pre-auditoria-costos` (commit `54a62eb`).
Todas las referencias `index.html:NNN` apuntan a ese estado exacto.

---

## 0. Advertencia de alcance — leer antes que nada

El pedido de auditoría describe un sistema de **costeo de producción textil por orden de
producción (OP)**: telas tejidas TEJ, OPs de servicio de tintorería TIN, tela tinturada,
prendas con subproductos por talla, producto en proceso, y kilos/unidades mes a mes de
enero a julio 2026.

**Ese sistema no existe en este repositorio.** No es que esté incompleto: no hay ni una
línea de código para nada de eso. Lo verifiqué buscando en todo el archivo:

| Concepto del pedido | ¿Existe en el código? | Evidencia |
|---|---|---|
| Orden de producción (OP) | **No** | No hay ninguna entidad, tabla, campo ni variable de OP |
| Clasificación TEJ / TIN de OPs | **No** | «TEJ» solo aparece dentro de nombres de familias de material (`MP-CUELLOSTEJID` «CUELLOS TEJIDOS», `index.html:912`) y como categoría de producto `'TEJIDOS'` (`index.html:757`). Nunca como tipo de OP |
| Kg de tela tejida / tinturada | **No** | No hay ninguna magnitud en kg. La unidad de medida (`um`) de las 42 familias de MP importadas es `'u'` (`index.html:894-962`) |
| Consumo de hilo y químicos de tejeduría/tintorería | **No** | `IN-HILOPARACOSE` es hilo de **coser** (insumo de confección), no hilo de tejeduría. No hay químicos |
| Subproductos por talla | **No** | No hay dimensión de talla en ninguna parte del modelo |
| Producto en proceso (WIP) | **No** | No hay inventario, ni saldos, ni valoración de existencias |
| Datos mensuales ene–jul 2026 | **No** | No hay ninguna dimensión de tiempo/periodo. El único campo temporal por producto es `anio` + `temporada` (texto libre, `index.html:1619-1623`) |
| Carga desde archivos de Odoo | **Parcial, una sola vez, a mano** | Ver §1.2 |

**Lo que sí es este sistema:** una aplicación de **ficha de costo unitario por prenda**
(costo estándar por referencia, no costo real por OP). Calcula, para *una prenda* de *una
referencia*: materiales + insumos + decoración + servicios + mano de obra, y a partir de
ese costo propone precios de venta por cliente.

Todo lo que sigue documenta **el sistema real**. Donde el pedido menciona algo que no
existe, lo digo explícitamente en vez de inventar un equivalente.

---

## 1. Arquitectura en una página

Es **un solo archivo**: `index.html` (2.784 líneas, 481 KB). No hay build, ni backend
propio, ni dependencias npm. Todo el código vive entre `index.html:737` (`<script>`) y
`index.html:2782` (`</script>`).

```
                 ┌──────────────────────────────────────────┐
                 │  index.html  (el programa Y la semilla)   │
                 │  · constantes de negocio (líneas 741-1147)│
                 │  · lógica de cálculo (1161-1173)          │
                 │  · interfaz + persistencia                │
                 └───────────────┬──────────────────────────┘
                                 │ al abrir: tomarSemilla() (2776)
                                 ▼
   ┌─────────────────┐   entrar() ┌──────────────────────────────┐
   │  localStorage    │◄──────────│  Supabase (PostgreSQL + Auth) │
   │  costos_tempo_v1 │  autosave │  oepsutldxratrvozpulq         │
   │  (copia local)   │──────────►│  8 tablas cst_* + cst_versiones│
   └─────────────────┘  syncPush  │  + perfiles + bucket cst-fotos │
                                  └──────────────────────────────┘
```

Variables globales que sostienen todo el estado en memoria (`index.html:741-1152`):

| Variable | Qué contiene | Línea |
|---|---|---|
| `REFS` | Productos / referencias | 773 |
| `FICHAS` | Ficha de costo de cada referencia (consumos, tiempos, precios) | 1127 |
| `CAT` | Catálogo de materiales (precio unitario) | 816 (+ `CAT_ODOO` 893, fusionado en 964) |
| `CEN` | Centros de costo y sus tarifas MOD/MOI | 1108 |
| `CLI` | Clientes y sus metas de margen | 1118 |
| `CATEG` | Árbol categoría → tipo de producto | 745 |
| `PANTONES` | Paleta de colores | 966 |
| `RECETAS`, `REC_BASE` | Consumos sugeridos por tipo de producto | 1036-1081 |
| `FOTO` | Fotos por referencia (base64 o URL) | 739 |
| `MARCAS`, `TEMPORADAS`, `DEPS` | Listas auxiliares | 743, 744, 742 |
| `TOT` | Resultado del último `calc()` — **se pisa en cada cálculo** | 1152 |

---

## 2. De dónde viene cada dato y cómo se carga

### 2.1 Orden de precedencia al abrir la aplicación

`index.html:2776-2781` y `entrar()` en `index.html:1833-1861`:

1. `tomarSemilla()` (`2776`, definida en `2055`) guarda una copia de las constantes del
   archivo en `SEED`.
2. `refrescar()` (`1777`) intenta renovar la sesión guardada en
   `localStorage['costos_tempo_sesion']`. Si no hay, muestra el login (`2780`).
3. Si hay marca de cambios pendientes de la sesión anterior y tiene menos de **3 días**
   (`1837-1838`), se carga **localStorage** y se reintenta subir (`1840-1845`).
4. Si no, se carga la **nube** con `cargarNube()` (`1883`). La nube **pisa por completo**
   `REFS`, `CAT`, `FICHAS` (`1903-1908`); `CEN`, `CLI`, `MARCAS`, `PANTONES`,
   `TEMPORADAS` solo si vienen no vacías (`1905-1911`).
5. Si la nube falla, se cae a `cargarLocal()` **en modo solo lectura** (`1847-1853`).
6. En cualquier caso corre `fusionarSemilla()` (`2057`): agrega del archivo lo que no
   esté en la nube, **nunca pisa lo existente**.

> Consecuencia: el archivo `index.html` **no es solo código, es también la semilla de
> datos**. Cada despliegue puede introducir productos y materiales nuevos en la base.

### 2.2 Origen real de cada dato

| Dato | Origen | Cómo se carga hoy | Línea |
|---|---|---|---|
| **Catálogo de materiales MP e Insumos** (68 familias) | **Odoo**, archivo `cate.xlsx`, hoja `MP-IN`. El commit `182bc0e` dice «765 items»; quedaron agrupados en **una fila por familia** | **Manual, una sola vez.** Alguien convirtió el Excel a literales JS y los pegó como `CAT_ODOO`. **No hay conector, API ni importador con Odoo.** Para actualizar hay que volver a editar el HTML o usar «Carga masiva» pegando desde Excel | 889-963 |
| **Paleta de pantones** (60) | Odoo, `cate.xlsx`, hoja `Pantones` | Igual: pegado a mano como literal | 965-1027 |
| **Precio unitario de cada material** | **Nadie: viene en 0** | Los 69 ítems de `CAT_ODOO` tienen `p:0`. Se editan a mano en la pantalla *Materiales* (`setPrecio`, `2359`) | 894-962 |
| **Decoración** (68 técnicas de serigrafía/bordado) | Tarifario interno TEMPO, fechado `8-sep-2026` / `provisional` | Literal en el archivo | 817-884 |
| **Servicios** (4) | Tarifario interno, `12-ago-2026` | Literal | 885-887, 961 |
| **Productos / referencias** (38) | Colección Aeropostale, cargados a mano | Literal + pantalla *Productos* + «Carga masiva» pegando desde Excel (`2292`) | 773-812 |
| **Consumos de cada ficha** | **Los teclea una persona** en la pantalla *Ficha de costos* | `setV()` (`1234`). 8 referencias traen consumos precargados en `PRE` (`1137-1146`); las otras 30 arrancan de la receta sugerida | 1137-1147 |
| **Tiempos por centro (min / puntadas)** | **Los teclea una persona** | `cenVal()` (`1333`) | 1313-1333 |
| **Tarifas MOD / MOI** | Nómina TEMPO, vigencia `01-ago-2026` | Literal `CEN`; editables en *Centros y tarifas* (`setTar`, `2554`) | 1108-1114 |
| **Metas de margen por cliente** | Comercial TEMPO | Literal `CLI`; editables (`setCli`, `2489`) | 1118-1124 |
| **Fotos** | Subidas por el usuario (archivo suelto, lote, o «plancha» recortada automáticamente) | `subirFotos` (`1728`), `detectar` (`2199`); se reducen a 440 px WebP (`1742`) | 1721-1750 |
| **Usuarios y roles** | Tabla `perfiles` en Supabase | `perfil()` (`1823`) | 1823-1831 |

### 2.3 Dónde viven los datos hoy

| Tabla Supabase | Qué guarda | Se arma en |
|---|---|---|
| `cst_productos` | Referencias | `filas()` `1872` |
| `cst_materiales` | Catálogo de materiales | `1873` |
| `cst_centros` | Centros y tarifas | `1874` |
| `cst_clientes` | Clientes y metas | `1875` |
| `cst_fichas` | **La ficha completa** (consumos, tiempos, precios, estado) | `1876` |
| `cst_marcas` | Marcas | `1877` |
| `cst_pantones` | Pantones | `1878` |
| `cst_temporadas` | Temporadas | `1879` |
| `cst_versiones` | Histórico de cada versión guardada | `guardarVersion()` `1986-1993` |
| `perfiles` | Usuario, nombre, rol | `1826`, `2465` |
| bucket `cst-fotos` | Imágenes | `subirFotoNube()` `1925` |

Todas las `cst_*` tienen la **misma forma**: `id` (texto) + `data` (JSON con todo
adentro) + `actualizado` (timestamp, usado en `2105`). **No hay columnas tipadas ni
relaciones declaradas en la base**: la integridad depende del navegador.

---

## 3. El flujo de cálculo, paso a paso

### 3.1 El motor: `calc()` — `index.html:1161-1173`

Es la **única** función de cálculo de costo del sistema. Todo lo demás la llama.

```
Paso 1 · Arranca todos los acumuladores en cero.                        línea 1163
        TOT = {mp, ins, dec, srv, mo, moi, sam, total, ncen}

Paso 2 · Recorre las líneas de material de la ficha.                    línea 1164
        Para cada línea:
          busca el material en el catálogo por su código
          SI NO LO ENCUENTRA → la línea se SALTA EN SILENCIO   ← ver VALORES_FIJOS.md
          si lo encuentra:
            costo_linea = consumo × (1 + desperdicio% ÷ 100) × precio_unitario
            suma costo_linea al acumulador de SU tipo (mp / ins / dec / srv)

Paso 3 · Recorre los centros de costo.                                  líneas 1165-1171
        Salta el centro si está apagado o su valor es 0.
        Si el centro se mide en PUNTADAS:
            MOD += (puntadas ÷ 1000) × tarifa_MOD
            MOI += (puntadas ÷ 1000) × tarifa_MOI
            (los minutos NO se suman al SAM)
        Si se mide en MINUTOS:
            MOD += minutos × tarifa_MOD
            MOI += minutos × tarifa_MOI
            SAM += minutos

Paso 4 · Suma final.                                                    línea 1172
        COSTO TOTAL = MP + Insumos + Decoración + Servicios + MOD + MOI
```

**En lenguaje simple:** el costo de una prenda es *lo que consume* (cantidad × precio de
lista, inflada por el % de desperdicio) más *el tiempo que tarda* (minutos × tarifa de
mano de obra directa e indirecta de cada centro por el que pasa).

Detalle importante de `precio(l,m)` — `index.html:1031`:

> Si el material es de tipo **servicio** (`srv`) y la línea trae un precio propio, se usa
> **el precio de la línea**, no el del catálogo. Para todo lo demás manda el catálogo.
> Es el único lugar donde un precio se puede sobrescribir por ficha.

### 3.2 Del costo al precio de venta — `basePvp()` y `plCalc()`

`index.html:1354-1368`.

```
Paso 1 · Precio base (el del PRIMER cliente de la lista, CLI[0] = Fashion Club):
         si el usuario fijó el PVP a mano → ese PVP                     línea 1356
         si no → PVP = costo ÷ (1 − margen_meta ÷ 100)
         (si el margen es ≥ 100 %, devuelve 0 — no avisa)

Paso 2 · Para cada cliente:                                             líneas 1358-1368
         · Cliente "sobre base" (Aero Dep):
              PVP = PVP_base × (1 + recargo% ÷ 100)
              es decir: precio del cliente base + 5 %, NO un margen propio
         · Cualquier otro cliente:
              PVP = costo ÷ (1 − margen_meta ÷ 100)

Paso 3 · Indicadores:
         margen_real_% = (PVP − costo) ÷ PVP × 100
         ganancia      = PVP − costo
         PVP_minimo    = costo ÷ (1 − meta ÷ 100)
```

**En lenguaje simple:** el margen es **sobre precio de venta**, no sobre costo. Un 30 %
de meta significa que el costo debe ser el 70 % del PVP, así que se divide por 0,70.

### 3.3 Guardar una ficha — `guardar()` — `index.html:1453-1468`

```
Paso 1 · Si el usuario es rol "prearmado": marca la ficha como pendiente
         de aprobación y termina. No calcula ni cierra nada.            líneas 1455-1460
Paso 2 · Si la ficha ya estaba guardada y está en re-costeo, sube la versión (+1). 1461
Paso 3 · Marca saved=true, edit=false, fecha=hoy.                                 1462
Paso 4 · Agrega al historial: {versión, fecha, total, SAM, PVP base}.             1464
Paso 5 · Llama a guardarVersion(ref), que sube a cst_versiones un registro con
         consumos, tiempos, total, SAM y PVPs.                                    1986
```

> **El texto de la pantalla (`index.html:1517`) dice que «quedan congelados los costos del
> catálogo y las tarifas de mano de obra de hoy». Eso no ocurre.** Ver
> `REGLAS_NEGOCIO.md` § Hallazgo H-1.

### 3.4 Los cinco tipos de costeo que pide la auditoría

Ninguno de los cinco existe como tal. Esto es lo más cercano que hay, y lo que falta:

#### a) Tela tejida (TEJ)

- **No hay costeo de tela.** La tela es un **material comprado** del catálogo con un
  precio unitario plano (`CAT`, campo `p`). En la ficha entra como una línea más:
  `consumo × (1 + desperdicio) × precio` (`index.html:1164`).
- No existe explosión de tela en hilo + químicos, ni rendimiento, ni merma de tejeduría.
- Hoy, además, **las 42 familias de tela tienen precio 0** (`index.html:894-962`), así
  que su aporte al costo es literalmente `$0.00` — ver `datos/costo_unitario_calculado.csv`.
- Unidad de medida: `'u'`, no kg.

#### b) Servicio de tintorería (OP TIN)

- **No hay OP de servicio.** Lo más cercano son dos materiales de tipo `srv`:
  - `SV-TIN001` «Tinturado de la tela», `$0,48` por prenda (`index.html:885`)
  - `SV-TINTURADOIND` «TINTURADO INDUSTRIAL», `$0` por unidad (`index.html:961`)
- Se cargan como una línea más de la ficha y suman al acumulador `srv` (`1164`).
- El costo del servicio es **un precio plano tecleado**, no el resultado de sumar
  químicos + mano de obra de tintorería. No hay consumo de químicos en ningún lado.
- Las 8 fichas precargadas traen `['SV-TINTURADOIND', 0, 0]` — el servicio está
  presente **con consumo 0**, o sea aporta `$0` sin avisar (`index.html:1138-1145`).

#### c) Tela tinturada

- Existe como **una familia de material más**: `MP-TELAIMPORTAD` «TELA IMPORTADA
  TINTURADA» (`index.html:960`), precio 0.
- **No hay relación entre tela cruda y tela tinturada.** El sistema no sabe que una
  tela tinturada = tela cruda + servicio de tintura. Son dos ítems de catálogo
  independientes, y nada impide cargar los dos en la misma ficha.

#### d) Prendas con subproductos por talla

- **No existe la dimensión talla.** No hay campo, tabla ni cálculo de tallas.
- La unidad de costeo es **una prenda promedio de la referencia**, sin curva de tallas.
- Por lo tanto tampoco hay reparto de costo entre tallas: no es que todo se cargue a la
  primera talla, es que las tallas no se modelan. Ver `REGLAS_NEGOCIO.md` § R-3.

#### e) Producto en proceso (WIP)

- **No existe.** No hay inventario, ni saldos, ni valoración, ni movimientos.
- El sistema es puramente de **costo estándar unitario prospectivo**: dice cuánto
  *debería* costar una prenda, no cuánto hay invertido en planta.

---

## 4. Todas las fórmulas del sistema, en lenguaje simple

| # | Fórmula | En palabras | Archivo:línea |
|---|---|---|---|
| F-1 | `costo_linea = q × (1 + d/100) × precio` | Consumo por unidad, inflado por el % de desperdicio, por el precio unitario del material | `index.html:1164` |
| F-2 | `precio = (tipo=='srv' && linea.p != null) ? linea.p : material.p` | Los servicios pueden llevar precio propio por ficha; el resto usa el precio del catálogo | `index.html:1031` |
| F-3 | `MOD += minutos × tarifa_MOD` | Mano de obra directa de un centro medido en minutos | `index.html:1170` |
| F-4 | `MOI += minutos × tarifa_MOI` | Mano de obra indirecta (CIF absorbido por minuto) del mismo centro | `index.html:1170` |
| F-5 | `MOD += (puntadas / 1000) × tarifa_MOD` | Bordado: la tarifa es por cada mil puntadas | `index.html:1169` |
| F-6 | `SAM += minutos` | Minutos totales de la prenda. **Los centros por puntadas no suman al SAM** | `index.html:1170` |
| F-7 | `total = mp + ins + dec + srv + mo + moi` | Costo total unitario de la prenda | `index.html:1172` |
| F-8 | `PVP = costo / (1 − margen/100)` | Precio para alcanzar un margen **sobre precio de venta** | `index.html:1356`, `1365` |
| F-9 | `PVP = PVP_base × (1 + recargo/100)` | Cliente ligado: precio del cliente base más un recargo | `index.html:1364` |
| F-10 | `margen_real = (PVP − costo) / PVP × 100` | Margen efectivo sobre PVP | `index.html:1366` |
| F-11 | `ganancia = PVP − costo` | Ganancia por prenda | `index.html:1368` |
| F-12 | `PVP_minimo = costo / (1 − meta/100)` | Precio mínimo para no bajar de la meta | `index.html:1368` |
| F-13 | `recargo_implicito = (PVP / PVP_base − 1) × 100` | Si se fija el PVP a mano en un cliente ligado, se deduce el recargo | `index.html:1363` |
| F-14 | `meta_heredada = meta_del_base + puntos_extra` | Cliente vinculado por puntos de margen (no por precio) | `index.html:2480` |
| F-15 | `tarifa_promedio = Σ(MOD+MOI de centros por minuto) / nº de centros por minuto` | Promedio **simple**, no ponderado | `index.html:2428` |
| F-16 | `tarifa_ponderada = Σ USD de todos los centros / Σ minutos de todos los centros` | Tarifa real según los minutos efectivamente cargados | `index.html:2431` |
| F-17 | `desvio_% = (tarifa_actual − tarifa_nomina) / tarifa_nomina × 100` | Compara la tarifa vigente contra la referencia de nómina fija en el código | `index.html:2443` |
| F-18 | `subtotal_categoria = Σ (q × (1+d/100) × precio)` de las líneas de ese tipo | Subtotal por grupo (MP / Insumos / Decoración / Servicios) en la tabla | `index.html:1207` |
| F-19 | `participacion_% = TOT[k] / TOT.total × 100` | Peso de cada componente en el costo | `index.html:1350` |
| F-20 | `foto: escala = min(1, 440 / alto_original)` | Reducción de fotos a 440 px de alto, WebP calidad 0,8 | `index.html:1744-1747` |

### 4.1 Fórmulas que la auditoría espera y **no existen**

| Fórmula esperada | Estado |
|---|---|
| `costo_tela = (kg_hilo × precio_hilo + químicos) / kg_producidos` | **No existe** |
| `costo_OP_TIN = químicos + MOD_tintorería` | **No existe** |
| `costo_tela_tinturada = costo_tela_cruda + costo_servicio_TIN` | **No existe** |
| Reparto de costo entre tallas / subproductos | **No existe** |
| Valoración de producto en proceso | **No existe** |
| Costo real por OP vs. costo estándar | **No existe** (solo hay estándar) |

---

## 5. Recorrido completo de un dato, de punta a punta

Ejemplo real: la referencia **4823 · CAMISETA ML RIBB CUELLO REDONDO**.

1. Nace como literal en `REFS` (`index.html:774`), categoría `CAMISETAS`, tipo `Camiseta ML`.
2. Su ficha se precarga desde `PRE['4823']` (`index.html:1138`): 5 líneas de material
   (`MP-RIBB2X2LIVIA` 0,245 · `IN-HILOPARACOSE` 0,014 · `IN-ETIQUETAS` 1 ·
   `IN-SATIN` 1 · `SV-TINTURADOIND` 0) y 3 centros (corte 0,95 min · confección 9,80 min ·
   empaque 1,25 min).
3. `nuevaFicha()` (`1128`) arma la estructura: líneas, centros (todos los de `CEN`),
   lista de precios por cliente, versión 1, `saved:false`.
4. Al dibujar, `draw()` (`1430`) llama a `calc()` (`1161`).
5. `calc()` busca cada material en `CAT`. Los cinco existen. **Los cinco tienen precio 0**
   (`index.html:894-962`), así que MP = Insumos = Servicios = **$0,00**.
6. Los 3 centros activos aportan: 12,00 minutos × tarifas de `CEN` →
   **MOD $2,2212 + MOI $0,6672**.
7. `total` = **$2,8884** — de los cuales el **100 % es mano de obra**.
8. `plCalc(0)` (`1358`): PVP Fashion Club = 2,8884 / (1 − 0,30) = **$4,13**.
9. `autosave()` (`2000`) escribe todo el estado en `localStorage` y, 900 ms después,
   lo sube a Supabase con `syncPush()` (`1942`).

Los 38 recorridos equivalentes están calculados en
**`datos/costo_unitario_calculado.csv`**.

> **Resultado agregado del estado actual del repositorio: MP $0,00 · Insumos $0,00 ·
> Servicios $0,00 · MOD $14,54 · MOI $4,37.** El costo de material de toda la colección
> es cero y el sistema no lo advierte en ninguna pantalla.

---

## 6. Qué mira cada pantalla

| Pantalla | Función | Lee | Línea |
|---|---|---|---|
| Ficha de costos | `draw()` | `FICHAS[cur]`, `CAT`, `CEN`, `CLI` | 1430 |
| Productos | `rowsProd()` → `totRef()` | Recalcula **en vivo** cada referencia | 1639, 1174 |
| Materiales | `rowsCatMat()` | `CAT`, `PANTONES` | 2348 |
| Centros y tarifas | `rowsCentros()`, `resumenFabrica()` | `CEN`, todas las `FICHAS` | 2509, 2409 |
| Lista de precios | `rowsLista()` | Solo fichas con `saved`, **recalculadas en vivo** | 2581 |
| Exportar por cliente | `rowsExp()` | Todas las activas, recalculadas en vivo | 2644 |

> Nótese el patrón `cur = x.r; calc(); ... ; cur = g; calc();` (`1174`, `2418`, `2592`,
> `2651`): para costear otra referencia se **cambia la referencia global, se calcula, y se
> restaura**. Funciona, pero significa que **cada pintado de la lista de productos
> recalcula las 38 fichas completas**, siempre con precios y tarifas de hoy.
