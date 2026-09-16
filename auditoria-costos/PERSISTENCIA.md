# PERSISTENCIA — Qué se guarda, qué se recalcula, y dónde se pueden perder cambios

Estado auditado: rama `pre-auditoria-costos` (commit `54a62eb`). Todo es `index.html`.

---

## 1. Los tres lugares donde vive un dato

| Lugar | Qué es | Vida útil |
|---|---|---|
| **Memoria del navegador** | Las variables globales `REFS`, `FICHAS`, `CAT`, `CEN`, `CLI`, `TOT`… | Se pierde al cerrar la pestaña |
| **`localStorage`** | Clave `costos_tempo_v1`: una copia completa del estado en JSON (`estado()`, `index.html:1997`) | Persiste por navegador y por equipo. No se comparte |
| **Supabase (PostgreSQL)** | 8 tablas `cst_*` + `cst_versiones` + `perfiles` + bucket `cst-fotos` | Es la única fuente compartida entre usuarios |

Hay además un cuarto lugar, más incómodo: **el propio `index.html`**, que contiene la
semilla de datos (productos, materiales, tarifas, márgenes). Cada despliegue puede
inyectar filas nuevas en la base vía `fusionarSemilla()` (`index.html:2057`).

---

## 2. Qué se guarda y qué se recalcula cada vez

### 2.1 Se GUARDA (persiste)

| Dato | Dónde | Función |
|---|---|---|
| Productos / referencias | `cst_productos` + localStorage | `filas()` `1872` |
| Catálogo de materiales y sus precios | `cst_materiales` + localStorage | `1873` |
| Centros y tarifas MOD/MOI | `cst_centros` + localStorage | `1874` |
| Clientes y metas de margen | `cst_clientes` + localStorage | `1875` |
| **Consumos de cada ficha** (`lines`) | `cst_fichas` + localStorage | `1876` |
| **Tiempos por centro** (`cen`) | `cst_fichas` + localStorage | `1876` |
| Precios manuales por cliente (`pl`) | `cst_fichas` + localStorage | `1876` |
| Estado de la ficha: versión, guardada, en re-costeo, fecha, aprobación | `cst_fichas` | `1876` |
| Historial resumido (`hist`) | dentro de `cst_fichas` | `1463-1464` |
| Marcas, pantones, temporadas | `cst_marcas`, `cst_pantones`, `cst_temporadas` — **NO en localStorage** | `1877-1879` |
| Fotos | bucket `cst-fotos`; URL en `cst_productos` | `1925-1934` |
| Versiones cerradas | `cst_versiones` | `1986-1993` |

### 2.2 Se RECALCULA cada vez que se abre o se pinta (no persiste)

**Todo lo que es un resultado de costo o de precio.** No hay una sola cifra calculada
guardada en una columna.

| Resultado | Se calcula en | Cuándo |
|---|---|---|
| Costo de cada línea de material | `calc()` `1164` | En cada `draw()` |
| MOD y MOI de cada centro | `calc()` `1169-1170` | En cada `draw()` |
| **Costo total de la prenda** | `calc()` `1172` | En cada `draw()` |
| SAM (minutos totales) | `calc()` `1170` | En cada `draw()` |
| PVP de cada cliente | `plCalc()` `1358` | En cada `draw()` y cada pintado de lista |
| Margen real, ganancia, PVP mínimo | `plCalc()` `1366-1368` | Ídem |
| Subtotales por categoría de material | `rowsLines()` `1207` | Al dibujar la tabla |
| KPIs de producto (costeados, pendientes) | `kpis()` `1578` | Al entrar a Productos |
| Tarifa promedio y ponderada de fábrica | `resumenFabrica()` `2428`, `2431` | Al entrar a Centros |
| Lista de precios completa | `rowsLista()` `2581` | Al entrar a Lista de precios |
| CSV y PDF exportados | `csvDe()` `2722`, `pdfCliente()` `2677` | Al exportar |

Al pintar la pantalla *Productos* se recalculan **las 38 fichas completas**
(`totRef()`, `index.html:1174`, llamada desde `filaProd()`, `1605`). Lo mismo en
*Lista de precios* (`2592`) y *Exportar* (`2651`).

### 2.3 La consecuencia principal — los costos guardados **no están congelados**

`guardar()` (`index.html:1453-1468`) marca la ficha como cerrada y guarda el total en el
historial. Pero **nunca copia los precios unitarios ni las tarifas** con los que se
calculó. `calc()` siempre lee `CAT` y `CEN` **vigentes**.

Entonces:

> Si mañana alguien cambia el precio del jersey en *Materiales*, o la tarifa de confección
> en *Centros y tarifas*, **el costo y el precio de todas las fichas ya cerradas cambian
> retroactivamente**, incluidas las que se exportaron a un cliente.

