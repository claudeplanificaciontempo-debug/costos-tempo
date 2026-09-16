# VALORES FIJOS — Constantes en el código, defaults silenciosos y clasificación por texto

Estado auditado: rama `pre-auditoria-costos` (commit `54a62eb`). Todo es `index.html`.

Tres secciones:
- **A.** Constantes, porcentajes, factores y mapeos escritos directamente en el código.
- **B.** Lugares donde, si falta un dato, se usa un default, un cero, o se omite el
  registro **sin avisar**. ← *esta es la sección crítica para la migración a base local.*
- **C.** Clasificaciones hechas por texto o prefijo.

---

## A. Constantes escritas en el código

### A.1 Tarifas de mano de obra — el factor económico más sensible

`index.html:1108-1114`. Vigencia declarada: `01-ago-2026`.

| Línea | Centro | Base | Tarifa MOD (`tD`) | Tarifa MOI (`tI`) | Total |
|---|---|---|---|---|---|
| 1109 | Corte | minuto | `0.2252` | `0.0680` | 0,2932 /min |
| 1110 | Estampado / Serigrafía | minuto | `0.1980` | `0.0600` | 0,2580 /min |
| 1111 | Bordado | **mil puntadas** | `0.1200` | `0.0000` | 0,1200 /mil |
| 1112 | Confección | minuto | `0.1649` | `0.0495` | 0,2144 /min |
| 1113 | Empaque | minuto | `0.3130` | `0.0940` | 0,3130 + 0,0940 /min |

**Para qué se usan:** son los dos factores de `MOD = valor × tD` y `MOI = valor × tI`
(`index.html:1169-1170`). `tI` es el vehículo con el que los **CIF se absorben por
minuto**: no hay otro mecanismo de costos indirectos en el sistema.

Observación: el centro *Bordado* tiene `tI = 0`, así que el bordado **no absorbe ningún
costo indirecto**. No hay comentario que diga si es deliberado.

### A.2 Tarifas de nómina de referencia — duplicadas y desincronizables

`index.html:2408`:

```js
const REF_NOMINA={corte:0.2252,confeccion:0.1649,empaque:0.3130,bordado:0.1200};
```

**Para qué se usa:** en *Centros y tarifas* se compara la tarifa vigente contra esta
referencia y se pinta un % de desvío (`index.html:2441-2444`).

**Problema:** son una **copia literal de los `tD` de `CEN`** (líneas 1109-1113). Si alguien
edita una tarifa en pantalla (`setTar`, `2554`), `CEN` cambia y `REF_NOMINA` no: el
indicador de desvío mide contra un valor que ya nadie mantiene. Además falta
`estampado`, que por eso siempre muestra `—` (`2447`).

### A.3 Metas de margen comercial por cliente

`index.html:1117-1124`.

| Línea | id | Cliente | Zona | Meta | Modo |
|---|---|---|---|---|---|
| 1119 | `fc` | Fashion Club | Ecuador | **30 %** | base — de aquí sale el PVP base |
| 1120 | `ad` | Aero Dep | Ecuador | 35 (ignorado) | `sobrebase`: **PVP de `fc` + 5 %** |
| 1121 | `jl` | JL Fashion Club | Colombia | **15 %** | margen propio |
| 1122 | `pr` | Price | Ecuador | **20 %** | margen propio |
| 1123 | `ot` | Otros clientes | Ecuador | **40 %** | margen propio |

- `const CLI_V=2` (`1117`): versión del esquema de clientes. Se usa en `aplicarEstado`
  (`2091`) para **descartar en silencio** la lista de clientes de un respaldo viejo.
- El campo `meta:35` de Aero Dep **no se usa nunca** (su modo es `sobrebase`): es un valor
  muerto que puede confundir a quien lea la tabla.
- **`CLI[0]` es el cliente base por posición, no por bandera.** `basePvp()` (`1355`) hace
  `F().pl[0]` sin mirar `c.base`. Si alguien reordena los clientes, todo el esquema de
  precios cambia sin aviso.

### A.4 Consumos sugeridos por tipo de producto (recetas)

`index.html:1036-1081`. **109 líneas de receta**, exportadas completas a
`datos/recetas_por_defecto.csv`.

- `REC_BASE` (`1036`) se agrega a **toda** receta: hilo de coser `0.010`, satín `1`,
  etiquetas `1`.
