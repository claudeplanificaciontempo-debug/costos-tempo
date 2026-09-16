# REGLAS DE NEGOCIO — Verificación contra el código

Estado auditado: tag `pre-auditoria-costos` (commit `2e4ef99`). Todo es `index.html`.
**No se corrigió nada.** Esto es solo el dictamen con su evidencia.

---

## Resumen

| # | Regla | Veredicto |
|---|---|---|
| R-1 | La tela fabricada por Tempo se valora solo con hilo + químicos; MOD y CIF no forman parte de ese costo | **No verificable — no existe costeo de tela** |
| R-2 | Químicos y MOD de tintorería se consumen en la OP de servicio TIN; la segunda OP consume ese servicio + tela cruda. Sin doble conteo | **No cumple — no hay OPs, y el doble conteo es posible y no se detecta** |
| R-3 | Las tallas que salen como subproductos reciben costo; no todo queda cargado a la primera talla | **No cumple — no existe la dimensión talla** |
| R-4 | Las OPs TEJ mal clasificadas deben poder detectarse | **No cumple — no hay OPs ni ninguna validación de clasificación** |
| R-5 | Si falta un dato, se reporta como faltante; nunca se inventa ni se reemplaza en silencio | **No cumple — 22 casos documentados de sustitución silenciosa** |

Y tres hallazgos que no estaban en la lista pero salieron de la revisión:

| # | Hallazgo | Gravedad |
|---|---|---|
| H-1 | Los costos **no quedan congelados** al guardar, aunque la pantalla afirma que sí | **Crítico** |
| H-2 | El **100 % del costo actual es mano de obra**: material, insumos y servicios valen $0,00 en las 38 referencias | **Crítico** |
| H-3 | Una línea con material inexistente **se comporta de tres formas distintas** según la pantalla | Alto |

---

## R-1 · La tela se valora solo con hilo + químicos; MOD y CIF no entran

### Veredicto: **No verificable. No existe costeo de tela fabricada.**

### Evidencia

En el sistema **la tela no se fabrica: se compra**. Es una fila del catálogo de materiales
con un precio unitario plano:

```js
// index.html:926
{c:'MP-JERSEY241', d:'JERSEY 24/1', k:'mp', um:'u', p:0, f:'15-sep-2026', fam:'JERSEY 24/1'},
```

En la ficha entra como una línea más y se valora con la fórmula única del sistema
(`index.html:1164`):

```js
TOT[m.k] += l.q * (1 + l.d/100) * precio(l,m);
```

**No hay** en ningún lugar del archivo:
- explosión de tela en hilo + químicos,
- rendimiento kg de hilo → kg de tela,
- merma de tejeduría,
- costo de tejeduría de ningún tipo.

Lo verifiqué buscando en las 2.784 líneas. El término «hilo» aparece **solo** en tres
familias, y ninguna es hilo de tejeduría:

| Código | Descripción | Tipo | Línea |
|---|---|---|---|
| `IN-HILOPARABORD` | HILO PARA BORDAR | insumo | 923 |
| `IN-HILOPARACOSE` | HILO PARA COSER | insumo | 924 |
| `IN-HILOSJEANS` | HILOS JEANS | insumo | 925 |

Los tres son insumos **de confección**, consumidos por prenda (`REC_BASE` los carga a
0,010 por prenda, `index.html:1036`). **La palabra «químico» no aparece ni una vez.**

### La parte que sí se puede dictaminar

La regla dice que **MOD y CIF no deben formar parte del costo de la tela**. En el sistema:

- MOD entra por `TOT.mo += valor × c.tD` (`index.html:1170`)
- CIF entra por `TOT.moi += valor × c.tI` (`index.html:1170`) — `tI` es el **único**
  vehículo de costos indirectos que existe

Ambos se calculan **a nivel de prenda**, a partir de los centros Corte, Estampado,
Bordado, Confección y Empaque (`index.html:1109-1113`). **Ninguno de esos centros es
tejeduría ni tintorería**, y ninguno toca las líneas de material.