Y la pantalla lo presenta como si no hubiera pasado nada:

- `index.html:1517` — al guardar dice: *«quedan congelados los costos del catálogo y las
  tarifas de mano de obra de hoy»*.
- `index.html:1522` — al guardar tarifas dice: *«Las fichas ya guardadas conservan la
  tarifa con la que se congelaron»*.
- `index.html:2596` — el precio en la lista lleva de tooltip: *«Precio de la v1 · guardada
  <fecha>»*.

**Las tres afirmaciones son falsas.** Ver `REGLAS_NEGOCIO.md` § H-1.

`cst_versiones` (`guardarVersion()`, `1986-1993`) guarda `total`, `sam`, `pvp`, `lines` y
`cen` — pero **no los precios unitarios ni las tarifas**, así que ni siquiera con el
historial se puede reconstruir por qué una versión costó lo que costó. Además ese
histórico **nunca se vuelve a leer** salvo en la recuperación manual de emergencia
(`recuperarDesdeVersiones()`, `1959`).

---

## 3. Los datos que el usuario edita a mano y cómo se guardan hoy

**Casi todo el valor del sistema es capturado a mano**: los consumos y los tiempos no
vienen de ningún sistema, los teclea una persona en la ficha.

### 3.1 No hay botón de guardar en el sentido habitual: hay autoguardado

`autosave()` — `index.html:2000-2025`:

```
1. Escribe TODO el estado en localStorage           (inmediato, línea 2002)
2. Marca "hay cambios pendientes"                   (líneas 2004-2005)
3. Espera 900 ms sin más cambios                    (línea 2024)
4. Sube fotos pendientes y hace syncPush() a la nube (líneas 2011-2012)
5. Si falla: reintenta a los 5, 10, 15… hasta 30 s   (líneas 2020-2021)
```

Se dispara desde `draw()` (`1444`), `rowsProd()` (`1654`), `cenVal()` (`1333`),
`setLineCol()` (`1225`), y las pantallas de pantones/temporadas. `syncPush()` (`1942`)
solo envía **las filas que cambiaron** respecto de `lastSent`, y borra en la nube las que
desaparecieron.

### 3.2 Lo que sí se guarda con un clic

| Botón | Función | Qué hace realmente |
|---|---|---|
| **Guardar costo** | `guardar()` `1453` | **No sube nada por sí mismo**: marca `saved=true`, sube la versión y deja que el autoguardado haga el resto |
| **Guardar avance** | `guardarAvance()` `2032` | Fuerza el envío inmediato, sin esperar los 900 ms. Es el único botón de guardado explícito, y solo está en la pantalla de ficha (commit `c8ba5ff`) |
| **Guardar tarifas** | `guardarTarifas()` `1520` | **No guarda nada**: solo repinta y muestra un aviso. El guardado real ya ocurrió en `setTar()` → `draw()` → `autosave()` |
| **Guardar productos** | `guardarProductos()` `1716` | Igual: **solo repinta**. No persiste nada por sí mismo |
| **Descargar respaldo** | `respaldo()` `2179` | Baja un `.json` con `estado()` |
| **Restaurar** | `confirmarRestaurar()` `2162` | Sube el respaldo a la nube comparando fechas |

> Dos de los cuatro botones que dicen «Guardar» no guardan nada. Funcionan porque el
> autoguardado ya lo hizo, pero le enseñan al usuario un modelo mental equivocado.

### 3.3 Protecciones que sí existen

Hay que reconocerlas, porque son buenas y son fruto de incidentes previos:

| Protección | Línea | Commit |
|---|---|---|
| Aviso al cerrar la pestaña con cambios sin subir | 2031 | `76f3adf` |
| Aviso al salir de la sesión con cambios pendientes | 1820 | — |
| Los pendientes sobreviven al cierre y se reintentan al volver a entrar | 1836-1845 | `76f3adf` |
| Reintento inmediato al recuperar la conexión | 2028 | `76f3adf` |
| Una tabla que falta (404) ya no bloquea el resto del guardado | 1787 | `1418e81` |
| La nube vacía **no** se rellena sola: pide confirmación explícita al admin | 1888-1901 | `e26775d` |
| Restaurar compara con la nube y no pisa lo más reciente sin permiso | 2132-2160 | `d528e59` |
| `fusionarSemilla()` solo agrega, nunca pisa | 2057-2071 | `e26775d` |

---

## 4. Riesgo real de perder cambios al recargar o recalcular

Ordenado de mayor a menor riesgo. Cada punto está verificado en el código.

### R-1 · `localStorage` se llena de fotos y el respaldo local muere en silencio — **alto**

