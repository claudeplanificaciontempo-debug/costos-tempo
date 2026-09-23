# Receta para Odoo desde la ficha · propuesta

Estado: propuesta para decidir con la usuaria. No hay código escrito. Fecha: 23-sep-2026.

Es el plano para decidir juntas qué se construye, en qué orden y qué necesitamos de ti. Todo lo que se cita del código es de `/home/user/costos-tempo/index.html` (número de línea entre paréntesis). Las marcas [P] y [NV] se explican al final de la sección 1.

---

## 1. Qué vamos a construir

1. **Un botón "Exportar receta Odoo"** que toma la ficha de costos que ya llenas en la app (telas, insumos, consumo, desperdicio, pantón) y genera el archivo que Odoo importa como lista de materiales (`mrp.bom`), validando antes que cada prenda y cada material tengan su código de Odoo. Lo que no pasa la validación no sale del archivo; sale en una hoja de avisos que dice qué falta.
2. **Un lector de fichas digitales**: se pega la tabla de la ficha (o se suelta un .csv), la app empata cada línea con el catálogo de Materiales y los pantones, tú revisas en una tabla con semáforo (verde, ámbar, rojo) y con un clic las líneas entran a la ficha de costos como si las hubieras tecleado.
3. **Tres datos maestros que hoy faltan** y sin los cuales Odoo no acepta nada: el código Odoo de cada material, la unidad real de cada material (hoy las 70 filas importadas dicen "u", aunque la tela se consuma en kg o metros) y el código único de cada prenda (hoy vacío en todos los productos).

Cuatro reglas que mandan en todo el diseño:

- **La ficha de costos de la app es la fuente única de la receta.** Lo que venga de una ficha digital entra primero a la app, se revisa, se costea y de ahí sale a Odoo. Nunca se genera un archivo para Odoo "directo desde el PDF".
- **Odoo es el dueño de los códigos; la app es la dueña de los consumos.** La app nunca inventa un código: si un material o una prenda no tiene código Odoo, esa receta no sale y la app dice exactamente qué falta y quién lo resuelve.
- **La app manda.** Si algo está mal en Odoo se corrige en la app y se vuelve a exportar; no se parcha en Odoo, porque a la siguiente exportación se pisaría.
- **Revisión humana antes de escribir**: nada leído se aplica solo, y nada generado se importa sin pasar por "Probar" en Odoo.

**Cómo se verificó el formato de Odoo.** La red bloqueaba odoo.com, así que no se pudo leer la documentación en línea. Se leyó el código fuente oficial de Odoo en las ramas 16.0, 17.0 y 18.0 (módulos `mrp`, `base_import`, `ir_fields`, `uom`, `product` y las traducciones es y es_419) y la plantilla oficial de importación `mrp_bom.xls`. Lo marcado **[P]** es probable: coherente con el código, pero sin prueba en una base real. Lo marcado **[NV]** hay que probarlo en su base antes de darlo por bueno. Las pruebas se hacen el día 1 (sección 6).

Todo vive en `index.html`, sin librerías y sin servidor, como hoy. En Supabase no hay que crear nada para el piloto: los campos nuevos viajan dentro de los JSON que ya se guardan enteros (`filas()`, 3672-3702).

---

## 2. El flujo de punta a punta

```
  FICHA DIGITAL (externa)              APP COSTOS TEMPO                                      ODOO
  Excel / Sheets / CSV  --pegar-->  [1] Leer  >  [2] Revisar y empatar  >  [3] Aplicar
  PDF / foto            --ver al-->      (modal "Leer ficha digital", 2 pasos)     |
                          lado                                                     v
                                                                    FICHAS[ref].lines (+ fuente)
                                                                                   |
                                             [3-bis] Altas en Odoo de lo que no existe (Avisos)
                                                                                   |
                                                        [4] Costear y aprobar como hoy (Costeada vN)
                                                                                   |
                                                        [5] Exportar receta Odoo ----------->  [6] Fabricación > Listas de
                                                            Receta_Odoo_<fecha>.xlsx              materiales > Importar
                                                            hojas: mrp.bom · Lectura · Avisos          > Probar > Importar
                                                                                   ^                       |
                                                        [7] Marcar "importada en Odoo vN" <----------------+

  Antes de todo, una vez:  [0-bis] Pedir a Odoo la exportación de productos y una LdM de ejemplo
                           [0] Datos maestros: código Odoo y UM por material · código único por prenda
```

| Paso | Qué pasa | Quién |
|---|---|---|
| 0-bis | Pedir a Odoo la exportación de product.product y de una LdM "compatible con importación"; confirmar versión, idioma y si hay base de prueba | Planificación (antes del día 1) |
| 0 | Se llenan código Odoo, unidad y código único. En el piloto: carga masiva de Materiales con las columnas nuevas (sección 4) y `cu` a mano. En etapa 2: pegando la lista de productos exportada de Odoo ("Empatar con Odoo") | Planificación |
| 1 | Se pega la tabla de la ficha digital (o se suelta un .csv); si es PDF o foto, se ve al lado para transcribir | Prearmado |
| 2 | La app propone material, color, consumo y desperdicio por línea; la persona confirma lo ámbar y resuelve lo rojo | Prearmado (Martha si hay telas nuevas) |
| 3 | Las líneas entran a la ficha de costos; los productos que no existan se crean con confirmación | Prearmado |
| 3-bis | Crear en Odoo las prendas y telas nuevas de la colección que la app lista en Avisos › "Sin producto en Odoo" (REF, nombre, familia, UM, color) | Quien administra productos en Odoo (nombre por definir) |
| 4 | Tiempos, precio, "Guardar costo", "Aprobar": igual que hoy | Prearmado llena, planificación aprueba |
| 5 | Botón "Exportar receta Odoo": valida, arma el .xlsx, registra quién y cuándo | Planificación |
| 6 | Importar en Odoo con "Probar" primero | Persona con usuario en Odoo (nombre por definir); si no tiene rol de edición en la app, avisa a planificación |
| 7 | "Marcar importadas en Odoo": cierra el ciclo | Planificación |
| Mantenimiento | Recargar la lista de Odoo cuando pasen 30 días o entren materiales nuevos | Planificación |

---

## 3. Las tres piezas

### 3.1 Pieza A · Lector de fichas digitales

**Los tres escenarios de "ficha digital".** Hasta ver los ejemplos reales, la ficha digital puede ser una de tres cosas, y cada una cambia el alcance:

| Escenario | Qué es | Qué se construye |
|---|---|---|
| **A · Tabla** (Excel, Sheets, CSV, PDF con texto seleccionable) | Una fila por material | Pieza A completa (pegar / soltar .csv) |
| **B · Imagen** (PDF escaneado, foto, plancha) | Solo se puede mirar | Pieza A con "Foto o PDF a la vista" para transcribir; OCR solo en etapa 3 |
| **C · Ya está en la app** (la "ficha digital" es la ficha de costos de esta app) | Nada que leer | **Se descarta la Pieza A del piloto**: solo Pieza C + datos maestros |

Si vienen varias prendas por archivo (una pestaña por prenda o una tabla larga con columna Referencia) el lector debe aceptar ambas. Si los consumos vienen por talla, ver la decisión de talla en 3.2-G.

**Dónde**