> Es decir: tal como está el sistema, **la MOD y el CIF no contaminan el valor de la tela**
> — pero solo porque la tela es un precio de compra tecleado a mano, no porque exista un
> costeo de tela que los excluya deliberadamente. La regla **no se puede cumplir ni
> incumplir**: el objeto que regula no está modelado.

### Agravante

Las **42 familias de materia prima tienen precio 0** (`index.html:894-962`). Hoy la tela no
vale «hilo + químicos»: vale **cero**. Ver H-2.

---

## R-2 · Químicos y MOD de tintorería en la OP TIN; sin doble conteo

### Veredicto: **No cumple.** No hay OPs, y el doble conteo es posible y no se detecta.

### Evidencia — no hay OP de servicio

No existe ninguna entidad de orden de producción en el archivo. Lo más cercano a una
tintorería son **dos materiales de tipo servicio**:

```js
// index.html:885
{c:'SV-TIN001', d:'Tinturado de la tela', k:'srv', um:'prenda', p:0.48, f:'12-ago-2026'},
// index.html:961
{c:'SV-TINTURADOIND', d:'TINTURADO INDUSTRIAL', k:'srv', um:'u', p:0, f:'15-sep-2026', fam:'TINTURADO INDUSTRIAL'},
```

Ambos son **un precio plano por prenda**, no el resultado de sumar químicos + mano de obra
de tintorería. **No hay consumo de químicos en ningún lado** y no hay un centro de costo
de tintorería en `CEN` (`index.html:1108-1114`).

Cómo se valora un servicio (`index.html:1031`):

```js
function precio(l,m){return (m.k==='srv'&&l.p!==undefined&&l.p!==null)?l.p:m.p}
```

Un servicio puede llevar precio propio por ficha; si no, usa el del catálogo. En ambos
casos es **un número tecleado**, sin composición.

### Evidencia — la estructura «servicio + tela cruda» existe, pero nada la protege

La segunda mitad de la regla (*la segunda OP consume ese servicio + tela cruda*) sí tiene
un reflejo: una ficha puede llevar a la vez una línea de tela y una línea de servicio de
tinturado, y `calc()` las suma a acumuladores distintos (`mp` y `srv`, `index.html:1164`).
Las 8 fichas precargadas están armadas así:

```js
// index.html:1138
'4823':{lines:[['MP-RIBB2X2LIVIA',0.245,0], … ,['SV-TINTURADOIND',0,0]], …}
```

**Pero el doble conteo no está impedido ni detectado.** El catálogo tiene, en paralelo:

| Código | Descripción | Tipo | Línea |
|---|---|---|---|
| `MP-TELAIMPORTAD` | **TELA IMPORTADA TINTURADA** | materia prima | 960 |
| `SV-TINTURADOIND` | TINTURADO INDUSTRIAL | servicio | 961 |

Nada impide cargar **las dos** en la misma ficha. El sistema no sabe que una tela ya
tinturada no debe volver a pagar el servicio de tintura. No hay validación, ni aviso, ni
regla de exclusión: `calc()` suma lo que encuentre.

Tampoco hay distinción entre **tela cruda** y **tela tinturada** como estados del mismo
material: son dos ítems de catálogo independientes, sin relación declarada.

### Agravante — el servicio está presente pero aporta $0

Las 8 fichas precargadas traen `['SV-TINTURADOIND', 0, 0]`: **consumo 0**, y el material
tiene **precio 0**. El servicio de tinturado figura en la ficha y aporta **$0,00**, sin que
nada lo señale. Ver `datos/fichas_lineas_materiales.csv`, columna `costo_linea_usd`.

### Detección propuesta (no implementada)

