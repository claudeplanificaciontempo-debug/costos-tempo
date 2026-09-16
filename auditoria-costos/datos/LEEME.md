# /datos — Qué contiene cada archivo

Exportación del estado del sistema en la rama `pre-auditoria-costos` (commit `54a62eb`).

**Formato de todos los CSV:** UTF-8 con BOM, separador `;`, encabezado en la primera fila.
Se abren directo en Excel y se cargan con los `\copy` de `../ESQUEMA.sql`, PARTE 3.

---

## ⚠️ Advertencia sobre el origen de los datos

Estos CSV salen de **la semilla embebida en `index.html`** (líneas 741-1147), **no de la
base de producción**.

Los datos reales viven en Supabase, y la política de red de este entorno **bloquea la
salida** hacia `oepsutldxratrvozpulq.supabase.co` (6 de 6 intentos rechazados por política
de la organización). No pude leerlos.

Lo exportado sí es un dato real del sistema —es lo que ve un usuario nuevo y lo que
`fusionarSemilla()` (`index.html:2057`) reinyecta en cada despliegue— pero **no es la
producción**. Para traer los datos reales hay tres caminos, en
`../INSTALACION_LOCAL.md` §2 paso 4.

---

## Archivos con datos reales (11)

| Archivo | Filas | Qué contiene |
|---|---|---|
| **`productos.csv`** | 38 | Referencias: código, nombre, categoría, tipo, marca, departamento, año, temporada, archivado |
| **`materiales.csv`** | 140 | Catálogo completo: código, descripción, tipo (`mp`/`ins`/`dec`/`srv`), unidad, **costo unitario**, fecha del costo, familia, y una columna `origen` (de la auditoría) que separa lo importado de Odoo de lo del catálogo interno |
| **`centros_costo.csv`** | 5 | Centros con sus tarifas MOD y MOI y la base de cálculo (minutos o puntadas) |
| **`clientes.csv`** | 5 | Clientes, zona, meta de margen, cuál es el base y cuál va ligado a otro |
| **`categorias.csv`** | 58 | Árbol categoría → tipo de producto |
| **`pantones.csv`** | 60 | Paleta de colores importada de Odoo |
| **`recetas_por_defecto.csv`** | 109 | Consumos sugeridos por categoría y tipo de producto (`RECETAS` + `REC_BASE`). `(TODAS)` / `(todos)` marcan las que aplican a todo |
| **`fichas_lineas_materiales.csv`** | 216 | **Los consumos reales de cada ficha**: material, cantidad, % de desperdicio, precio unitario, costo de la línea, pantón |
| **`fichas_centros_tiempos.csv`** | 190 | **Los tiempos de cada ficha**: centro, si está activo, minutos o puntadas, y el MOD/MOI que genera |
| **`costo_unitario_calculado.csv`** | 38 | **El resultado**: costo por componente y total de cada referencia, replicando `calc()` (`index.html:1161-1173`) |
| **`materiales_sin_precio.csv`** | 69 | Diagnóstico: los materiales con costo 0 |

### Columnas que agregué yo (no existen en el sistema)

Van con nombre largo y descriptivo a propósito, para que no se confundan con datos del
sistema. Cada una existe porque la aplicación **no** reporta esa situación:

| Columna | Archivo | Por qué |
|---|---|---|
| `lineas_omitidas_por_material_inexistente` | `costo_unitario_calculado.csv` | `calc()` las descarta en silencio (`../VALORES_FIJOS.md` B-2) |
| `fuente_de_los_consumos` | `costo_unitario_calculado.csv`, `fichas_lineas_materiales.csv` | Distingue una ficha capturada por una persona de una rellenada con la receta — la aplicación no lo distingue (`../VALORES_FIJOS.md` B-21) |
| `origen` | `materiales.csv` | Separa el catálogo interno de lo importado de Odoo |
| `costo_linea_usd` = `OMITIDA_EN_EL_CALCULO` | `fichas_lineas_materiales.csv` | Marca explícita, en vez de una celda vacía ambigua |

---

## Lo primero que se ve en estos datos