- Ejemplos de consumo fijo: `MP-JERSEY241 0.200` para camisetas (`1038`),
  `MP-FLEECEPERCHA 0.560` para hoodies (`1056`), `IN-BOTONES 3` para polos (`1052`),
  `IN-BOTONES 9` para camisas ML (`1075`).
- **Para qué se usan:** al crear un producto (`nuevoProd`, `1699`), en carga masiva
  (`2311`), y al cambiar la categoría de un producto (`reajustarReceta`, `1092`).
- Todos los consumos de receta llevan **desperdicio = 0** (el tercer valor de cada
  tupla). El sistema soporta desperdicio por línea pero **ninguna receta lo usa**.
- Comentario en `index.html:1067`: la categoría `DENIM` **no tiene tela** en su receta
  porque el catálogo importado no trae mezclilla. Un jean creado por receta arranca sin
  tela y **nada lo advierte**.

### A.5 Árbol de categorías y listas cerradas

| Constante | Valor | Línea |
|---|---|---|
| `DEPS` | `['Hombre','Mujer','Niño']` — **cerrado, no editable en la app** | 742 |
| `MARCAS` | arranca en `['Aeropostale']`, se puede ampliar (`1666`) | 743 |
| `TEMPORADAS` | `['Spring','Summer','Fall','Winter']`, ampliable (`2540`) | 744 |
| `CATEG` | 25 categorías → 58 tipos de producto. **Cerrado: no hay pantalla para editarlo** | 745-770 |
| `KN` | `{mp:'Materia prima', ins:'Insumos', dec:'Decoración', srv:'Servicios'}` — los 4 únicos tipos de material posibles | 1032 |
| `COLORS` | Colores de las barras del gráfico | 1033 |
| `SCR` | Las 6 pantallas | 2760 |
| Roles | `['admin','planificacion','prearmado','consulta']` | 1760-1764, 2469 |

### A.6 Precios de catálogo escritos en el código

`index.html:817-887` — 71 ítems con precio fijo (serigrafía, bordado, servicios).
Ejemplos: `SG-PLAS-S $0.15/color`, `SG-FLOC-E $1.95/color`, `DC-BORD $0.12/mil puntadas`,
`SV-TIN001 $0.48/prenda`, `SV-LAV002 $0.65/prenda`.

`index.html:894-962` — 69 familias importadas de Odoo, **todas con `p:0`**.

| Tipo | Cantidad | ¿Con precio? |
|---|---|---|
| Decoración (`dec`) | 68 | Sí, todas |
| Servicios (`srv`) | 4 | 3 sí, 1 en 0 (`SV-TINTURADOIND`) |
| Materia prima (`mp`) | 42 | **Ninguna: todas en 0** |
| Insumos (`ins`) | 26 | **Ninguna: todas en 0** |
| **Total** | **140** | **69 en cero (49 %)** |

Listado completo en `datos/materiales_sin_precio.csv`.

### A.7 Divisores, umbrales y factores mágicos

| Valor | Para qué | Línea |
|---|---|---|
| `1000` | Divisor de puntadas: la tarifa de bordado es por mil puntadas | 1169, 1317-1318, 2423 |
| `100` | Divisor del % de desperdicio y de los márgenes | 1164, 1356, 1365, 1366 |
| `0.5` | Tolerancia: solo avisa «bajo la meta» si el margen real cae más de 0,5 puntos | 1378 |
| `100` | Si el margen meta es ≥ 100 %, el PVP se fuerza a **0** en silencio | 1356, 1365 |
| `440` | Alto en píxeles al que se reducen todas las fotos | 1744, 2234 |
| `0.8` / `0.82` | Calidad de compresión WebP / JPEG de las fotos | 1747, 2237 |
| `238`, `26` | Umbrales de brillo y saturación para detectar recortes en una plancha | 2210 |
| `0.004` | Área mínima de un recorte, como fracción de la imagen | 2228 |
| `26` | Ancho/alto mínimo de un recorte en píxeles | 2229 |
| `6` | Margen en píxeles alrededor de cada recorte | 2231 |
| `1400` | Ancho máximo al que se escala la plancha antes de analizarla | 2202 |
| `10` | Separación mínima por defecto entre fotos de una plancha | 2201 |
| `40` | Máximo de resultados en el buscador de materiales | 1302 |
| `2` | Paso de muestreo de píxeles en la detección | 2211-2212 |
| `4` | Largo máximo de la abreviatura de cliente en la lista de precios | 2580 |