En `ESQUEMA.sql`, PARTE 4, dejé la vista `qc_posible_doble_conteo_tintura`, que marca las
fichas que llevan a la vez una MP y un servicio cuya descripción o familia contiene
`TINTUR`. Es una heurística por texto —con todas las limitaciones de la sección C de
`VALORES_FIJOS.md`— porque el modelo actual no ofrece nada mejor.

---

## R-3 · Las tallas que salen como subproductos reciben costo

### Veredicto: **No cumple.** La dimensión talla no existe.

### Evidencia

Busqué «talla» en las 2.784 líneas. Aparece **una sola vez**, dentro de la palabra
«restauradas» en un mensaje de pantalla (`index.html:1984`). No hay:

- campo de talla en `REFS` (`index.html:773-812`),
- tabla de tallas, curva de tallas ni matriz de tallas,
- ningún bucle ni reparto por talla en `calc()` (`index.html:1161-1173`),
- concepto de subproducto ni de coproducto en ninguna parte.

La unidad de costeo del sistema es **una prenda de una referencia**, sin desagregar. Todas
las unidades de medida de los centros son «minutos por prenda» o «puntadas por prenda»
(`index.html:1321`), y todos los precios son «USD por prenda» (`index.html:2632`).

### Matiz importante para el dictamen

La regla teme un problema concreto: *que todo el costo quede cargado a la primera talla*.
**Eso no es lo que pasa aquí.** Aquí no hay tallas en absoluto: el costo se expresa como
**una prenda promedio**. Es un problema distinto y, según para qué se use, puede ser peor:

- Si las tallas consumen tela distinta (una XL consume más que una S), el costo por prenda
  del sistema es un **promedio implícito no ponderado por la curva real de producción**.
- El sistema **no sabe qué mezcla de tallas asume**. No hay un campo que lo declare, ni un
  supuesto escrito en el código.

O sea: no es que el reparto entre tallas esté mal hecho. Es que **el reparto no existe y
tampoco está declarado el supuesto que lo reemplaza**.

---

## R-4 · Las OPs TEJ mal clasificadas deben poder detectarse

### Veredicto: **No cumple.** No hay OPs, ni clasificación, ni validación.

### Evidencia — «TEJ» no es un tipo de OP en este sistema

El texto `TEJ` aparece en el archivo únicamente en dos contextos, **ninguno de los cuales
es una clasificación de orden de producción**:

1. **Nombres de familias de material** (`index.html:912-959`):
   `MP-CUELLOSTEJID` «CUELLOS TEJIDOS», `MP-PUOSTEJIDOS` «PUÑOS TEJIDOS»,
   `MP-FAJASTEJIDOS` «FAJAS TEJIDOS», `MP-JERSEYLINETE` «JERSEYLINE TEJIDO»,
   `MP-SOFTWAFFLETE` «SOFTWAFFLE TEJIDO».
2. **Una categoría de producto terminado** (`index.html:757`):
   `'TEJIDOS':['Hoodie Tejido','Polo Tejida','Camiseta Tejida','Henley Tejida']`.

No hay tipo de OP, ni campo de clasificación, ni validación de ninguno de los dos.

### El problema equivalente que sí existe: prefijos que nadie verifica

El sistema **sí tiene** una convención de clasificación por prefijo de código —
`MP-` materia prima, `IN-` insumo, `SV-` servicio, `SG-`/`DC-` decoración
(`index.html:817-962`) — y **esa convención no se valida nunca**.

La clasificación que el cálculo usa de verdad es el campo `k` (`index.html:1164` usa
`m.k`, jamás el prefijo). Nada obliga a que coincidan:

| Dónde | Qué permite | Línea |
|---|---|---|
| `agregarMat()` | Crea códigos `NUEVO-<timestamp>` con `k:'mp'` — prefijo que no corresponde a ningún tipo | 2330-2331 |
| `setMat(i,'k',…)` | Cambia el tipo de un material **sin tocar el código** | 2356 |
| `procesarMasiva()` | Si el tipo no está en `['mp','ins','dec','srv']`, lo pone en **`'ins'`** en silencio | 2314 |