| Dato | Valor |
|---|---|
| Materiales con **costo 0** | **69 de 140 (49 %)** — incluidas **las 42 familias de tela** |
| Fichas con **0 centros activos** | **30 de 38** |
| Fichas con **costo total $0,00** | **30 de 38** |
| Fichas marcadas como **guardadas** | **0 de 38** |
| Costo de material + insumos + decoración + servicios, sumando las 38 referencias | **$0,00** |
| Mano de obra (MOD + MOI), sumando las 38 referencias | **$18,91** |

Es decir: **el 100 % del costo que produce hoy el sistema es mano de obra.** Ver
`../REGLAS_NEGOCIO.md` H-2.

Comprobaciones rápidas en la base, una vez cargados (ver `../ESQUEMA.sql`, PARTE 4):

```sql
SELECT round(sum(costo_total_usd),2) FROM costos.v_costo_unitario;  -- 18.91
SELECT count(*) FROM costos.qc_material_sin_precio;                 -- 69
SELECT count(*) FROM costos.qc_ficha_sin_tiempos;                   -- 30
```

---

## Plantillas vacías (6) — enero a julio 2026

**Estos seis archivos tienen encabezado y cero filas. Es deliberado.**

El pedido de auditoría solicita exportar, mes a mes de enero a julio 2026: kg de tela
tejida, kg de tela tinturada, unidades de prendas, consumos de hilo y químicos, costo
unitario y producto en proceso.

**El sistema no tiene ninguna dimensión de periodo.** No hay mes contable, ni fechas de
producción, ni cantidades por periodo, ni kg, ni tallas, ni inventario. Los siete meses no
existen en ningún formato: no están vacíos, **no están modelados**.
Ver `../MAPA.md` §0.

| Archivo | Qué contendría |
|---|---|
| `PLANTILLA_VACIA_kg_tela_tejida_mensual.csv` | Kg producidos por OP TEJ, consumo de hilo, merma, costo por kg |
| `PLANTILLA_VACIA_kg_tela_tinturada_mensual.csv` | Kg entrada/salida por OP de tintura, tela cruda consumida, servicio TIN aplicado |
| `PLANTILLA_VACIA_unidades_prendas_mensual.csv` | Unidades por referencia **y talla**, marcando cuáles son subproducto |
| `PLANTILLA_VACIA_consumos_hilo_quimicos_mensual.csv` | Consumo de hilo y químicos por OP |
| `PLANTILLA_VACIA_costo_unitario_mensual.csv` | Costo unitario por referencia y periodo, desglosado |
| `PLANTILLA_VACIA_producto_en_proceso_mensual.csv` | Saldos inicial y final de WIP por OP y centro |

### Por qué vacías y no de otra forma

- **Rellenarlas con ceros** habría afirmado que la producción de enero a julio fue cero.
  Es falso.
- **Estimarlas** a partir de algo habría sido inventar un dato — exactamente lo que la
  regla R-5 de la auditoría prohíbe (*«si falta un dato, se reporta como faltante; nunca se
  inventa ni se reemplaza en silencio»*).
- **No crearlas** habría dejado sin respuesta un punto explícito del pedido.

Un archivo con encabezado y cero filas dice exactamente lo que pasa: **la estructura está
propuesta, el dato no existe.**

Los nombres de columna son **una propuesta mía**, derivada del vocabulario del pedido.
Hay que validarlos con quien defina el modelo de OPs antes de usarlos. Su equivalente en
SQL está en `../ESQUEMA.sql`, PARTE 5, también comentado y sin crear.

---

## Cómo se generaron

Extraje las constantes de `index.html` (líneas 741-1147) y **repliqué `calc()` línea por
línea** en un script de Node ejecutado fuera del repositorio. **No se ejecutó la
aplicación, no se tocó la base, no se modificó ningún archivo del proyecto.**

La réplica respeta los detalles que importan del original (`index.html:1161-1173`):

- el `if(m)` que omite líneas cuyo material ya no está en el catálogo (`1164`);
- el `if(!s||!s.on||!s.val)return` que salta centros apagados o en cero (`1167`);
- que los centros medidos en puntadas **no** suman al SAM (`1169-1170`);
- que los servicios pueden llevar precio propio de línea (`1031`).

Ver `../SUPUESTOS.md` §2.3.