- Productos, barra de acciones (775-786): botón **Leer fichas digitales** entre **Carga masiva** (777) y **Fotos** (779). Ahí están las otras dos entradas en lote y ahí aterriza el rol prearmado al entrar (3657).
- Ficha de costos, tarjeta Materiales (658): botón **Leer ficha digital** junto a **Cargar sugeridas del tipo** (`#bt-sug`, misma línea 658), con la referencia ya fijada. Se deshabilita en ficha cerrada igual que el vecino (`RO()`, 2460).
- Modal nuevo `ovl-receta` con dos pasos (origen → revisión), calcado de "Recortar fotos de una imagen" (`ovl3`, 1172-1192: detectar → revisar → aplicar). No se toca ninguna ficha hasta el botón final.
- Lo usan admin, planificación y prearmado (`puedeEditar()`, 3487). El lector exige `puedeEditar()` dentro de la función, no solo en el botón.

**Paso 1 · Origen.** Tres tarjetas como en `ovl-fotos` (1226-1236):

1. **Pegar desde Excel** (camino principal). Sirve para Excel, Google Sheets y PDF con texto seleccionable.
2. **Soltar archivos** `.csv`/`.txt` (uno por prenda; la referencia sale del nombre del archivo con la misma regla de las fotos, `refDeArchivo` 3361).
3. **Foto o PDF a la vista**: la imagen o el PDF se muestran en un panel lateral con zoom (visor nativo del navegador para PDF) para transcribir mirando. **No hay lectura automática de fotos en el piloto** (ver etapa 3).

Formato de pegado (una fila por material; tabulación, `;`, coma si no hay otro separador, o **dos o más espacios**, que es como llega el texto copiado de un PDF; acepta coma decimal):

```
Referencia ; Material           ; Color               ; Consumo ; Desperdicio % ; UM
4931       ; JERSEY 24/1        ; 19-4025 CADET NAVY  ; 0,240   ; 5             ; kg
           ; CUELLOS TEJIDOS    ; 19-4025             ; 1       ; 0             ; u
           ; HILO PARA COSER    ;                     ; 0,010   ; 0             ;
4934       ; FLEECE PERCHADO    ; 18-0601 GRIS        ; 0,560   ; 4             ; kg
           ; RIBB 2X2 LIVIANA   ; 18-0601             ; 0,070   ; 0             ;
           ; CORDON REDONDO     ;                     ; 1,40    ; 0             ; m
```

Reglas: la referencia vacía **hereda la anterior** (se pega el bloque de una ficha tal cual); desde la Ficha de costos la columna Referencia se omite; la primera fila puede ser encabezado (se detecta por "Ref" o "Material"); "Material" admite código de la app (`MP-JERSEY241`), código Odoo, `[CÓDIGO] nombre`, familia de Odoo, descripción del catálogo o un alias aprendido (alias: etapa 2); "Ver plantilla" pone el ejemplo, como en los otros modos (`plantilla`, 4527). Referencia que no existe en Productos: se ofrece crear el producto con nombre y colección (como `nuevoDeArchivo`, 3378) y queda en la cola de Clasificar; nunca se crea sin confirmar.

Detalles del pegado y de los archivos:

- La regla "dos o más espacios separan" vive **solo** en el modo `receta` (una función `partesReceta` nueva), no en `partes` (4543), que usan los otros cuatro modos de la carga masiva. Así no se rompe nada de lo que ya se pega hoy.
- Archivos `.csv` soltados: se leen como ArrayBuffer; se intenta UTF-8 y, si aparece U+FFFD, se decodifica con `TextDecoder('windows-1252')` (Excel en español guarda ANSI).

**Lo más barato de todo el proyecto**: pedir a quien hace la ficha digital una pestaña **RECETA** con exactamente esas seis columnas. Con eso el lector es copiar y pegar y no hace falta OCR nunca.

**Paso 2 · Revisión.** Una tabla agrupada por referencia (encabezado `tr.cat` con miniatura con lupa, "REF 4931 · HENLEY ML RIB", estado de la ficha y una pastilla si la referencia se creará o si la ficha está cerrada). Columnas por línea:

| Columna | Control | De dónde |
|---|---|---|
| Lo que dice la ficha | texto literal, debajo la nota en `.cod` | pegado |
| Material | combo con la búsqueda de la ficha (`buscarMat`, extraída de `filterCat` 2740, ver 3.2-B) con el candidato preseleccionado y la etiqueta de tipo `.catbadge`; si hay varios, lista de los 5 mejores | empate B (3.2) |
| Color | input con la lista de pantones (`#dl-pan`, 672) + "crear pantón" si no existe (`crearPantone`, extraída de `agregarPantone` 2722) | empate C |
| Consumo · Desp. % | `input.n` | pegado |
| UM | la del material en el catálogo; aviso ámbar si la ficha dice otra | empate E |
| Qué pasa | pastilla: "nueva" / "ya estaba" / "cambia 0.200 → **0.240**" (formato de `pintarDif`, 4004) / "sin empate" | comparación con `FICHAS[ref].lines` |
| Usar | casilla: verde marcada; ámbar y rojo desmarcadas | semáforo |

Barra destacada encima (fondo `var(--vino-soft)`, como `#lmo-cargar` 1073): "18 líneas · 14 empatadas · 3 por confirmar · 1 sin empate" y botones **Aceptar las verdes** · **Aplicar la misma corrección a las filas iguales** · **Crear los materiales que faltan** (patrón `agregarMat` 4626, con familia elegida de la lista y UM obligatoria; hace `CAT.push` primero y la línea después, en la misma acción).

Pie: **Cancelar** · **Aplicar a las fichas** · **Aplicar y exportar receta Odoo**.

"Guardar para después" (dejar la propuesta a medias en `FICHAS[ref].propuesta` para que otra persona la termine) **no va en el piloto**. Motivo: la ficha se guarda entera en una fila de `cst_fichas` (3690) y la última escritura gana (comentario 3710-3713); si otra persona tiene la ficha abierta y cambia algo, la propuesta se pierde. En etapa 2 se ofrece con un aviso al guardar ("otra persona puede pisar esto si edita la misma ficha") o se guarda en una fila aparte `REF#propuesta` de `cst_fichas`.

**Desperdicio visible en la ficha.** La Ficha de costos no muestra ni edita el desperdicio por línea (`rowsLines` 2626-2652 no tiene esa columna; solo la base de Configuración lo tiene, 922). Antes de que el lector escriba `d`, se agrega a la tabla de materiales una columna **Desp. %** (`input.n` → `setV(i,'d',v)`, que ya funciona porque `setV` es genérico, 2662) y en la celda Consumo un `title` con el consumo real `q×(1+d/100)`. Sin eso, la cantidad que va a Odoo incluye un número que nadie puede ver.

**Aplicar.** Por referencia: mismo código → se actualizan consumo, desperdicio y pantón; código nuevo → se agrega (con `empujarLinea`, extraída de `addLine` 2701); los insumos base (`BASE`, 2340: hilo, etiquetas y etiqueta de lavado, `IN-INS001` familia SATIN) se conservan; lo que la ficha digital no menciona **no se borra** (se lista en el aviso para que la persona decida; casilla por grupo "Reemplazar telas e insumos" para quien quiera partir de cero). Regla dura: **nunca** se hace `lines.push` con un código que no esté en `CAT`, porque `rowsLines` (2628) rompe la ficha entera al no encontrarlo. Ficha **cerrada** (Costeada sin re-costeo abierto): no se toca y se cuenta en el aviso; si el rol puede editar costos y marcó "abrir re-costeo", se abre la versión siguiente (`abrirRecosteo`, extraída de `recostearRef` 2975) y entonces sí se aplica. Después: `draw()`, `rowsProd()`, autoguardado y toast "Recetas aplicadas · 4 referencias, 23 líneas · 2 quedaron sin empatar: revísalas en la ficha". Al aplicar queda solo `FICHAS[ref].fuente = {tipo, archivo, fecha con hora, por}` (compacto, para no engordar la ficha en cada guardado).

