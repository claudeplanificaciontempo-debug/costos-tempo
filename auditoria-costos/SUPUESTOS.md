# SUPUESTOS — Lo que tuve que suponer o interpretar

Estado auditado: tag `pre-auditoria-costos` (commit `2e4ef99`).

Todo lo que sigue es una decisión mía, no algo que estuviera definido. Lo separo del resto
de la auditoría para que se pueda discutir o corregir sin tocar los hallazgos.

---

## 1. El supuesto principal: el sistema auditado no es el que describe el pedido

**El pedido describe un sistema de costeo de producción textil por orden de producción**
(OPs TEJ y TIN, kg de tela tejida y tinturada, consumos de hilo y químicos, subproductos
por talla, producto en proceso, series mensuales de enero a julio 2026).

**Este repositorio contiene otra cosa:** una aplicación de **ficha de costo unitario por
prenda** (costo estándar prospectivo por referencia), en un solo archivo `index.html`, con
datos en Supabase.

### Qué supuse

Que el pedido apunta a un sistema real que existe en otro lado —otro repositorio, una hoja
de cálculo, un módulo de Odoo— y que este repositorio es el que quedó a mano.

### Qué hice en consecuencia

Auditar **lo que hay**, con el mismo rigor, y decir con precisión qué de lo pedido no
existe, en vez de forzar equivalencias. Concretamente:

- Documenté el flujo de cálculo **real** (`MAPA.md` §3).
- Para cada uno de los cinco tipos de costeo que pide el pedido, expliqué qué es lo más
  cercano que hay y qué falta (`MAPA.md` §3.4).
- Dictaminé las cinco reglas de negocio con la evidencia que el código permite, incluyendo
  el veredicto «no verificable» cuando el objeto regulado no está modelado
  (`REGLAS_NEGOCIO.md`).
- En `ESQUEMA.sql` dejé el esqueleto de OPs, tallas y producto en proceso **comentado y
  sin crear**, para que se vea la distancia sin inventar un modelo.

### Qué NO hice, y por qué

No inventé un modelo de OPs, tallas ni WIP. Habría sido el error más grave posible en una
auditoría cuyo criterio explícito es *«si falta un dato, se reporta como faltante; nunca se
inventa»*.

### Si me equivoqué en el supuesto

Si el sistema del pedido existe en otro repositorio o archivo, hace falta indicármelo:
la auditoría de TEJ/TIN/tallas/WIP habría que rehacerla completa sobre esa fuente. Nada de
lo que está aquí serviría para eso.

---

## 2. Supuestos sobre los datos exportados a `/datos`

### 2.1 Supuse que «los datos actuales» son los del repositorio, porque no hay otros al alcance

Los datos de producción viven en Supabase. Intenté leerlos en solo lectura y **la política
de red del entorno bloquea la salida** hacia `oepsutldxratrvozpulq.supabase.co`
(`connect_rejected` por política de la organización, 6 de 6 intentos).

Así que lo exportado es **la semilla embebida en `index.html`**: 38 productos, 140
materiales, 5 centros, 5 clientes, 109 líneas de receta, 60 pantones. Eso es lo que ve un
usuario nuevo antes de que la nube responda, y lo que `fusionarSemilla()`
(`index.html:2057`) reinyecta en cada despliegue — o sea, es un dato real del sistema,
pero **no es la producción**.

Está advertido en `datos/LEEME.md` y en la cabecera de esta auditoría. En
`INSTALACION_LOCAL.md` §2 paso 4 dejé las tres maneras de traer los datos reales.

### 2.2 Supuse que no debía autenticarme contra producción

Aunque la clave *publishable* está en el código (`index.html:1757`), no intenté iniciar
sesión con credenciales de nadie. Leer con esa clave pública es una cosa; usar la cuenta de
una persona para entrar a un sistema de negocio en producción es otra, y no me lo pidieron.

### 2.3 Calculé los costos replicando `calc()` fuera del navegador

Para `datos/costo_unitario_calculado.csv` extraje las constantes de `index.html`
(líneas 741-1147) y **reimplementé `calc()` línea por línea** en un script de Node, sin
tocar el repositorio. Verifiqué que la réplica coincide con el código original
(`index.html:1161-1173`), incluyendo los detalles que importan:

- el `if(m)` que omite líneas con material inexistente (`1164`),
- el `if(!s||!s.on||!s.val)return` que salta centros (`1167`),
- que los centros por puntadas **no** suman al SAM (`1169-1170`),
- que los servicios pueden llevar precio propio de línea (`1031`).

El script está en el scratchpad de la sesión, no en el repositorio, porque la tarea pedía
no agregar código al proyecto. Si se quiere versionar, lo agrego donde se indique.

### 2.4 Agregué columnas que la aplicación no tiene

En los CSV incluí columnas que **no existen en el sistema** y que calculé yo, porque son
justamente lo que la aplicación no reporta:

| Columna | Archivo | Por qué la agregué |
|---|---|---|
| `lineas_omitidas_por_material_inexistente` | `costo_unitario_calculado.csv` | La aplicación las omite en silencio (`VALORES_FIJOS` B-2) |
| `fuente_de_los_consumos` | `costo_unitario_calculado.csv`, `fichas_lineas_materiales.csv` | La aplicación no distingue una ficha capturada de una rellenada con la receta (`VALORES_FIJOS` B-21) |
| `origen` | `materiales.csv` | Separa lo importado de Odoo de lo del catálogo interno |
| `costo_linea_usd` = `OMITIDA_EN_EL_CALCULO` | `fichas_lineas_materiales.csv` | Marca explícita en vez de una celda vacía ambigua |

Van con nombres descriptivos para que se note que son de la auditoría, no del sistema.

### 2.5 Las series mensuales de enero a julio 2026 van vacías, a propósito

El sistema **no tiene ninguna dimensión de periodo**. No hay mes contable, ni fechas de
producción, ni cantidades por periodo. Los siete meses no existen en ningún formato.

Creé los seis archivos `PLANTILLA_VACIA_*.csv` **con encabezado y sin una sola fila**, en
vez de:

- **no crearlos** — habría dejado sin respuesta un punto explícito del pedido;
- **rellenarlos con ceros** — habría afirmado que la producción de enero a julio fue cero,
  que es falso;
- **estimarlos** a partir de algo — habría sido inventar, justo lo que la regla R-5
  prohíbe.

Un archivo con encabezado y cero filas dice exactamente lo que pasa: **la estructura está
definida, el dato no existe**. Los nombres de columna son mi propuesta, derivada del
vocabulario del pedido; habría que validarlos antes de usarlos.

---

## 3. Supuestos al escribir `ESQUEMA.sql`

| Supuesto | Por qué | Alternativa descartada |
|---|---|---|
| **PostgreSQL 14+** | Es el motor que ya usa Supabase: migrar no cambia de tecnología | SQLite o MySQL: obligarían a reescribir los `jsonb` y perder `FILTER`, que uso en las vistas |
| **Dos modelos en un archivo**: réplica de la nube (PARTE 1) + normalizado (PARTE 2) | La réplica permite volcar los datos actuales sin perder nada; el normalizado es a donde conviene ir. Migrar en un solo paso es más riesgoso | Solo el normalizado: obligaría a transformar en el momento del volcado, sin red |
| `producto.anio` es **`text`**, no `int` | El campo es un input de texto libre (`index.html:1619`) y puede tener cualquier cosa | `int`: rompería la carga con el primer valor no numérico |
| Guardar **las dos** versiones de cada fecha (`fecha_costo_texto` + `fecha_costo`) | El sistema guarda `'8-sep-2026'` y `'provisional'`. Convertir y descartar el original perdería información | Solo `date`: `'provisional'` no tiene conversión posible |
| `costos.fecha_es()` devuelve **`NULL`** para lo que no puede convertir | Es exactamente lo contrario de lo que hace `num()` (`index.html:1157`), que devuelve 0 | Devolver una fecha por defecto: repetiría el error que la auditoría denuncia |
| `material_costo_unitario >= 0`, **no `> 0`** | Con `> 0` la carga de los datos actuales fallaría en 69 filas. El control se hace con la vista `qc_material_sin_precio`, que reporta en vez de bloquear | `> 0`: impide cargar el estado real |
| `ficha_linea.codigo_material` con **`ON DELETE RESTRICT`** | Hoy un material borrado deja líneas huérfanas que `calc()` omite en silencio | `CASCADE`: borraría la línea sin dejar rastro, tapando el problema |
| Un solo cliente base, forzado por índice único | El código lo asume pero no lo garantiza: usa `CLI[0]` por posición (`index.html:1355`) | Dejarlo sin restricción: reproduciría el fallo latente |
| Tablas **nuevas** `centro_costo_tarifa_hist` y `material_precio_hist` | Sin vigencias no se puede recalcular un costo histórico (`REGLAS_NEGOCIO` H-1) | No incluirlas: el esquema no resolvería el hallazgo principal |
| Columnas **nuevas** `*_congelado` / `*_congelada` en las tablas de versión | Son la corrección estructural de H-1 | — |
| Tabla **nueva** `bitacora` | Hoy no hay ninguna trazabilidad de autoría | — |
| El esqueleto de OPs, tallas y WIP va **comentado** | No hay ni una línea de código ni un dato que lo respalde. Crearlo sería inventar un modelo | Crearlo: daría por definido algo que nadie definió |

Todo lo que agregué y no existe hoy está marcado en el archivo con un comentario que
empieza por «HOY NO EXISTE» o «ESTAS COLUMNAS SON NUEVAS».

---

## 4. Supuestos al interpretar el negocio

### 4.1 Interpreté `tI` (`tarifa_moi`) como el vehículo de los CIF