Consecuencia directa: un material con código `MP-…` puede estar clasificado como insumo (o
al revés) y **sumar al acumulador equivocado** en `calc()`. Nada lo detecta, ni en pantalla
ni en los exportes.

> **Traducido a los términos de la regla:** el sistema tiene exactamente el problema que la
> regla quiere prevenir —clasificación no verificada— solo que sobre materiales en vez de
> sobre OPs. Y **no hay ningún mecanismo de detección**.

### Detección propuesta (no implementada)

`ESQUEMA.sql`, PARTE 4, vista `qc_material_prefijo_incoherente`: compara el prefijo del
código contra el tipo declarado y lista las discrepancias. Aplicada a los datos actuales
—ver `datos/materiales.csv`— los 140 materiales son coherentes, pero eso es suerte del
estado inicial, no una garantía del sistema.

---

## R-5 · Si falta un dato, se reporta; nunca se inventa ni se reemplaza en silencio

### Veredicto: **No cumple.** Es la regla que más se incumple, y de forma sistemática.

`VALORES_FIJOS.md` § B documenta **22 casos**. Los siete más graves para el costo:

### R-5.1 · Cualquier dato ilegible se convierte en 0 · `index.html:1157`

```js
const num=v=>parseFloat(String(v).replace(',','.').replace(/[%+\s$]/g,''))||0;
```

`'N/D'`, `'—'`, `'s/d'`, una celda vacía → **0**. Y el `||0` hace que **no se pueda
distinguir «escribió cero» de «escribió algo que no se entiende»**. Esta función procesa
consumos (`1234`), tiempos (`1333`), precios (`1237`), tarifas (`2555`) y márgenes
(`2490`). Es el incumplimiento más extendido del sistema.

### R-5.2 · Línea con material inexistente: se omite del costo · `index.html:1164`

```js
f.lines.forEach(l=>{const m=byCode(l.c); if(m) TOT[m.k]+= …});
```

El `if(m)` descarta la línea. **El costo sale más bajo y no hay contador, marca ni aviso.**
Es literalmente «omitir el registro en silencio».

### R-5.3 · Precio 0 se trata como costo válido · `index.html:894-962` + `1164`

No hay ninguna validación de que el precio sea mayor que cero. **69 de 140 materiales
(49 %) tienen precio 0**, incluidas las 42 familias de tela. El sistema los suma como si
fueran costos reales. Ver `datos/materiales_sin_precio.csv`.

### R-5.4 · Centro sin tiempo: se salta · `index.html:1167`

```js
if(!s||!s.on||!s.val)return;
```

Una prenda a la que se olvidó cargar la confección cuesta menos y **se ve exactamente
igual de válida** que una completa. Hoy **30 de 38 fichas no tienen ningún centro activo**
y su costo total es **$0,00** sin ninguna advertencia
(`datos/costo_unitario_calculado.csv`, columna `centros_activos`).

### R-5.5 · Carga masiva: tres datos inventados en cascada · `index.html:2299-2311`

| Si falta o no coincide | Se inventa | Línea |
|---|---|---|
| Categoría | Prefijo de 4 caracteres; si falla → **`'CAMISETAS'`** | 2303 |
| Tipo de producto | **El primero** de esa categoría | 2304 |
| Departamento | Prefijo de 3 letras; si falla → vacío | 2305 |
| Tipo de material | Si no está en la lista válida → **`'ins'`** | 2314 |

Y **la receta se elige con esos valores inventados** (`2311`): el producto nace con la
lista de materiales equivocada. El único aviso es un contador de líneas ignoradas
(`2322-2323`) que **no nombra cuáles** y que **no cuenta las que se «arreglaron»** con
estos defaults.

### R-5.6 · Ficha ausente: se fabrica con la receta · `index.html:2065`

```js
if(!FICHAS[x.r])FICHAS[x.r]=nuevaFicha(recetaDe(x.cat,x.sub));
```