### 3.2 Pieza B · Empate: de la ficha al catálogo y del catálogo a Odoo

Todo se normaliza como ya hace la app para nombres: mayúsculas, sin tildes, solo A-Z0-9 (`normCat`, 1400) y letras repetidas colapsadas (`colapsa`, 1401). Ojo: `colapsa` iguala letras repetidas (FLECCE = FLEECE) pero **no** OVERLOK con OVERLOCK; la regla 6 de abajo lo cubre.

Funciones puras que hay que extraer antes de usarlas desde el modal, porque las actuales están pegadas al DOM de la ficha:

- `filterCat` (2740) escribe en `#cb-list`. Se extrae `buscarMat(q)` (devuelve la lista, sin DOM) y `filterCat` la usa; el modal de revisión llama a `buscarMat`.
- `agregarPantone` (2722) lee `#np-pan` y `#np-nombre`. Se extrae `crearPantone(pan, nombre)`.
- `addLine` (2701) toca `#q-all` y llama `draw()`. Se extrae `empujarLinea(ref, {c,q,d,pan})`.
- `recostearRef` (2975) cambia `cur`, navega y hace scroll. Se extrae `abrirRecosteo(ref)`, que solo hace `f.edit=true`.

**A. Referencia** (texto o nombre de archivo → producto): exacta; luego cualquier trozo alfanumérico que coincida con una referencia existente probando los largos primero (`refDeArchivo`, 3361: `4823-2` gana a `4823`); si no existe, se ofrece crear.

**B. Material** (texto → material del catálogo). Antes de buscar se filtra por tipo: si el texto trae HILO, ETIQUETA, BOTON, CIERRE, ELASTICO, CORDON se busca solo en insumos; si trae JERSEY, RIBB, FLEECE, PIQUE, PLANA solo en telas. Cascada, se toma el primer escalón que resuelve:

| # | Regla | Semáforo |
|---|---|---|
| 1 | Igual al código de la app (`c`) o al **código Odoo** del material | verde (1.00) |
| 2 | Igual a un **alias** aprendido (etapa 2) | verde (1.00) |
| 3 | Igual a la familia o a la descripción de exactamente un material | verde (0.95) |
| 4 | `[CÓDIGO] nombre` → regla 1 | verde |
| 5 | Todas las palabras aparecen en descripción + código + familia de **un solo** material (lógica de `buscarMat`) | ámbar (0.80): confirmar |
| 6 | Parecido: normalizar con `normCat`, colapsar repetidas y además reemplazar `CK→K`, `QU→K`, `PH→F`, `LL→L`; si sigue sin candidato, distancia de edición ≤ 2 sobre la descripción con un único candidato (FLECCE PERCHADO, OVERLOK) | ámbar (0.65) |
| 7 | Varias coincidencias | ámbar (0.55): elegir entre las 5 mejores |
| 8 | Ninguna | rojo: buscar a mano o "Crear material" |

Verde ≥ 0.90 se aplica con un clic global; ámbar hay que confirmar; rojo hay que resolver. En etapa 2, cuando la persona confirma un ámbar o resuelve un rojo, el texto original se guarda como **alias** del material elegido (`CAT[i].alias`, casilla "recordar este nombre" marcada por defecto). Un alias solo nace de una confirmación humana, nunca de un empate por palabras. Los alias se ven y se borran en Materiales, columna **Alias** plegada en la tabla (`rowsCatMat`, 4645), con contador de veces y último uso, porque un alias mal enseñado se repite en todas las fichas siguientes.

**C. Color** (texto → pantón): código exacto (`19-4025`), nombre exacto, "código NOMBRE" (como `setLineColTxt`, 2654) o alias de pantón. Vacío, `-` o `COMBINADO` = sin color (aviso si el material es tela). Pantón desconocido = ámbar con "crear pantón". Decoración y servicios no llevan color. Si el texto trae el color pegado al material ("JERSEY 24/1 ROJO"), primero se separa lo que empata con un pantón y el resto se empata como material.

**D. Componente en Odoo** (material + pantón → referencia interna de Odoo). El material tiene un campo nuevo `odoo` (su referencia interna en Odoo) y, solo si en Odoo la tela existe por color, una tabla `colores` = {pantón → referencia Odoo de la variante}. Resolución en cascada, sin decidir de antemano cómo está su Odoo:

1. `colores[pantón]` si existe (tela por color o variante por color).
2. `odoo` genérico si el material no tiene colores cargados (producto por familia).
3. Material con colores cargados y línea sin pantón resoluble → **bloquea**.
4. Sin `odoo` → **bloquea**.

**Cómo se llena en el piloto**: sin tabla de empate. `odoo` y `um` se cargan con la carga masiva de Materiales, que gana dos columnas al final (sección 4), y `cu` a mano o con "Copiar REF como código único".

**Cómo se llena en etapa 2 ("Empatar con Odoo")**: modo nuevo en la carga masiva de Materiales (`abrirMasivaMat`, 4513). De Odoo se exporta **product.product** (Inventario › Productos › *Variantes de producto* › Exportar), no las plantillas, con: Referencia interna · Nombre · Unidad de medida · Valores de atributo · Categoría de producto · Activo. Reglas: varias filas de Odoo con la misma familia y distinto color empatan con **un** material de la app y llenan `colores[pantón]`; una sola fila sin color llena `odoo`; la UdM llega como nombre traducido y se empata contra la lista cerrada por nombre (`Unidades→u`, `kg`, `g`, `m`, `cm`, `Docenas→doc`). Los nombres de color de Odoo que no coincidan con un pantón se resuelven con alias de pantón. La app propone el material de la app por familia o descripción (solo cuando hay un único candidato); la propuesta se revisa en una tabla y se confirma; lo que no empate queda en un contador "N productos de Odoo sin material" para asignar a mano. Con el mismo pegado se aceptan las **prendas terminadas**, que sirven para validar el código único (existe en Odoo, está activo, no se repite en dos referencias de la app; hoy `cu` es texto libre sin validación, 3177) y para proponerlo cuando la referencia de Odoo contiene la REF de la app. Si resulta que en Odoo la referencia de la prenda es la misma REF, un botón **Copiar REF como código único** lo llena en masa. La app guarda la fecha de la última carga y avisa si pasaron más de 30 días.

**E. Unidad.** `um` deja de ser texto libre y pasa a lista cerrada con su equivalencia en Odoo:

| UM en la app | Se usa para | Odoo |
|---|---|---|
| `u` | unidades, prenda | `uom.product_uom_unit` (Unidades) |
| `kg` | tela de punto | `uom.product_uom_kgm` |
| `g` | hilos, adornos | `uom.product_uom_gram` |
| `m` | tela plana, elástico, cordón, framilón | `uom.product_uom_meter` |
| `cm` | cintas | `uom.product_uom_cm` |
| `doc` | botones por docena | `uom.product_uom_dozen` |
| `prenda`, `color`, `mil punt` | decoración y servicios | no se exporta |

La lista cerrada se impone en las cuatro entradas: `setMat` (2681) rechaza valores fuera de la lista; la fila de Materiales (4655) pasa de `input` a `select`; la carga masiva de materiales (4606-4608) normaliza `KGS/KG→kg`, `MTS/M→m`, `UND/PZA/U→u` y rechaza lo demás; `agregarMat` (4628) sigue naciendo con `u`.