### A.8 Constantes de conexión, tiempos y reintentos

| Valor | Para qué | Línea |
|---|---|---|
| `SB_URL = 'https://oepsutldxratrvozpulq.supabase.co'` | Base de datos en la nube, **una sola, fija: no hay entorno de pruebas** | 1756 |
| `SB_KEY = 'sb_publishable_…'` | Clave pública de Supabase, escrita en el archivo. Es del tipo *publishable* (pensada para estar en el cliente), así que **toda la seguridad real depende de las políticas RLS en Supabase**, que están fuera de este repositorio y no se pueden auditar desde aquí | 1757 |
| `SKEY = 'costos_tempo_sesion'` | Clave de sesión en localStorage | 1758 |
| `LKEY = 'costos_tempo_v1'` | Clave del estado local. El `_v1` **nunca se incrementa**: un cambio de formato pisaría el estado viejo sin migración | 1996 |
| `20000` ms | Tiempo máximo de espera por defecto | 1768 |
| `25000` ms | Tiempo máximo al subir datos | 1786 |
| `30000` ms | Tiempo máximo al subir una foto | 1931 |
| `LOTE = 300` | Filas por lote al subir y al restaurar | 1944, 2171 |
| `900` ms | Retardo del autoguardado tras el último cambio | 2024 |
| `5000 × n`, tope `30000` ms | Espera entre reintentos | 2021, 2050 |
| `6` | Máximo de reintentos antes de que la espera se quede en 30 s | 2020, 2050 |
| `45 × 60 × 1000` ms | Cada 45 minutos se renueva la sesión | 1860 |
| `3 × 24 × 60 × 60 × 1000` ms | **3 días**: si los cambios pendientes son más viejos, se **descartan** y se carga la nube | 1838 |
| `2000` ms | Tolerancia al comparar fechas en la restauración | 2144 |
| `4200` ms | Duración de los avisos en pantalla | 1527 |
| `120` ms | Retardo al ocultar el buscador | 1310 |
| `250` ms | Retardo antes de abrir la ventana de impresión | 2634, 2703 |
| `400` ms | Retardo del aviso «Archivo actualizado» | 1921, 2080 |
| `50` ms | Retardo del foco en el login | 1797 |
| `6` | Largo mínimo de contraseña | 1811 |

### A.9 Formatos y textos con significado

| Valor | Para qué | Línea |
|---|---|---|
| `['ene','feb',…,'dic']` | Meses en español para las fechas. **Las fechas se guardan como texto tipo `8-sep-2026`, no como `date`** | 1450-1451 |
| `'8-sep-2026'`, `'12-ago-2026'`, `'15-sep-2026'`, `'provisional'` | Fechas de vigencia de precio escritas a mano en el catálogo | 817-962 |
| `'01-ago-2026'` | Vigencia de las tarifas de mano de obra | 1109-1113 |
| `fmt` = 2 decimales, `fmt4` = 4 decimales | Redondeo de presentación. **`fmt` redondea con `Math.round(n*100)/100` antes de formatear** | 1154-1155 |
| `';'` | Separador de los CSV que exporta la app | 2708, 2724 |
| `'﻿'` | BOM que se antepone al CSV para que Excel lea los acentos | 2752 |
| `'TEMPOCODECA S.A.'` | Pie de los PDF | 2632, 2701 |
| `v:1`, `cliv:CLI_V` | Versión del formato de respaldo | 1997 |

---

## B. Defaults silenciosos, ceros y omisiones sin aviso

> Esta sección responde a: *«Todo lugar donde, si falta un dato, se usa un valor por
> defecto, un cero o se omite el registro sin avisar.»*
> Cada punto está verificado en el código. **Ninguno de estos casos genera un mensaje,
> un log visible ni una marca en pantalla**, salvo donde se indique.

### B-1 · `num()` — cualquier texto ilegible se vuelve 0 · **`index.html:1157`**

```js
const num=v=>parseFloat(String(v).replace(',','.').replace(/[%+\s$]/g,''))||0;
```

**Qué hace:** convierte lo que el usuario teclea a número. Si no puede, devuelve **0**.
También el `||0` convierte a 0 cualquier `NaN` **y cualquier 0 legítimo por igual**, así
que no se distingue «escribió cero» de «escribió basura».