`estado()` (`1997`) incluye `FOTO`, y las fotos recién cargadas son **base64**. Una sola
ocupa cientos de KB (`index.html:739` son 317 KB). La cuota típica es de 5-10 MB.

Cuando se supera, `localStorage.setItem` lanza una excepción que el código **traga con un
`catch` vacío** (`2002`, `2035`, `2074`).

**Escenario de pérdida:** se cargan fotos, `localStorage` se llena, el respaldo local deja
de actualizarse sin decir nada. Más tarde falla la nube → `cargarLocal()` (`1851`)
restaura **un estado viejo**, y el usuario ve datos antiguos creyendo que son los suyos.

### R-2 · Los pendientes se descartan a los 3 días — **alto**

`index.html:1837-1838`:

```js
pendienteAntes = localStorage.getItem(LKEY+'_pend')==='1' && (Date.now()-ts) < 3*24*60*60*1000;
```

Si alguien trabaja un viernes, la subida falla, y vuelve el martes: la condición es falsa,
se ejecuta `cargarNube()` (`1847`), **y el trabajo del viernes se pisa sin una sola
advertencia**. No se intenta recuperar, no se avisa, no se ofrece elegir.

### R-3 · El respaldo pierde datos que el usuario creó a mano — **alto**

- `estado()` (`1997`) **no incluye `MARCAS`, `TEMPORADAS` ni `PANTONES`**. Son listas que
  el usuario crea a mano (`1666`, `2540`, `1284`). No están ni en el autoguardado local ni
  en el `.json` de respaldo.
- `filasDeRespaldo()` (`2113`) **no incluye `anio`, `temporada` ni `arch`**. Restaurar un
  respaldo **borra el año y la temporada de todos los productos y desarchiva lo
  archivado**, directamente en la nube.
- `aplicarEstado()` (`2091`) descarta la lista de clientes de un respaldo anterior a
  `CLI_V=2`, sin decirlo.

El usuario ve «Restaurado · N registros aplicados» y cree que volvió todo.

### R-4 · Dos personas editando a la vez: gana la última — **alto**

No hay bloqueo, ni control de concurrencia, ni fusión. `syncPush()` (`1942`) hace un
*upsert* con `resolution=merge-duplicates` **a nivel de fila completa**: la fila entera se
reemplaza. La ficha de un producto es **una sola fila** (`cst_fichas`, `1876`), así que si
A edita los consumos y B los tiempos del mismo producto, **quien guarde último borra el
trabajo del otro**, en silencio.

Peor: los catálogos `CAT` y `CEN` también son estado global. Si A cambia el precio de un
material mientras B tiene la aplicación abierta, B **no se entera** (no hay recarga ni
suscripción en tiempo real) y al guardar cualquier cosa **vuelve a subir el precio viejo**
desde su copia en memoria.

### R-5 · La restauración baja la guardia si falla la comparación — **medio**

`index.html:2140`: `try{vivos=await sbGetConFecha(t)}catch(e){vivos=[]}`.
Si la comparación falla, `vivos=[]` significa «no hay nada más reciente» y la protección
contra pisar ediciones nuevas se desactiva sola. Es justo el incidente que el comentario
de `2099-2102` dice querer evitar.

### R-6 · El historial de versiones se puede perder sin aviso — **medio**

`guardarVersion()` (`1986`) se **salta entera** si no hay conexión o el rol no puede
editar (`1987`), y si la subida falla solo escribe en la consola (`1992`). El usuario ve
«Costo guardado» igual. Trabajando sin conexión, **ninguna versión queda registrada**.

### R-7 · La recuperación de emergencia puede vaciar fichas — **medio**

`recuperarDesdeVersiones()` (`1959`): `f.lines = v.lines || []` (`1975`). Si un registro
del historial no trae líneas, la ficha queda sin materiales, se marca como guardada
(`1977`) y **se sube a la nube** (`1983`).

### R-8 · Un despliegue puede reintroducir datos borrados — **medio**

`fusionarSemilla()` (`2057`) reagrega del archivo todo lo que no esté en la nube. Si se
borró a propósito un producto o un material que sigue en la semilla de `index.html`,
**vuelve a aparecer en el siguiente despliegue**. Por eso el commit `7b903f3`
(«Permanently remove legacy provisional mp/ins materials from the seed») tuvo que
**editar el HTML**, no la base: era el único modo de que no volvieran.

### R-9 · Recalcular no pierde datos de entrada, pero sí cambia resultados ya comunicados — **medio**