Acción **Aplicar UM a los seleccionados** en la barra de selección de Materiales (molde de "Aplicar familia", `aplicarFamiliaMasiva` 4681) para corregir las telas de una vez. En etapa 2, el pegado "Empatar con Odoo" trae la UdM real de cada producto y la **propone** con un clic. La exportación **no manda** la UdM de línea (Odoo toma la del componente, que es lo más seguro), pero **valida** que la UM de la app coincida con la de Odoo para ese componente; si difieren, bloquea: "la app dice kg y Odoo tiene m para MP-000117: corrige uno de los dos". Es la única forma de garantizar que el 0.245 esté en la unidad correcta, porque Odoo no lo rechaza al importar. Unidades leídas de la ficha (KGS, MTS, UND, PZA, PAR) se traducen a la lista y, si difieren del catálogo, avisan; nunca se convierte nada solo.

Precedencia de esa validación: si la lista de Odoo **no** está cargada (piloto), "UM app ≠ UM Odoo" no se puede evaluar y se degrada al aviso "Tela con UM u". Con la lista cargada, misma categoría pero distinta unidad (g/kg, cm/m) también **bloquea**, porque no se manda la columna de UdM de línea. Alternativa documentada para etapa 2: mandar `bom_line_ids/product_uom_id/id` **en todas las filas** (nunca vacía) desde la lista cerrada, y validar solo la categoría.

**F. Qué líneas entran**

| Tipo (`k`) | ¿Va? | Motivo |
|---|---|---|
| Materia prima (`mp`) | Sí | Componente |
| Insumos (`ins`), incluidos los base (hilo, etiquetas, etiqueta de lavado) | Sí | Componente |
| Decoración (`dec`) | No por defecto | Serigrafía va por "color" y bordado por "mil puntadas": no son cantidades de inventario. Una fila `dec` entra solo si tiene `odoo` **y** su UM está en la lista exportable (`u`, `kg`, `g`, `m`, `cm`, `doc`). Se listan en Avisos |
| Servicios (`srv`: tinturado, lavado) | No | En Odoo son subcontratación u operación; en Odoo 18 un servicio ni siquiera puede ser componente. Se listan en Avisos |

Dos detalles de decoración e insumos:

- `prenda`, `color` y `mil punt` nunca se exportan. Al asignarle código Odoo a `DC-DTF`, `DC-VINIL` o `DC-BAPL` (1536-1541) se les cambia la UM a `u`.
- `IN-INS001` (ETIQUETA DE LAVADO, familia SATIN, 1576) e `IN-SATIN` (1618): si en Odoo son el mismo producto, se les pone el mismo `odoo` y `BASE` (2340) se cambia a un solo código; si no, se corrige la familia de `IN-INS001`. Es la pregunta 14 de la sección 8; hasta tener respuesta, el exportador avisa "dos líneas del mismo componente" cuando ambos aparecen en una ficha (la 4823 precargada los trae, 2449).

**G. Cantidad.** Consumo × (1 + desperdicio/100), **3 decimales**, número nativo en el .xlsx (sin pelea de coma y punto). Es la regla de "Exportar BOM" hoy (5712). Interruptor de configuración "cantidad neta" por si Odoo maneja la merma aparte. Consumo 0 en tela o insumo bloquea.

Talla y colorway (decisión y pregunta):

- Cantidad por prenda: **una sola cifra por REF**. Supuesto para el piloto: la que ya tiene la ficha (consumo promedio de la curva, que es lo que se costea). Si la ficha digital trae consumo por talla, el lector propone el promedio ponderado por la curva estándar (o la talla base si no hay curva) y lo marca ámbar. Pregunta a la usuaria: promedio o talla base (pregunta 8).
- Colorway: si en Odoo la prenda es un producto por REF+color, la app hoy no puede generar N recetas. Supuesto: LdM por plantilla, una por REF, con la variante de tela del pantón de la ficha. Si la respuesta es "producto por color" (pregunta 5), el camino es una REF por colorway en la app (`4823-ROJO`) con `cu` propio, y el lector acepta "Referencia + color" como clave.

### 3.3 Pieza C · Exportador "Receta Odoo"

**Dónde y qué entra.** Botón **Exportar receta Odoo (Excel)** junto a **Exportar BOM (Excel)** en Productos (781); el botón actual se mantiene como reporte plano. Segundo acceso en la cabecera de la Ficha para una sola prenda. Si hay productos marcados con el check (selección múltiple `SELP`, barra `#bulk-prod` 763), **solo esos**; si no, todas las activas con ficha **costeada** (`saved` y sin re-costeo abierto). Casilla "Incluir borradores y fichas en avance", apagada por defecto. KPI nuevo en Productos **Listas para Odoo** (molde de "Sin código único", `kpis` 3137-3153) que filtra la lista.

**Validación antes de generar**

| Bloquea la ficha | Solo avisa |
|---|---|
| Sin código único, repetido en otra referencia activa, o no encontrado / archivado en la lista de Odoo cargada | Líneas de decoración o servicio excluidas |
| Prenda o material sin producto en Odoo ("BLOQUEA · sin producto en Odoo"; la lista de altas va al dueño del paso 3-bis) | Borrador o ficha en avance incluida a propósito |
| Línea mp/ins con material sin código Odoo o con componente inactivo | Tela con UM `u` en la app (y, si la lista de Odoo no está cargada, es lo único que se puede decir de la UM) |
| Material con colores por pantón y pantón vacío, `-` o `COMBINADO` | Desperdicio 0 en una tela |
| Consumo 0 en mp/ins | Consumo fuera de rango: punto > 1.5 kg o < 0.05 kg, plana > 3 m, insumo > 20 u (umbrales editables) |
| UM de la app distinta de la UM de Odoo del componente (solo con la lista de Odoo cargada) | Misma huella que la última exportación ("sin cambios frente a lo enviado") |
| Ficha sin ninguna línea mp/ins | Dos líneas del mismo componente en una ficha (`IN-INS001` e `IN-SATIN` con el mismo `odoo`) |
| Dos `cu` distintos que saneados dan el mismo `id` (`bom_<cu>`): bloquea ambas | |

Las fichas bloqueadas no se mezclan con las buenas: el archivo sale solo con las que pasan y el resumen dice "12 recetas listas · 71 líneas · 3 omitidas (ver hoja Avisos)".

**Archivo `Receta_Odoo_AAAA-MM-DD.xlsx`**, generado con `libroXlsx` (5842), tres hojas. Encabezados con los **nombres técnicos** de Odoo: el asistente los reconoce sin importar si la base está en Español (España), Español (Ecuador) o Latinoamérica.

Hoja 1 · `mrp.bom` (la que se importa, y por eso va primera). Una receta = primera fila con cabecera + primer componente; filas siguientes con las columnas de cabecera **vacías** (así Odoo agrupa; `hojaXml` ya omite celdas vacías, 5803). **No existe columna de unidad de línea**: si la columna estuviera presente pero vacía, el importador la convertiría en "falso" y la importación fallaría [P: coherente con el motor, se prueba el día 1]; omitida, Odoo copia la UdM del producto componente.