El código lo llama «MOI» / «Mano de obra indirecta» (`index.html:1346`). La regla R-1 habla
de **CIF**. Supuse que son lo mismo aquí, porque `tI` es el **único** mecanismo de costos
indirectos que tiene el sistema: no hay ninguna otra tasa de absorción, ni prorrateo, ni
gasto de fábrica.

Si en TEMPO «MOI» y «CIF» son conceptos distintos y los CIF se absorben por otra vía, el
dictamen de R-1 hay que revisarlo: significaría que **los CIF no están en el costo en
absoluto**, que es un hallazgo distinto y más serio.

### 4.2 Interpreté el margen como margen **sobre precio de venta**

`PVP = costo / (1 − margen/100)` (`index.html:1356`) es inequívocamente margen sobre PVP,
no *markup* sobre costo. Con una meta del 30 %, el costo es el 70 % del precio. No hay
comentario que lo diga, pero la fórmula no admite otra lectura.

### 4.3 Interpreté que la unidad de costeo es «una prenda promedio»

El sistema no declara qué prenda representa el costo: no hay talla, ni curva, ni tamaño de
lote. Supuse que es «una prenda promedio de la referencia», porque es la única lectura
compatible con las unidades de medida que usa (`min/prenda`, `USD/prenda`).

**Es un supuesto mío, no algo que el sistema afirme.** Es justamente lo que señalo en
`REGLAS_NEGOCIO.md` R-3: el supuesto que reemplaza a las tallas no está escrito en ningún
lado.

### 4.4 No juzgué si los valores de negocio son correctos

Reporté que la tarifa de corte es `0.2252` y que la meta de Fashion Club es `30 %`
(`VALORES_FIJOS.md` §A), pero **no evalué si esas cifras son las correctas**. No tengo la
nómina, ni el tarifario, ni la política comercial. Auditá el *cómo*, no el *cuánto*.

La única excepción es cuando el propio código se contradice: las tarifas duplicadas entre
`CEN` y `REF_NOMINA` (`VALORES_FIJOS.md` A.2), y el `meta:35` de Aero Dep que nunca se usa
(A.3).

### 4.5 Supuse que `MP-TELAIMPORTAD` y `SV-TINTURADOIND` pueden solaparse

Para el dictamen de R-2 supuse que cargar en la misma ficha **«TELA IMPORTADA TINTURADA»**
y **«TINTURADO INDUSTRIAL»** sería doble conteo. Es lo que sugieren los nombres, pero
**nadie lo definió** y el sistema no lo impide ni lo advierte.

Si en TEMPO esa combinación es legítima por algún motivo (por ejemplo, un reproceso de
tintura sobre tela ya tinturada), el hallazgo se debilita. Pero la observación de fondo se
mantiene: **el sistema no sabe distinguir un caso del otro**, y la vista
`qc_posible_doble_conteo_tintura` que dejé en `ESQUEMA.sql` es una heurística por texto,
no una regla.

---

## 5. Supuestos metodológicos

### 5.1 Auditá el código, no la ejecución

No abrí la aplicación en un navegador ni la ejecuté: leí las 2.784 líneas y repliqué el
cálculo aparte. Todo hallazgo está anclado a un número de línea verificable.

**Lo que esto no cubre:** comportamientos que solo aparecen en ejecución (fallos de
renderizado, condiciones de carrera en la sincronización, el comportamiento real de
`localStorage` al llenarse). Los riesgos R-1 a R-10 de `PERSISTENCIA.md` están derivados
del código, no reproducidos en vivo.

### 5.2 No pude auditar las políticas RLS

`SB_KEY` (`index.html:1757`) es una clave *publishable*, pensada para estar visible en el
navegador. Eso significa que **toda la seguridad real vive en las políticas RLS de
Supabase**, que están en la nube y **no en este repositorio**.

No las pude ver. Así que **esta auditoría no dice nada sobre si los permisos están bien
puestos**. Los roles que sí revisé (`admin`, `planificacion`, `prearmado`, `consulta`,
`index.html:1760-1764`) son controles **de interfaz**: esconden botones. Si las políticas
RLS no replican esas restricciones del lado del servidor, cualquiera con la clave pública
podría saltárselas. **Es lo primero que habría que revisar, y no pude.**

### 5.3 Tomé el tag como el estado auditado

Creé el tag `pre-auditoria-costos` sobre `claude/lucid-maxwell-xix1ec` (commit `54a62eb`),
el estado con el que me encontré. No verifiqué si esa rama es lo que está desplegado en
producción. Si producción corre otro commit, los números de línea pueden no coincidir.

### 5.4 Lo que la auditoría no incluye

Para que quede claro el alcance, esto **no** está cubierto:

- las políticas RLS y la configuración de Supabase (§5.2);
- si los valores de negocio son los correctos (§4.4);
- el comportamiento en ejecución y en varios navegadores (§5.1);
- accesibilidad, rendimiento y seguridad del lado del cliente más allá de lo que salió al
  paso (por ejemplo, la interpolación de datos en HTML sin escapar de `escR`, que solo se
  usa en la pantalla de restauración, `index.html:2103`);
- los datos de producción (§2.1).