**Dónde entra:** consumo y desperdicio de cada línea (`setV`, `1234`), minutos de cada
centro (`cenVal`, `1333`), precio de cada material (`setPrecio`, `1237`), margen de cada
cliente (`setCli`, `2490`), tarifas MOD/MOI (`setTar`, `2555`), PVP y % de la lista de
precios (`setPL`, `1422`), precio en carga masiva (`2314`).

**Consecuencia:** si alguien pega `1,5 kg` en el consumo, `num` quita el `%$+ ` y espacios
pero **no** la `kg`; `parseFloat('1.5kg')` = `1.5`, así que pasa. Pero `'N/D'`, `'—'`,
`'s/d'` o una celda vacía → **0**, y el costo baja sin que nadie se entere.
**Es el default silencioso de mayor impacto del sistema.**

### B-2 · Línea de material con código inexistente: **se omite del cálculo** · `index.html:1164`

```js
f.lines.forEach(l=>{const m=byCode(l.c);if(m)TOT[m.k]+=l.q*(1+l.d/100)*precio(l,m)});
```

Si el código de la línea ya no está en `CAT`, el `if(m)` la **salta**. El costo sale más
bajo y no hay contador, marca ni aviso.

Peor: la **misma condición está tratada de forma distinta** en otros lugares:

| Lugar | Qué hace con un material inexistente | Línea |
|---|---|---|
| `calc()` | Lo ignora en silencio → costo subvaluado | 1164 |
| `rowsLines()` | `byCode(f.lines[a].c).k` **sin guarda** → lanza `TypeError` y **la tabla de materiales no se dibuja** | 1200 |
| `draw(soft)` | Mismo patrón sin guarda | 1435 |
| `exportarBOM()` | `if(!m)return` → la línea **desaparece del BOM exportado** | 2712 |

Es decir: la misma ficha puede **calcular** (mal), **romper la pantalla**, y **exportar un
BOM incompleto**, según por dónde se la mire. La columna
`lineas_omitidas_por_material_inexistente` de `datos/costo_unitario_calculado.csv` mide
esto: hoy es 0 en las 38 fichas, pero `borrarMat` (`1247`) y `limpiarMPeIns` (`2392`) sí
limpian las fichas, mientras que un borrado hecho **desde la nube por otro usuario** no.

### B-3 · Centro apagado o en cero: se salta · `index.html:1167`

```js
if(!s||!s.on||!s.val)return;
```

Un centro sin tiempo cargado **no aparece como faltante**: simplemente no suma. Una prenda
a la que se le olvidó cargar la confección cuesta menos y se ve igual de válida.
Hoy, **30 de las 38 fichas tienen 0 centros activos** (ver
`datos/costo_unitario_calculado.csv`, columna `centros_activos`) y su costo total es
**$0,00**, sin ninguna advertencia.

### B-4 · Precio de material en 0: se trata como costo real · `index.html:894-962` + `1164`

No hay validación de que el precio sea > 0. Un material con `p:0` aporta `$0` y el sistema
lo suma como un costo válido. **69 de los 140 materiales están así hoy** — incluidas
**todas las telas**. Ver `datos/materiales_sin_precio.csv`.

### B-5 · `precio()` para servicios · `index.html:1031`

```js
return (m.k==='srv'&&l.p!==undefined&&l.p!==null)?l.p:m.p
```

Si la línea de servicio no trae precio propio, cae al del catálogo. Si el del catálogo es
0 (caso de `SV-TINTURADOIND`), el servicio vale 0. Sin aviso.

### B-6 · Carga masiva de productos: **tres defaults en cascada** · `index.html:2299-2311`

```js
if(!CATEG[cat]){cat=Object.keys(CATEG).find(c=>c.startsWith(...slice(0,4)))||'CAMISETAS'}
if(!CATEG[cat].includes(sub)){sub=CATEG[cat].find(...)||CATEG[cat][0]}
const dep=DEPS.find(d=>d.toLowerCase().startsWith((p[4]||'').slice(0,3)))||(/kid|ni[nñ]/i.test(p[4]||'')?'Niño':'')
```

| Si falta o no coincide | Se pone | Línea |
|---|---|---|
| Categoría | Primero intenta por los **4 primeros caracteres**; si falla → **`'CAMISETAS'`** | 2303 |
| Tipo de producto | El **primer tipo** de esa categoría | 2304 |
| Departamento | Prefijo de 3 letras; si falla → **cadena vacía** | 2305 |
| Marca | Cadena vacía | 2306-2308 |