| Encabezado exacto | Valor | Regla |
|---|---|---|
| `id` | `bom_4823` | `bom_` + código único saneado a `[a-z0-9_]`. Un punto en el id solo falla si lo de antes es un módulo instalado; se sanea para evitar ambigüedad y colisiones, y el saneado detecta cuando dos `cu` distintos caen en el mismo id. Misma clave = actualiza en vez de duplicar |
| `product_tmpl_id` | `4823` | Código único (referencia interna de la prenda en Odoo), tal cual está en Odoo |
| `code` | `4823 v2 · 23-sep-2026` | Referencia visible de la LdM: REF de la app, versión de la ficha y fecha de cierre |
| `product_qty` | `1` | Una prenda |
| `product_uom_id/id` | `uom.product_uom_unit` | Se manda siempre (si se omite, Odoo pone la primera UdM de la base, no la del producto) |
| `type` | `normal` | "Fabricar este producto" |
| `bom_line_ids/id` | `bom_4823_mp_000117` | id de cabecera + `_` + código Odoo del componente saneado; `_2`, `_3` si el mismo componente se repite (misma tela en cuerpo y puños). Estable por componente, no por posición |
| `bom_line_ids/product_id` | `MP-000117` | Referencia interna del componente en Odoo (de la variante, si hay color). Nunca el nombre, nunca `MP-JERSEY241` salvo que sea de verdad el de Odoo |
| `bom_line_ids/product_qty` | `0.245` | Cantidad con desperdicio, 3 decimales, número |
| `bom_line_ids/sequence` | `10, 20, 30…` | Orden de la ficha (telas, luego insumos) |

Ejemplo con dos referencias. La 4823 es real (líneas precargadas en `PRE`, 2449: RIBB 2X2 LIVIANA 0.245, hilo 0.014, etiquetas 1, satín 1; el tinturado industrial es servicio y no va). Los códigos de Odoo (`MP-000117`, `IN-000031`…) son **supuestos** y saldrán de la carga masiva del piloto o del pegado "Empatar con Odoo" de etapa 2:

```
id        product_tmpl_id  code                   product_qty  product_uom_id/id     type    bom_line_ids/id         bom_line_ids/product_id  bom_line_ids/product_qty  bom_line_ids/sequence
bom_4823  4823             4823 v2 · 23-sep-2026  1            uom.product_uom_unit  normal  bom_4823_mp_000117      MP-000117                0.245                     10
                                                                                            bom_4823_in_000031      IN-000031                0.014                     20
                                                                                            bom_4823_in_000210      IN-000210                1                         30
                                                                                            bom_4823_in_000198      IN-000198                1                         40
bom_4931  4931             4931 v1 · 22-sep-2026  1            uom.product_uom_unit  normal  bom_4931_mp_000140      MP-000140                0.252                     10
                                                                                            bom_4931_in_000055      IN-000055                1                         20
                                                                                            bom_4931_in_000031      IN-000031                0.010                     30
```

Hoja 2 · `Lectura` (para ojos humanos, no se importa): Referencia · Producto · Código único · Versión · Estado ficha · Material (app) · Código Odoo · Tipo · Familia · Color (pantón y nombre) · Consumo neto · Desperdicio % · Cantidad Odoo · UM app · UM Odoo.

Hoja 3 · `Avisos`: Referencia · Nivel (BLOQUEA / AVISO) · Detalle · Acción en Odoo (crea / actualiza). Lleva además dos secciones: **"Sin producto en Odoo"** (lista de altas para el paso 3-bis: REF, nombre, familia, UM, color) y **"En Odoo hay que quitar a mano"** (las líneas de `odoo.lineas` de la última exportación que ya no están en la ficha; la importación nunca borra líneas).

Alternativa `.csv` con las mismas filas de la hoja 1: separador `;`, punto decimal, UTF-8 con BOM, campos con `;` entre comillas. Va por el modal de vista previa actual (`ovl`, 1157: Copiar / Descargar archivo). Para el .xlsx la descarga es directa como en `xlsxFichas` (6025-6033); la vista previa muestra en `ovl` el resumen y la hoja Avisos, y hace falta un botón condicional "Descargar Excel" en ese modal, porque hoy sus tres botones son fijos (1162-1164) y los comparten otras dos exportaciones.

**Versiones y reimportación.** Dos modos, uno se elige en configuración según su Odoo:

- **Actualizar en sitio** (Odoo 17/18): `id` = `bom_<cu>`; reimportar actualiza la cabecera y, gracias a `bom_line_ids/id`, cada línea existente; las nuevas se crean. Las líneas que desaparecieron de la ficha **no se borran solas**: la hoja Avisos las lista.
- **Una LdM por versión** (Odoo 16, donde el id por línea es [NV], o si prefieren historial en Odoo): `id` = `bom_<cu>_v<ver>`, y una hoja `archivar` (`id ; active = False`) para desactivar la versión anterior. Importar `active` por id externo es [P]: se prueba una vez en su base; si no funciona, la hoja sirve como lista para archivar a mano.

**Checklist de reimportación y compatibilidad del archivo**

1. El asistente de Odoo lee por defecto la **primera hoja** del .xlsx (o la elegida en "Hoja"): por eso `mrp.bom` va primera; Lectura y Avisos no se importan nunca.
2. El .xlsx de la app usa celdas `inlineStr` y ZIP sin comprimir (`libroXlsx` 5842, `zipAlmacenado` 5753): un archivo hecho en Excel no prueba que Odoo lo lea [NV]. La prueba del día 1 se hace con un archivo generado por `libroXlsx` (basta un exportador mínimo de una ficha o `xlsxFichas` re-nombrado). Si Odoo lo rechaza, el CSV es el camino y se dice el día 1.
3. "Columna de UdM de línea presente pero vacía = falso = falla" es [P]: entra en la prueba del día 1 (importar una vez con la columna vacía y ver el error).
4. `active = False` por id externo (modo "una LdM por versión") es [P]: probar una vez; si no funciona, la hoja `archivar` es lista para hacerlo a mano.
5. Avisos lleva la sección "En Odoo hay que quitar a mano" con las líneas de `odoo.lineas` que ya no están en la ficha.
6. Sanear el id detecta colisiones entre dos `cu` (sección 4).

**Registro en la app.** Al descargar, cada ficha exportada guarda:

```
FICHAS[ref].odoo = {
  estado: 'exportada' | 'importada',
  ver, code,                              // versión y referencia de la LdM
  lineas: [[codigoOdoo, cantidad], ...],  // lo que salió, ordenado por código
  crc,                                    // crc32 (5752) del JSON de `lineas`, para comparar rápido en filaProd
  fecha,                                  // fecha y hora local con desfase (toISOString() da UTC)
  por: NOMBRE,
  hist: [{estado, ver, fecha, por}]       // solo cabeceras, sin líneas
}
```

"Líneas quitadas desde la última exportación" en Avisos = `odoo.lineas` menos las líneas actuales; sin `lineas` guardadas el CRC no puede decirlo. Al pintar la fila del producto (`filaProd`, 3169) se compara el `crc` con la ficha actual y se muestra "Odoo v2" (verde), "Exportada v2 · sin confirmar" (ámbar) o "Cambió tras exportar" (color de falta). Botón **Marcar importadas en Odoo** en la barra de selección (`#bulk-prod`) y en la cabecera de la ficha: pasa a `importada` con fecha, hora y persona. Es la primera vez que la app registra quién hizo qué (hoy `NOMBRE` existe en memoria, 3486, pero no se escribe en ninguna fila). KPIs condicionales: Listas para Odoo · Exportadas sin confirmar · Cambiaron tras exportar · En Odoo.