Un producto sin ficha no se reporta como faltante: se le inventa una con consumos
sugeridos, que el sistema luego trata **igual que a una capturada por una persona**.
No hay ningún indicador que los distinga. La columna `fuente_de_los_consumos` de
`datos/costo_unitario_calculado.csv` lo separa por primera vez: **30 de 38 fichas están
en ese estado**.

### R-5.7 · Tabla que no existe en la nube: se ignora · `index.html:1783`, `1787`

```js
if(r.status===404)return[];                                     // al leer: "tabla vacía"
if(r.status===404){console.warn('Tabla … no existe'); return}    // al escribir: se omite
```

Al escribir, **los datos de esa tabla se pierden en cada guardado** y el único rastro es un
`console.warn` que nadie mira. Ya ocurrió: el commit `5f00038` corrige exactamente este
caso para `cst_marcas`.

### Lo que sí se reporta bien

Para ser justos, el sistema sí avisa en algunos casos, y conviene señalarlos como el
patrón a extender:

| Caso | Aviso | Línea |
|---|---|---|
| Pantón no encontrado | `toast('Pantón no encontrado'…)` y **no aplica el cambio** | 1231 |
| Falta código o nombre de pantón | `toast('Faltan datos'…)` | 1282 |
| Pantón duplicado | `toast('Ya existe'…)` | 1283 |
| Temporada duplicada o sin nombre | `toast` | 2538-2539 |
| Centro sin nombre | `toast('Falta el nombre'…)` | 2562 |
| Fotos que no coinciden con ninguna referencia | Contador en el aviso (no nombra cuáles) | 1736 |
| Borrar material/pantón/temporada en uso | `confirm()` diciendo cuántas fichas afecta | 1251, 1292, 2548 |
| Nube vacía | `confirm()` explícito, **no sube nada solo** | 1888-1901 |

El contraste es nítido: **los datos maestros que el usuario administra sí se validan; los
datos que entran al cálculo del costo, no.**

---

## H-1 · Los costos no quedan congelados al guardar (la pantalla dice que sí)

### Gravedad: **crítica**. No estaba en la lista de reglas, pero es el hallazgo principal.

### Evidencia

`guardar()` (`index.html:1453-1468`) marca la ficha como cerrada y guarda el total en el
historial, pero **nunca copia los precios ni las tarifas** con los que se calculó:

```js
f.saved=true; f.edit=false; f.fecha=hoy(); f.aprob=null;
f.hist.push({ver:f.ver, fecha:f.fecha, total:TOT.total, sam:TOT.sam, pvp:plCalc(0).pvp});
```

Y `calc()` (`index.html:1161-1173`) **siempre lee `CAT` y `CEN` vigentes**. La lista de
precios recalcula en vivo cada vez que se pinta (`index.html:2592`):

```js
cur=x.r; calc(); const f=FICHAS[x.r];
…
`<span class="lppx" title="Precio de la v${f.ver} · guardada ${f.fecha}">${fmt(r.pvp)}</span>`
```

El tooltip afirma que es *«el precio de la v1 guardada el <fecha>»*. **No lo es: es el
precio de hoy.**

Tres textos de la interfaz afirman lo contrario de lo que hace el código:

| Línea | Texto en pantalla | Realidad |
|---|---|---|
| 1517 | «Al guardar quedan congelados los costos del catálogo y las tarifas de mano de obra de hoy» | No se congela nada |
| 1522 | «Las fichas ya guardadas conservan la tarifa con la que se congelaron» | No la conservan |
| 2596 | «Precio de la v1 · guardada <fecha>» | Es el precio recalculado hoy |

### Consecuencia práctica

Cambiar una tarifa en *Centros y tarifas* (`setTar`, `2554`) o el precio de un material en
*Materiales* (`setPrecio`, `1237`) **modifica retroactivamente el costo y el precio de
todas las fichas ya cerradas**, incluidas las que se exportaron a un cliente en PDF.