Y la **receta se elige con esos valores inventados** (`2311`), así que un producto mal
cargado nace con la lista de materiales equivocada. El único aviso es un contador
agregado de líneas ignoradas (`2322-2323`) que **no dice cuáles ni por qué**, y que **no
cuenta las líneas que se «arreglaron» con estos defaults**.

### B-7 · Carga masiva de materiales: tipo desconocido → `'ins'` · `index.html:2314`

```js
k:['mp','ins','dec','srv'].includes(p[2].toLowerCase())?p[2].toLowerCase():'ins'
```

Si la columna de tipo no es uno de los cuatro válidos, el material entra como **Insumo**.
Un rollo de tela mal tipeado queda clasificado como insumo y se suma al acumulador
equivocado. Sin aviso. (Además, `p[2]` sin guarda: si la línea tiene 5 partes pero la
tercera es vacía, `''.toLowerCase()` funciona, pero si `partes()` devolviera `undefined`
lanzaría excepción y **cortaría el procesamiento de todas las líneas siguientes**.)

### B-8 · Rol de usuario: cualquier fallo → `'consulta'` · `index.html:1823-1831`

```js
catch(e){ROL='consulta';NOMBRE=(SES&&SES.user&&SES.user.email)||''}
```

Si la consulta a `perfiles` falla (red, permiso, tabla ausente), el usuario entra en
**modo consulta** sin que se le diga *por qué*. Es un default **seguro** (degrada
permisos, no los amplía), pero opaco: un administrador puede creer que perdió su rol.

### B-9 · Tabla que no existe en la nube: se ignora · `index.html:1783`, `1787`, `1792`

```js
if(r.status===404)return[];                                   // sbGet
if(r.status===404){console.warn('Tabla … no existe …');return} // sbUpsert
```

Un 404 se trata como **«tabla vacía»**. Consecuencias:
- Al **leer**: `cargarNube` recibe `[]` y, para `CEN`/`CLI`/`MARCAS`/`PANTONES`/
  `TEMPORADAS`, el guardado `if(ce.length)` (`1905-1911`) deja la semilla del archivo. Para
  `CAT` y `REFS` **no hay esa guarda** (`1903-1904`): se vacían y se rellenan solo con
  `fusionarSemilla()`.
- Al **escribir**: los datos de esa tabla **se pierden en cada guardado**, y el único
  rastro es un `console.warn` que nadie mira. Esto ya pasó: el commit `5f00038` corrige
  exactamente este caso para `cst_marcas`.

### B-10 · `localStorage` lleno: el respaldo local falla en silencio · `index.html:2002`, `2035`, `2074`

```js
try{localStorage.setItem(LKEY,JSON.stringify(estado()))}catch(e){}
```

El `catch` está **vacío**. `estado()` incluye `FOTO`, y las fotos se guardan como
**base64** (`index.html:739` ocupa 317 KB en una sola línea). Con la cuota típica de
5-10 MB, unas pocas decenas de fotos la agotan. A partir de ahí **el respaldo local deja
de funcionar y nadie se entera**, justo cuando es el único salvavidas si la nube falla.

### B-11 · `estado()` no guarda todo lo que hay · `index.html:1997`

```js
function estado(){return {v:1,cliv:CLI_V,fecha:…,cur,REFS,FICHAS,CAT,CEN,CLI,FOTO}}
```

**Faltan `MARCAS`, `TEMPORADAS` y `PANTONES`.** Son datos que el usuario crea a mano
(`1666`, `2540`, `1284`) y que **sí** se suben a la nube (`filas()`, `1877-1879`), pero
**no** entran ni en el autoguardado local ni en el archivo de respaldo (`respaldo()`,
`2179`). Si se restaura un respaldo, se pierden.

### B-12 · El respaldo pierde campos de producto · `index.html:2113`

```js
cst_productos: d.REFS.map((x,i)=>({id:x.r,data:{r,n,marca,dep,cat,sub,orden,foto}}))
```

Comparado con `filas()` (`1872`), **faltan `anio`, `temporada` y `arch`**. Restaurar un
respaldo **borra el año y la temporada de todos los productos y desarchiva los
archivados**, en la nube, sin avisar. Los campos `anio`/`temporada` se agregaron en el
commit más reciente (`54a62eb`) y `filasDeRespaldo` no se actualizó.

### B-13 · Clientes de un respaldo viejo: se descartan callados · `index.html:2091`

```js
if(d.CLI&&(d.cliv||1)>=CLI_V){CLI.length=0;d.CLI.forEach(x=>CLI.push(x))}
```