**Permisos.** `exportarRecetaOdoo` y "Marcar importadas" exigen `puedeEditarCostos()` (3488) dentro de la función (toast "Sin permiso", molde `limpiarMPeIns` 4690), porque escriben en la ficha y `marcarCambio` (4104) no guarda nada para quien no puede editar. El lector exige `puedeEditar()`. Quien importe en Odoo y no tenga rol de edición en la app le avisa a planificación, que marca.

**Cómo se importa en Odoo (procedimiento)**

1. Una sola vez: Ajustes › Técnico › Precisión decimal › "Product Unit of Measure" → 3 decimales (por defecto son 2 y 0.245 se guardaría como 0.25).
2. Fabricación › Productos › Listas de materiales › menú de acciones (engranaje) › Importar registros › subir el .xlsx (hoja `mrp.bom`).
3. Verificar que las columnas se emparejaron solas; si alguna `bom_line_ids/...` no aparece, activar "Permitir emparejamiento con subcampos".
4. En Producto y Componente **no** activar "Crear nuevos valores": si un código no existe, mejor que falle a que cree un producto fantasma.
5. **Probar** → si está en verde, **Importar**. Un error en una fila aborta todo el archivo: se corrige en la app y se vuelve a exportar.
6. Volver a la app y **Marcar importadas**.

---

## 4. Qué existe ya y se reutiliza, y qué es nuevo

**Se reutiliza tal cual o como molde**

| Pieza existente | Línea | Para qué |
|---|---|---|
| `exportarBOM` (bucle `activos()` → `FICHAS[x.r].lines` → `byCode`) | 5704-5719, 3115, 1690 | Fuente de datos del exportador |
| `libroXlsx`, `hojaXml`, `zipAlmacenado` (xlsx sin librerías; celdas vacías omitidas) | 5842, 5794, 5753 | Archivo Receta_Odoo con números nativos |
| Modal `ovl` + `copiarCSV`/`bajarCSV` | 1157-1167, 6071, 6076 | Vista previa y alternativa CSV |
| Descarga directa de `xlsxFichas` | 6025-6033 | Descarga del .xlsx |
| Modal `ovl2`, `partes`, `num`, `MAY`, `plantilla`, `procesarMasiva` | 1311, 4543, 2472, 2933, 4527, 4547 | Pegado y parser tolerante; modo nuevo `receta` (piloto) y `empatar-odoo` (etapa 2) |
| `filterCat` (molde, requiere extraer `buscarMat`), `normCat`, `colapsa` | 2740, 1400, 1401 | Empate de material por palabras y por parecido |
| `setLineColTxt`, `agregarPantone` (molde, requiere extraer `crearPantone`), `pantoneNombre`, `#dl-pan` | 2654, 2722, 2706, 672 | Validar y crear pantones |
| `refDeArchivo`, `nuevoDeArchivo`, `carpetaDe` | 3361, 3378, 3392 | Referencia desde el nombre de archivo; crear producto |
| `recetaDe`, `nuevaFicha`, `addLine` (molde, requiere extraer `empujarLinea`), `BASE` | 2387, 2438, 2701, 2340 | Ficha nueva con receta base; agregar líneas |
| `ovl3` (detectar → revisar → aplicar), `pintarRC`, `aplicarRecortes` | 1172-1192, 4477, 4496 | Molde del modal de revisión |
| `ovl-clasif` ("Guardar y siguiente") y `ovl-fotos` (tarjetas de origen) | 1249-1279, 1222-1248 | Molde de cola y de paso 1 |
| `pintarDif`, `difLineas` | 4004, 3984 | Columna "Qué pasa" (0.200 → 0.240) |
| `recostearRef` (molde, requiere extraer `abrirRecosteo`), `RO()` | 2975, 2460 | Fichas cerradas |
| `rowsLines`, `setV` | 2626-2652, 2662 | Columna Desp. % en la ficha |
| `kpis` (KPI `sincu`), `filaProd`, `pintarBulkProd`, `#bulk-prod` | 3137-3153, 3169, 3090, 763 | KPIs, pastillas, botón "Marcar importadas" |
| `rowsCatMat`, `agregarMat`, `setMat`, `#bulk-mat`, `aplicarFamiliaMasiva` | 4645, 4626, 2681, 807, 4681 | Columnas Código Odoo, UM (select), Alias; "Aplicar UM" |
| `limpiarMPeIns` | 4689-4706 | Debe conservar `odoo`, `colores`, `alias` y `um` al restablecer |
| `setP` | 3275 | `cu` con `trim()` y aviso de repetido |
| `crc32` | 5752 | Huella de la receta exportada |
| `filas()` (manda el objeto entero) | 3672-3702 | Los campos nuevos viajan solos a Supabase |
| `toast`, `cerrar`, `hoyISO`, `forzarGuardado` | 3032, 4622, 2934, 4169 | Avisos y guardado |
| `cargarRutaBase` (`ops.push` en 5198), carga masiva de operaciones (push en 4562), `copiarOps` | 5185, 5198, 4562, 5052 | Guardar desde ya `lmo`, `maq`, `cenCod` y `seq` en cada operación, para no perder el vínculo con el catálogo de Martha (cambio de una línea en cada sitio, compatible con lo guardado) |

**Nuevo en la app** (todo en `index.html`)

- Campos: `CAT[i].odoo`, `CAT[i].colores` = `{pantón: referencia Odoo de la variante}`, `CAT[i].alias` (etapa 2), `CAT[i].um` como lista cerrada; `REFS[i].cu` validado y sin repetidos; `FICHAS[ref].odoo`, `FICHAS[ref].fuente`; `FICHAS[ref].propuesta` solo en etapa 2.
- Modal `ovl-receta` (dos pasos), función `exportarRecetaOdoo`, modo `receta` en la carga masiva (y `empatar-odoo` en etapa 2), columnas Código Odoo / UM / Alias en Materiales, "Aplicar UM", "Copiar REF como código único", KPIs y pastillas, "Marcar importadas", tarjeta **Odoo** en Configuración (sub-navegación `#cfg-nav`, 839) con: versión de Odoo, modo de versiones, cantidad con o sin desperdicio, decimales, incluir decoración, fecha de la última carga del catálogo.
- Columna Desp. % en `rowsLines` (2626-2652) con `setV(i,'d',v)` (2662).
- Select de UM en la fila de Materiales (4655) en lugar del `input` libre.
- `limpiarMPeIns` (4689-4706) borra todos los mp/ins y reinserta `CAT_ODOO` (1552) limpio: destruiría `odoo`, `colores`, `alias` y la UM corregida. Cambio: al reinsertar, conservar esos cuatro campos del material que se borró (`{...m, odoo, colores, alias, um}`), y si algún material tiene `odoo` cargado, pedir una segunda confirmación que lo diga.
- Carga masiva de materiales, columnas nuevas al final: `Código ; Descripción ; Tipo ; UM ; Costo ; Código Odoo ; Familia`. Con esto se llenan `odoo` y `um` en el piloto sin construir "Empatar con Odoo". La rama de materiales (4606-4608) normaliza la UM a la lista cerrada y rechaza lo demás.
- `setP` (3275): `setP(i,'cu',v)` pasa a hacer `trim()` y a avisar si otra referencia activa ya lo tiene; el saneado `bom_<cu>` a `[a-z0-9_]` detecta colisiones (dos `cu` distintos → mismo id) y bloquea ambas.
- Regla del lector: **nunca** se hace `lines.push` con un código que no esté en `CAT` (`rowsLines` 2628 rompe la ficha entera). "Crear los materiales que faltan" hace `CAT.push` primero y la línea después, en la misma acción.
- Funciones puras extraídas: `buscarMat`, `crearPantone`, `empujarLinea`, `abrirRecosteo`, `partesReceta` (sección 3.2 y 3.1).
- Ocultar los botones al rol consulta requiere lógica nueva: `aplicarRolUI` (3665) hoy solo oculta pestañas a prearmado. Por eso los permisos se exigen también dentro de cada función (sección 3.3, Permisos).