Ni siquiera el histórico salva: `cst_versiones` (`guardarVersion`, `1986-1993`) guarda
`total`, `sam`, `pvp`, `lines` y `cen`, pero **no los precios unitarios ni las tarifas**.
Un costo histórico **no se puede reconstruir ni explicar**.

### Cómo comprobarlo sin tocar nada

Cargar los CSV de `datos/` en la base del `ESQUEMA.sql` y consultar la vista
`qc_version_desfasada`: lista las versiones cerradas cuyo costo recalculado hoy ya no
coincide con el que quedó guardado.

---

## H-2 · El 100 % del costo actual es mano de obra

### Gravedad: **crítica**.

Calculando `calc()` sobre las 38 referencias del estado actual del repositorio
(`datos/costo_unitario_calculado.csv`):

| Componente | Total de las 38 referencias |
|---|---|
| Materia prima | **$0,00** |
| Insumos | **$0,00** |
| Decoración | **$0,00** |
| Servicios | **$0,00** |
| Mano de obra directa (MOD) | $14,54 |
| Mano de obra indirecta (MOI / CIF) | $4,37 |

Causa: las **69 familias importadas de Odoo entraron con `p:0`** (`index.html:894-962`), y
las 8 fichas precargadas solo usan materiales de ese grupo. Además **30 de las 38 fichas
no tienen ningún centro activo**, así que su costo total es exactamente **$0,00**.

Ninguna pantalla lo advierte. Peor: el panel *Resumen de la fábrica* calcula sus KPIs sobre
esos borradores en cero cuando no hay fichas guardadas (`index.html:2412-2414`), y lo único
que lo indica es la palabra «provisional» en un subtítulo (`2437`).

> Esto significa que **cualquier precio que salga hoy del sistema está construido solo
> sobre mano de obra**. El comentario del propio código lo reconoce
> (`index.html:891`: *«Costo en 0: complétalo tú»*), pero la aplicación no distingue
> «todavía no cargado» de «cuesta cero».

---

## H-3 · Un material inexistente se comporta de tres formas distintas

### Gravedad: alta.

La misma condición —una línea de ficha cuyo código ya no está en el catálogo— está tratada
de forma incoherente:

| Lugar | Qué hace | Línea |
|---|---|---|
| `calc()` | La **omite en silencio** → costo subvaluado | 1164 |
| `rowsLines()` | `byCode(…).k` **sin guarda** → `TypeError`, la tabla de materiales **no se dibuja** | 1200 |
| `draw(soft)` | Mismo patrón sin guarda | 1435 |
| `exportarBOM()` | `if(!m)return` → la línea **desaparece del BOM exportado** | 2712 |

La misma ficha puede calcular mal, romper la pantalla y exportar un BOM incompleto según
por dónde se la mire. `borrarMat()` (`1247`) y `limpiarMPeIns()` (`2392`) sí limpian las
fichas al borrar, pero **un borrado hecho por otro usuario desde la nube no llega a la
copia en memoria de los demás** (no hay recarga ni suscripción en tiempo real).

---

## Conclusión

De las cinco reglas planteadas, **tres (R-1, R-2, R-4) regulan objetos que el sistema no
modela**: órdenes de producción, tela fabricada, clasificación TEJ/TIN. No es que estén
implementadas a medias — no existen.

**R-3** tampoco existe, y el matiz importa: no es que el costo se cargue a la primera
talla, es que no hay tallas y el supuesto que las reemplaza (una prenda promedio) no está
declarado en ningún lado.

**R-5 es la única regla plenamente aplicable al sistema actual, y se incumple de forma
sistemática**: 22 puntos de sustitución silenciosa, siete de ellos directamente sobre el
cálculo del costo.

Y por encima de las cinco está **H-1**: mientras los costos no queden congelados al
cerrar una versión, **ninguna cifra que produzca este sistema es auditable**, porque no se
puede reconstruir con qué precios se calculó.