Si el respaldo es anterior a `CLI_V=2`, la lista de clientes **no se restaura** y se
quedan los actuales. El usuario ve «Restaurado» y cree que volvió todo.

### B-14 · Restaurar: cada tabla que falle se trata como vacía · `index.html:2140`

```js
try{vivos=await sbGetConFecha(t)}catch(e){vivos=[]}
```

Si la comparación con la nube falla, `vivos=[]` significa **«no hay nada más reciente»** y
la protección contra pisar ediciones nuevas **se desactiva sola**. Es exactamente el
escenario que el comentario de `index.html:2099-2102` dice querer evitar.

### B-15 · `guardarVersion()` falla en silencio · `index.html:1992`

```js
try{await sbUpsert('cst_versiones',[row])}catch(e){console.error(e)}
```

Si la subida del histórico falla, el usuario ve «Costo guardado» igual. **El historial
queda con un hueco** y el único rastro está en la consola del navegador. Además, la
función **se salta entera** si `!ONLINE || !puedeEditar()` (`1987`): trabajando sin
conexión, **ninguna versión se registra**.

### B-16 · Recuperación desde el historial: puede vaciar fichas · `index.html:1975`

```js
f.lines=v.lines||[];
```

Si el registro del historial no trae líneas, la ficha se queda **sin materiales**, se
marca `saved=true` (`1977`) y se sube a la nube (`1983`). El aviso final solo cuenta
cuántas fichas tocó, no si alguna quedó vacía.

### B-17 · Márgenes: ≥ 100 % → PVP 0 · `index.html:1356`, `1365`

```js
b.pct>=100 ? 0 : c/(1-b.pct/100)
```

Se evita la división por cero devolviendo **0**. Un precio de venta de `$0.00` aparece en
la lista de precios y en los PDF como si fuera un precio real.

### B-18 · `metaDe()` con vínculo roto · `index.html:2480`

Si el cliente base al que apunta `vinc` no existe, devuelve `c.meta` — el valor que el
modo vinculado justamente decía no usar.

### B-19 · `resumenFabrica()` divide por la cantidad de centros por minuto · `index.html:2428`

```js
const tarProm=tmin.reduce((s,c)=>s+c.tD+c.tI,0)/tmin.length;
```

Si se borran todos los centros medidos en minutos, `tmin.length` es 0 → **`NaN`**, que se
imprime como `$NaN` en el panel. También `const n=ac.n||1` (`2426`) evita la división por
cero **inventando un divisor de 1**, lo que hace pasar un total por un promedio.

### B-20 · `resumenFabrica()` cambia de base sin destacarlo · `index.html:2412-2414`

```js
const conj=activos().filter(x=>FICHAS[x.r].saved);
const base=conj.length?conj:REFS;
const prov=!conj.length;
```

Si no hay ninguna ficha guardada, **calcula sobre los borradores** —incluidos los que
valen $0— y lo único que lo indica es la palabra «provisional» en un subtítulo (`2437`).
Hoy es exactamente el caso: 0 fichas guardadas, así que **los KPIs de fábrica que se ven
hoy están calculados sobre 30 fichas en cero**.

### B-21 · `fusionarSemilla()` rellena fichas faltantes con la receta · `index.html:2065`

```js
if(!FICHAS[x.r])FICHAS[x.r]=nuevaFicha(recetaDe(x.cat,x.sub));
```

Un producto sin ficha en la nube **no se reporta como faltante**: se le fabrica una ficha
con consumos sugeridos, que el sistema luego trata igual que a una capturada por una
persona. La columna `fuente_de_los_consumos` de
`datos/costo_unitario_calculado.csv` distingue los dos casos; **la aplicación no**.

### B-22 · Otros silencios menores

| Qué | Línea |
|---|---|
| `cargarLocal()` con JSON corrupto → `return false`, sin aviso | 2084 |
| `refrescar()` con token inválido → borra la sesión sin explicar | 1781 |
| `subirFotosPendientes()`: cada foto que falla solo va a `console.error` y el contador de éxito no lo refleja | 1939 |
| `reducir()`: si la imagen no se puede leer, se guarda **el original sin comprimir** | 1748 |
| `subirFotos()`: los archivos cuyo nombre no coincide con una referencia se cuentan pero **no se nombran** | 1736 |
| `CSVTXT` y `CSVNOM` se usan (`2716`, `2738`) **sin declararse nunca**: son globales implícitas | 2716 |
| `pantoneNombre()` devuelve el código crudo si el pantón ya no existe, en vez de marcarlo | 1264 |
| `plCalc` con PVP ≤ 0 → margen `0 %` en vez de indefinido | 1366 |