**En Supabase**: nada para el piloto. Más adelante, solo si se decide: bucket **privado** `cst-fichas` para guardar las fichas originales (no `cst-fotos`, que es público: `subirAlmacen` 3818 devuelve la URL pública y una ficha de marca licenciada quedaría a la vista de cualquiera con el enlace), y las Edge Functions de la etapa 3. Cualquier tabla nueva exige además su rama en `filas()`, `cargarNube`, `adoptarEstado`, `estado()` (4056), `aplicarEstado` (4250) y `filasDeRespaldo` (4283): por eso el piloto no crea ninguna.

**Fuera de la app**, siempre: leer .xlsx real, OCR de fotos y hablar con Odoo por API (un navegador no puede llamar a Odoo directo por CORS).

---

## 5. Qué hace cada persona y cómo se corrigen los errores

| Paso | Quién | Dónde |
|---|---|---|
| Pedir a Odoo la exportación de product.product y una LdM "compatible con importación"; confirmar versión, idioma y base de prueba (antes del día 1) | Planificación | Odoo, fuera de la app |
| Cargar código Odoo y UM (carga masiva de Materiales en el piloto; "Empatar con Odoo" en etapa 2) y códigos únicos (una vez, y cuando haya materiales nuevos) | Planificación / admin | Materiales; Productos |
| Pedir a diseño la pestaña RECETA en la ficha digital | Planificación | Fuera de la app |
| Leer la ficha, revisar empates, aplicar, enviar para aprobación | Prearmado | Modal Leer ficha digital; Ficha |
| Crear en Odoo las prendas y telas nuevas que lista Avisos › "Sin producto en Odoo" | Quien administra productos en Odoo (nombre por definir) | Odoo |
| Revisar telas nuevas, colores raros, consumos que no cuadran; rutas cuando se exporten | Martha | Ficha; Operaciones |
| Aprobar costo (cierra vN), exportar receta, revisar hoja Avisos | Planificación | Ficha; Productos |
| Importar en Odoo con "Probar" | Persona con usuario en Odoo (nombre por definir); si no tiene rol de edición en la app, avisa a planificación | Odoo |
| Marcar importadas | Planificación | Productos |
| Recargar la lista de Odoo cuando pasen 30 días o entren materiales nuevos | Planificación | Materiales |
| Validar operaciones el día que se exporten | Martha | Operaciones |

**Excepciones: qué se ve, qué se hace, qué queda**

| Situación | Qué ve la persona | Qué hace | Qué queda registrado |
|---|---|---|---|
| Referencia que no existe en Productos | "No está en Productos · se creará" | Acepta (nombre y colección desde el archivo) o corrige la REF | Producto nuevo en cola de Clasificar |
| Material que no está en el catálogo | Fila roja "sin empate" | Elige uno, o "Crear los materiales que faltan" (con familia Odoo y UM), o deja pendiente | Alias si eligió (etapa 2); material nuevo sin código Odoo (bloquea la exportación hasta que se le ponga) |
| Empate dudoso (RIBB LIVIANA vs PESADA) | Fila ámbar con candidatos | Elige; "aplicar a las filas iguales" | Alias del material elegido (etapa 2) |
| Pantón que no existe | "Pantón no encontrado" | Crea el pantón desde el modal o elige otro | Pantón nuevo; alias |
| Color `COMBINADO` o `-` | "Pendiente de color" | Parte la línea en dos pantones, o deja sin color si el componente no depende del color | Decisión por línea |
| Consumo 0, vacío o ilegible | "Consumo pendiente" | Escribe el consumo | Bloquea la exportación de esa referencia hasta resolver |
| La ficha dice kg y el catálogo dice u | Aviso ámbar en UM | Corrige la UM en Materiales (no desde el modal) | UM del material |
| Ficha de costos cerrada y la lectura difiere | "Cerrada · no se toca" + comparación de líneas | Quien edita costos abre re-costeo y aplica; prearmado solo avisa | Re-costeo v(N+1) en curso |
| Producto sin código único | KPI "Sin código único"; en Avisos "BLOQUEA" | Llena el `cu` (o lo copia de la REF en masa) | Sale en la siguiente exportación |
| Prenda o material que no existe en Odoo | "BLOQUEA · sin producto en Odoo" | Manda la lista de altas (Avisos › "Sin producto en Odoo") al dueño del paso 3-bis | Sale en la siguiente exportación |
| Ficha con consumo por talla | Nota en la fila con las otras tallas; promedio ponderado propuesto en ámbar | Confirma promedio o talla base | Una sola cifra por REF va a la receta |
| Servicio o decoración en la ficha | Fila "no va a Odoo como componente" | Nada; sigue en la ficha para el costo | Fuera de la receta (etapa 3 decide si va como operación) |
| Alias mal enseñado (etapa 2) | Fichas siguientes empatan mal en verde | Lo borra en Materiales › columna Alias | Alias eliminado |
| Odoo rechaza el archivo en "Probar" | Mensaje de Odoo (producto no encontrado, unidad) | Corrige el código en Materiales o el `cu` en Productos y re-exporta; no toca la LdM en Odoo | Nueva exportación, nueva huella |
| Se cambió la ficha después de exportar | Pastilla "Cambió tras exportar" | Re-costea si está cerrada, aprueba, re-exporta; en Odoo actualiza por el mismo id | Estado vuelve a exportada; Avisos lista líneas a quitar a mano |
| Se olvidó marcar "importada" | Pastilla "Exportada · sin confirmar" y KPI | Marca cuando confirme en Odoo | Estado importada con fecha y persona (hasta la API de la etapa 3 nadie lo puede verificar solo) |

---

## 6. Etapas

**Semana 1 · Piloto con 5 referencias de BULL DOG** (las que ya están cargadas con foto)

- **Día 0** (planificación): pedir a Odoo la exportación de product.product y una LdM "compatible con importación"; confirmar versión, idioma y si hay base de prueba. Sin esto no hay día 1.
- **Día 1**: cronometrar la línea base con 3 referencias (leer la ficha digital + teclear consumos en la app + armar la LdM en Odoo a mano), para poder decir después cuánto se ahorró. Cargar por carga masiva de Materiales `odoo` y `um` de los 4 materiales de 4823 y su `cu`. Probar en Odoo **un archivo generado por la app** (punto 2 del checklist de la sección 3.3: generado con `libroXlsx`, con un exportador mínimo de una ficha o `xlsxFichas` re-nombrado) con la receta de 4823, y además una vez con la columna de UdM de línea vacía (punto 3 de ese checklist). Si entra, el formato, la versión, el idioma y la precisión decimal quedan validados antes de escribir el exportador; si no entra, el mensaje de Odoo dice exactamente qué ajustar, y si rechaza el .xlsx el CSV es el camino.
- **Días 2-4** (código): `exportarRecetaOdoo` con validaciones, hojas mrp.bom / Lectura / Avisos, registro `FICHAS[ref].odoo` (sección 3.3), KPI "Listas para Odoo", "Marcar importadas"; columnas Código Odoo y UM (select) en Materiales; Desp. % en la ficha (sección 3.1); `lmo/maq/cenCod/seq` en `cargarRutaBase` (5198), carga masiva de operaciones (4562) y `copiarOps` (5052). El modo `receta` básico se abre **solo desde la Ficha de costos**, sobre la ficha abierta, y muestra la tabla de revisión mínima (material propuesto · consumo · usar) antes de Aplicar: así no rompe la regla 4. "Empatar con Odoo", alias y "Guardar para después" pasan a etapa 2.
- **Día 5**: las 5 referencias reales, primero en base de prueba y después en producción. La "ida y vuelta" (leer una LdM exportada de Odoo hacia la ficha) se hace a mano con la carga masiva, no con un modo nuevo.
- Criterio de paso: 5 recetas importadas sin editar el archivo a mano; tiempo medido contra la línea base. Plazo honesto: los días de código son 3; el cuello real es tener los códigos Odoo y las UM cargadas, que es trabajo de la planta y por eso arranca el día 0.