Recargar la página **no pierde consumos ni tiempos** (están en la nube y en localStorage).
Lo que sí ocurre es lo descrito en §2.3: **los costos y precios se recalculan con el
catálogo de hoy**, así que una ficha cerrada en agosto puede mostrar otro precio en
septiembre. No es pérdida de datos de entrada; es **pérdida de la trazabilidad del
resultado**, que para una auditoría de costos es igual de grave.

### R-10 · Fotos en base64 que nunca llegan a subirse — **bajo**

`subirFotosPendientes()` (`1935`) ignora los fallos individuales (`1939`). Una foto que
falle siempre queda como base64 en `localStorage`, engordándolo (ver R-1), y **no aparece
para los demás usuarios**.

---

## 5. Recomendación: ¿hace falta un botón de «guardar cambios»?

**Sí, pero no como se plantea la pregunta.** *(Recomendación, no implementada — esta
auditoría no modifica código.)*

### 5.1 El autoguardado no es el problema

Quitarlo sería un retroceso. La captura de una ficha son decenas de campos pequeños, y el
autoguardado con reintentos ya resolvió incidentes reales (commits `76f3adf`, `1418e81`).
Un botón de guardar **en lugar** del autoguardado reintroduciría el riesgo de perder una
sesión entera de captura.

### 5.2 Lo que sí falta es un **cierre explícito de versión que congele precios**

El problema real no es *cuándo* se escribe en la base: es que **«guardado» no significa
nada**. Una ficha «cerrada v1» sigue moviéndose con el catálogo.

Lo que hace falta es que `guardar()` (`index.html:1453`) **copie a la versión** el precio
unitario de cada material y la tarifa de cada centro usados en ese momento, y que a partir
de ahí la ficha cerrada se muestre **con esos valores congelados**, no recalculada. Las
columnas están previstas en `ESQUEMA.sql`:
`ficha_version_linea.precio_unitario_congelado` y
`ficha_version_centro.tarifa_mod_congelada` / `tarifa_moi_congelada`.

Con eso:
- un precio exportado a un cliente deja de cambiar solo;
- el «re-costeo» pasa a tener sentido real (comparar v1 congelada contra v2);
- `qc_version_desfasada` (ver `ESQUEMA.sql`, PARTE 4) deja de tener filas.

**Esto es más importante que cualquier botón.**

### 5.3 Dónde sí conviene un botón explícito

En **los maestros**, no en la ficha. Hoy editar una tarifa (`setTar`, `2554`) o el precio
de un material (`setPrecio`, `1237`) se guarda al instante y **repropaga a todo el
catálogo de precios sin confirmación**. Un solo tecleo mal puesto en *Centros y tarifas*
mueve el costo de las 38 referencias y los precios de los 5 clientes.

Para esas dos pantallas conviene: editar en borrador → ver el impacto («esto cambia el
costo de N referencias en promedio X %») → **Aplicar cambios**, que abre una nueva
vigencia en `centro_costo_tarifa_hist` / `material_precio_hist` en vez de pisar el valor.

Y conviene **quitar o renombrar** los dos botones que hoy dicen «Guardar» sin guardar
(`guardarTarifas` `1520`, `guardarProductos` `1716`): enseñan un modelo mental falso.

### 5.4 Resumen de la recomendación

| Prioridad | Qué | Por qué |
|---|---|---|
| 1 | Congelar precios y tarifas al cerrar una versión | Sin esto, ningún costo histórico es auditable (H-1) |
| 2 | Vigencias con fecha para precios de material y tarifas de centro | Permite recalcular «a la fecha» y explicar variaciones |
| 3 | Botón **Aplicar cambios** en Materiales y en Centros y tarifas | Hoy un tecleo mueve toda la colección sin confirmar |
| 4 | Mantener el autoguardado en la ficha, con indicador visible | Ya funciona y evitó pérdidas reales |
| 5 | Que el fallo de `localStorage` **avise** en vez de callarse | El respaldo local es el último salvavidas (R-1) |
| 6 | Control de concurrencia por fila (versión o marca de tiempo) | Hoy la última escritura borra la anterior (R-4) |
| 7 | Incluir `MARCAS`, `TEMPORADAS`, `PANTONES`, `anio`, `temporada`, `arch` en respaldo y restauración | Hoy se pierden (R-3) |
| 8 | Registrar quién cambió qué (tabla `bitacora` del esquema) | Hoy no hay ninguna trazabilidad de autoría |

### 5.5 Qué cambia al pasar a una base local

Al mover esto a una base local, **R-4 (concurrencia) y R-1 (localStorage) se resuelven
solos o dejan de aplicar**, porque desaparece el modelo de «cada navegador tiene una copia
completa del estado». Pero **H-1 (costos no congelados) no se resuelve solo**: es una
decisión del cálculo, no del almacenamiento. Si se migra tal cual, se migra el problema.