---

## C. Clasificación por texto o prefijo

> Responde a: *«Toda clasificación hecha por texto o prefijo (por ejemplo, detectar "TEJ"
> o "TIN" por el nombre).»*
>
> **Aclaración:** el sistema **no clasifica OPs por prefijo TEJ/TIN**, porque no tiene
> OPs. Pero sí toma varias decisiones a partir de texto. Estas son todas.

### C-1 · Códigos de material con prefijo semántico — convención **no verificada**

Los códigos siguen un patrón claro: `MP-` materia prima, `IN-` insumo, `SV-` servicio,
`SG-`/`DC-` decoración (`index.html:817-962`).

**Pero el prefijo es decorativo:** la clasificación real vive en el campo `k`
(`index.html:1164` usa `m.k`, nunca el prefijo). Nada valida que coincidan.
`agregarMat()` (`2330`) crea códigos `NUEVO-<timestamp>` con `k:'mp'` — **prefijo que no
corresponde a nada**. Y `setMat(i,'k',…)` (`2356`) deja cambiar el tipo sin tocar el
código. Resultado previsible: códigos `MP-` clasificados como insumo y viceversa, sin
forma de detectarlo.

> Esto es lo más parecido en el sistema al problema de *«OPs TEJ mal clasificadas»*:
> **hay una convención de prefijos que nadie verifica.** Ver `REGLAS_NEGOCIO.md` § R-4.

### C-2 · Categoría por los 4 primeros caracteres · `index.html:2303`

```js
cat=Object.keys(CATEG).find(c=>c.startsWith((p[2]||'').toUpperCase().slice(0,4)))||'CAMISETAS'
```

Cuatro caracteres bastan para elegir categoría. `'SHOR'` coincide con **`SHORT PLANOS`**
(la primera en el orden del objeto) aunque el usuario quisiera `SHORT FLEECE`.
Colisiones reales con 4 caracteres: `SHORT PLANOS` / `SHORT FLEECE`, `FLEECE BASICO` /
`FLEECE PESADO`. **Elige la primera del objeto, siempre.**

### C-3 · Departamento por los 3 primeros caracteres · `index.html:2305`

```js
DEPS.find(d=>d.toLowerCase().startsWith((p[4]||'').trim().toLowerCase().slice(0,3)))
  || (/kid|ni[nñ]/i.test(p[4]||'') ? 'Niño' : '')
```

Prefijo de 3 letras más una expresión regular de rescate (`kid`, `niñ`, `nin`).
`'Hombre'`/`'Mujer'`/`'Niño'` no colisionan en 3 letras, pero `'MUJ'`, `'muje'` y `'M'`
se comportan distinto: `'M'.slice(0,3)` = `'M'` y `'mujer'.startsWith('m')` es cierto → un
`'M'` suelto se resuelve como **Mujer**.

### C-4 · Tipo de material por pertenencia a una lista · `index.html:2314`

Ya cubierto en B-7: si el texto no está en `['mp','ins','dec','srv']`, se asigna `'ins'`.

### C-5 · Encabezado detectado por expresión regular · `index.html:2300`, `2313`

```js
if(p.length<2||/^ref/i.test(p[0])){mal++;return}   // productos
if(p.length<5||/^cod/i.test(p[0])){mal++;return}   // materiales
```

Una fila se descarta si su primera celda **empieza por** `ref` o `cod`. Una referencia real
llamada `REF-2026-01` se descartaría como si fuera un encabezado, y se contaría en `mal`
junto con las filas mal formadas.

### C-6 · Foto emparejada por nombre de archivo · `index.html:1732`

```js
const ref=f.name.replace(/\.[^.]+$/,'').trim();
```

El nombre del archivo **es** la referencia. `4823 (1).jpg` o `4823-frente.png` no
coinciden y la foto se descarta silenciosamente (solo entra al contador de `1736`).

### C-7 · Pantón buscado por texto · `index.html:1229-1231`

Busca primero `"código nombre"` exacto y después solo el código, ambos sin distinguir
mayúsculas. **Este sí avisa** cuando no encuentra (`toast('Pantón no encontrado'…)`,
`1231`) — es de los pocos lugares donde el sistema reporta un dato faltante en vez de
inventarlo.