**Etapa 2 · Colección completa (semanas 2 a 4)**

- Modal `ovl-receta` completo: origen (pegar, soltar .csv, imagen/PDF a la vista), acceso desde Productos para varias prendas, revisión con semáforo completo, alias que aprenden, "aplicar a las filas iguales", aplicar con reglas de ficha cerrada, `fuente` en la ficha.
- "Guardar para después" (`FICHAS[ref].propuesta`) con aviso al guardar o en fila aparte `REF#propuesta` de `cst_fichas`, y KPI "Lectura por revisar".
- "Empatar con Odoo" en la carga masiva de Materiales (pegado de product.product, `colores` por pantón, UdM propuesta, prendas terminadas para validar `cu`, fecha de la última carga y aviso a los 30 días).
- Columna Alias en Materiales, "Aplicar UM", KPIs de lectura (Lectura por revisar, Con pendientes, Cambiaron tras exportar), tarjeta **Receta Odoo** en el bloque Costos de la ficha (estado, versión exportada frente a actual, pendientes), tarjeta Odoo en Configuración, tarjeta "Recetas Odoo" en Reportes (fichas leídas, aplicadas, importadas, % de líneas empatadas sin corrección, re-exportaciones por colección).
- Si hace falta: `bom_line_ids/product_uom_id/id` en todas las filas desde la lista cerrada, validando solo la categoría (sección 3.2-E).
- Correr con la siguiente colección entera (SOCKIES o la que venga).
- Criterio de paso: al menos 80 % de líneas empatadas sin corrección en la segunda colección y cero duplicados en Odoo.

**Etapa 3 · Automatizar lo que sobre (solo si el volumen o el formato lo justifican)**

- **Operaciones a Odoo** (con Martha): mapa centro de la app → nombre exacto del centro de trabajo en Odoo (`CEN[i].odoo`), filas de continuación con `operation_ids/id`, `/name`, `/workcenter_id`, `/time_cycle_manual` (minutos; si se omite Odoo pone 60), decisión sobre servicios como operación o subcontratación.
- **Lector de .xlsx real** en el navegador (ZIP + `DecompressionStream` + `DOMParser`, unas 150 líneas, sin librerías), si diseño no puede entregar la pestaña RECETA.
- **Lectura de fotos y PDF escaneados con IA**: primero una prueba de concepto sin construir nada (10-20 fichas reales por script o chat, con un esquema fijo: texto literal por línea, descripción, familia sugerida, color, pantón, consumo, unidad, desperdicio, confianza, calidad de lectura) midiendo % de líneas y consumos correctos. Solo si supera 90 % en fichas legibles: una función en el mismo Supabase con la clave de la API como secreto, bucket privado `cst-fichas`, deduplicación por hash del archivo, lectura cruda guardada aparte de lo aplicado, y el resultado entrando al mismo modal de revisión. Costo del orden de centavos por ficha; implica que las fichas salgan de la empresa hacia el proveedor del modelo: es una decisión de ustedes (y de la marca, si el contrato lo exige).
- **Carga directa a Odoo por API** (JSON-RPC desde una función de Supabase): empate exacto por referencia interna con error claro, reemplazo completo de líneas sin residuos, archivado automático de la versión anterior, "importada" marcada sola. Debe usar el mismo espacio de ids externos que la importación por archivo (`__import__`) para encontrar las LdM ya cargadas. Requiere Odoo accesible desde internet y un usuario con clave API.

---

## 7. Supuestos explícitos

Cada pregunta de la sección 8 lleva el supuesto con el que se avanza si no hay respuesta. Los tres que más pesan: que la ficha de costos de la app es (o será) la fuente única de la receta; que en Odoo la prenda y cada material tienen una referencia interna estable con la que se empata (y que los códigos `MP-…/IN-…` de la app **no** son esas referencias, sino nombres de familia recortados); y que la lista de materiales de Odoo es por plantilla de producto (una por REF, consumo promedio por talla), que es exactamente lo que la ficha ya calcula.

---

## 8. Lo que necesitamos de ti para arrancar

Quince preguntas. Las cuatro primeras bloquean el día 1; el resto tiene un supuesto con el que se avanza si no hay respuesta.

1. ¿En qué formato viene la ficha digital (Excel/Sheets, PDF con texto, PDF escaneado o foto, o es esta misma app)? Manda 2-3 ejemplos. *Supuesto: tabla en Excel, una prenda por pestaña.*
2. ¿Versión y edición de Odoo, idioma de la base, hay base de prueba, está instalada Subcontratación? *Supuesto: 17 Enterprise, es_419, sin base de prueba.*
3. Exporta de Odoo product.product (referencia, nombre, UdM, valores de atributo, activo) y una LdM "compatible con importación". ¿Las telas están por color como productos, como variantes o genéricas? *Supuesto: producto por color con referencia propia.*
4. ¿El `cu` es la referencia interna de la prenda en Odoo? ¿De la plantilla o de una variante? ¿Ya existe cada prenda antes de la receta, y quién la crea? *Supuesto: referencia de la plantilla, la crea quien administra productos en Odoo, antes del paso 5.*
5. ¿La prenda en Odoo es una por REF o una por REF+color? *Supuesto: una por REF.*
6. ¿UdM real de cada familia (kg/m/u/cono)? *Supuesto: punto en kg, plana/elástico/cordón en m, resto u.*
7. ¿La cantidad va con desperdicio dentro o neta? *Supuesto: con desperdicio.*
8. ¿Consumo promedio de la curva o talla base? *Supuesto: promedio (lo que ya costea la ficha).*
9. ¿Servicios y decoración entran (como qué) o quedan fuera? *Supuesto: fuera.*
10. ¿Operaciones en la LdM? Si sí, nombres exactos de los centros de trabajo. *Supuesto: no en el piloto.*
11. ¿Al cambiar una receta: actualizar la misma LdM o crear v2 y archivar la anterior? *Supuesto: actualizar (17/18).*
12. ¿Quién importa en Odoo y qué rol tiene en la app? *Supuesto: planificación.*
13. Si hay fotos/PDF escaneados: ¿aceptan un servicio externo de lectura? *Supuesto: no; se transcribe.*
14. ¿IN-INS001 (etiqueta de lavado) e IN-SATIN son el mismo producto en Odoo? *Supuesto: sí.*
15. ¿Alguien usa hoy TEMPO_BOM.csv o se puede reemplazar? *Supuesto: se mantiene como reporte.*