### C-8 · Tipo de error clasificado por el texto del mensaje · `index.html:2019`, `2048`

```js
marcaSave(/40[13]/.test(e.message) ? 'Sin permiso para guardar' : 'Sin conexión · reintentando…','err')
```

Se busca `401`/`403` **dentro del texto del error**. Un error cuyo mensaje contenga
`403` por cualquier otro motivo (un id, un código de material) se reportaría como falta de
permisos. Y cualquier fallo real de permisos con otro código se anuncia como «sin
conexión», mandando al usuario a revisar la red.

### C-9 · Tipo de imagen por búsqueda de subcadena · `index.html:1928`

```js
const ext=blob.type.includes('png')?'png':blob.type.includes('webp')?'webp':'jpg';
```

Cualquier formato no reconocido (GIF, AVIF, HEIC) se guarda con extensión `.jpg` aunque no
lo sea.

### C-10 · Identificadores generados desde el nombre · `index.html:1877-1879`

```js
id: m.toLowerCase().replace(/[^a-z0-9]+/g,'-')
```

Marcas, pantones y temporadas usan como clave primaria un *slug* del nombre.
`'Aero Postale'` y `'aero-postale'` producen **el mismo id** → uno pisa al otro en la nube.
Además, renombrar una marca **crea un registro nuevo** y deja el viejo huérfano, porque el
borrado en `syncPush` (`1948`) solo alcanza a lo que estaba en `lastSent`.

### C-11 · Abreviatura de cliente por iniciales · `index.html:2580`

```js
function abbr(s){return s.split(/\s+/).map(w=>w[0]).join('').toUpperCase().slice(0,4)}
```

Encabezados de la lista de precios. `Fashion Club` y `Fashion Corp` darían ambos `FC`.

### C-12 · Búsqueda de materiales por concatenación de campos · `index.html:1302`, `2344`

```js
const t=(x.d+' '+x.c+' '+(x.fam||'')+' '+KN[x.k][0]).toLowerCase();
return ws.every(w=>t.includes(w));
```

Todos los campos se pegan en una cadena y se busca subcadena. Buscar `tin` devuelve
`TINTURADO INDUSTRIAL`, `TELA IMPORTADA TINTURADA` y `Tinturado de la tela` — pero también
cualquier material cuyo código o familia contenga esas tres letras en cualquier posición.
**Es exactamente el tipo de coincidencia por texto que hace inseguro clasificar por
nombre**, y es el único buscador que tiene el sistema.

### C-13 · Agrupaciones por valor de texto libre · `index.html:1645`, `2664`, `2689`

```js
const k = item.x[prodAgrupa] || '(sin asignar)';
```

Se agrupa por el **texto exacto** de marca, departamento, año o temporada.
`'Spring'`, `'spring'` y `'Spring '` son tres grupos distintos. El año es un campo de
texto libre (`index.html:1619`), no un número: `'2026'` y `'26'` no se juntan.

---

## D. Resumen para la migración

Lo que hay que resolver **antes** de llevar esto a una base local, en orden de riesgo:

| # | Qué | Referencia |
|---|---|---|
| 1 | 69 de 140 materiales (todas las telas) tienen precio 0 y el sistema lo suma como costo válido | B-4 |
| 2 | `num()` convierte cualquier dato ilegible en 0 sin distinguirlo de un cero real | B-1 |
| 3 | Una línea con material inexistente se omite del costo, rompe una pantalla y desaparece del BOM, según dónde se mire | B-2 |
| 4 | Ni el respaldo local ni el archivo de respaldo guardan marcas, temporadas y pantones; el respaldo además borra año, temporada y archivado | B-11, B-12 |
| 5 | Un 404 de tabla se trata como tabla vacía, tanto al leer como al escribir | B-9 |
| 6 | `localStorage` se llena con fotos en base64 y el respaldo local muere sin avisar | B-10 |
| 7 | Las tarifas de referencia están duplicadas en dos constantes que se desincronizan | A.2 |
| 8 | El cliente base se identifica por posición (`CLI[0]`), no por su bandera `base` | A.3 |
| 9 | Los prefijos `MP-`/`IN-`/`SV-` no se validan contra el campo `k` | C-1 |
| 10 | Las fechas son texto en español (`8-sep-2026`), no fechas: no se pueden ordenar ni comparar en SQL | A.9 |
