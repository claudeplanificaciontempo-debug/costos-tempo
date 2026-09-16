# Auditoría del sistema de costos — Costos TEMPO

Auditoría previa a la migración a una base de datos local.
**No se modificó código ni datos.** Todo lo que hay aquí es documentación y exportación.

- **Estado auditado:** rama `pre-auditoria-costos` → commit `54a62eb`
  (existe además el tag anotado `pre-auditoria-costos` en local; **no se pudo publicar**
  porque las credenciales de esta sesión no tienen permiso para empujar tags — la rama
  cumple la misma función y sí está publicada)
  (rama `claude/lucid-maxwell-xix1ec`)
- **Alcance:** `index.html` — 2.784 líneas, un único archivo con todo el sistema
- **Fecha:** 16-sep-2026
- Todas las referencias `index.html:NNN` apuntan a ese estado exacto

---

## Lo primero que hay que saber

**El sistema que describe el pedido no es el que hay en este repositorio.**

El pedido habla de costeo por orden de producción: OPs TEJ y TIN, kg de tela tejida y
tinturada, consumo de hilo y químicos, subproductos por talla, producto en proceso, series
mensuales de enero a julio 2026.

Este repositorio contiene una aplicación de **ficha de costo unitario por prenda** (costo
estándar prospectivo por referencia). No hay OPs, ni kg, ni tallas, ni WIP, ni ninguna
dimensión de periodo. No están incompletos: **no existen**.

Audité lo que hay, con el mismo rigor, y señalo con precisión qué de lo pedido no existe en
vez de forzar equivalencias. El detalle está en `MAPA.md` §0 y el razonamiento en
`SUPUESTOS.md` §1.

---

## Los tres hallazgos principales

| # | Hallazgo | Dónde |
|---|---|---|
| **H-1** | **Los costos no quedan congelados al guardar**, aunque tres textos de la pantalla afirman que sí. Cambiar el precio de un material o una tarifa modifica retroactivamente el costo y el precio de todas las fichas ya cerradas, incluidas las exportadas a clientes | `REGLAS_NEGOCIO.md` H-1 |
| **H-2** | **El 100 % del costo actual es mano de obra.** Los 38 productos suman $0,00 de material, insumos, decoración y servicios, y $18,91 de MOD+MOI. 69 de 140 materiales tienen precio 0, incluidas las 42 familias de tela. Nada lo advierte | `REGLAS_NEGOCIO.md` H-2 |
| **H-3** | **22 puntos donde un dato faltante se reemplaza en silencio** por un cero, un valor por defecto o la omisión del registro. Es la única de las cinco reglas de negocio plenamente aplicable al sistema, y se incumple de forma sistemática | `VALORES_FIJOS.md` §B |

---

## Archivos generados

| Archivo | Qué responde |
|---|---|
| **`MAPA.md`** | De dónde viene cada dato y cómo se carga. El flujo de cálculo paso a paso. Las 20 fórmulas del sistema en lenguaje simple, con archivo y línea. Qué falta para cada uno de los cinco tipos de costeo del pedido |
| **`VALORES_FIJOS.md`** | Toda constante, porcentaje, factor y mapeo escrito en el código (§A). Los 22 lugares donde falta un dato y se sustituye en silencio (§B). Las 13 clasificaciones hechas por texto o prefijo (§C) |
| **`ESQUEMA.sql`** | Tablas, campos, tipos y relaciones, listo para ejecutar en PostgreSQL. Réplica de la nube actual + modelo normalizado + vistas que reproducen `calc()` en SQL + 8 vistas de control de calidad |
| **`datos/`** | 11 CSV con los datos de entrada y los resultados calculados, y 6 plantillas vacías para las series mensuales que el sistema no tiene. Ver `datos/LEEME.md` |
| **`PERSISTENCIA.md`** | Qué se guarda y qué se recalcula cada vez. Los 10 riesgos de perder cambios al recargar o recalcular. Recomendación sobre el botón de «guardar cambios» |
| **`INSTALACION_LOCAL.md`** | Qué se necesita, instalación paso a paso, tres formas de traer los datos reales, y la lista de comprobación antes de dar la migración por buena |
| **`REGLAS_NEGOCIO.md`** | El dictamen de las cinco reglas del pedido, con evidencia y número de línea. No se corrigió ninguna |
| **`SUPUESTOS.md`** | Todo lo que tuve que suponer o interpretar porque no estaba definido, y qué no cubre esta auditoría |

---

## Dictamen de las cinco reglas de negocio

| # | Regla | Veredicto |
|---|---|---|
| R-1 | La tela de Tempo se valora solo con hilo + químicos; MOD y CIF no entran | **No verificable** — no existe costeo de tela; es un precio de compra tecleado, hoy en 0 |
| R-2 | Químicos y MOD de tintorería en la OP TIN; la segunda OP consume servicio + tela cruda, sin doble conteo | **No cumple** — no hay OPs; el doble conteo es posible y no se detecta |
| R-3 | Las tallas que salen como subproductos reciben costo | **No cumple** — no existe la dimensión talla |
| R-4 | Las OPs TEJ mal clasificadas deben poder detectarse | **No cumple** — no hay OPs; y la convención de prefijos que sí existe no se valida nunca |
| R-5 | Si falta un dato se reporta; nunca se inventa ni se reemplaza en silencio | **No cumple** — 22 casos documentados |

Detalle y evidencia en `REGLAS_NEGOCIO.md`.

---

## Por dónde empezar a leer

- **Si vas a migrar la base:** `INSTALACION_LOCAL.md` → `ESQUEMA.sql` → `datos/LEEME.md`
- **Si vas a decidir qué arreglar primero:** `REGLAS_NEGOCIO.md` → `VALORES_FIJOS.md` §D
- **Si querés entender cómo calcula:** `MAPA.md` §3 y §4
- **Si te preocupa perder datos:** `PERSISTENCIA.md` §4 y §5
- **Si algo no te cuadra:** `SUPUESTOS.md` — probablemente esté ahí

---

## Qué no cubre esta auditoría

- **Las políticas RLS de Supabase.** `SB_KEY` (`index.html:1757`) es una clave *publishable*
  pensada para estar visible en el navegador, así que **toda la seguridad real vive en las
  políticas RLS**, que están en la nube y no en este repositorio. No las pude ver. Los
  roles que sí revisé son controles de interfaz: esconden botones. **Es lo primero que
  habría que revisar, y no pude.**
- **Los datos de producción.** La política de red del entorno bloquea la salida hacia
  Supabase. Lo exportado en `datos/` es la semilla del repositorio.
- **Si los valores de negocio son los correctos.** Reporté que la tarifa de corte es
  `0.2252` y la meta de Fashion Club `30 %`, pero no tengo la nómina ni el tarifario para
  juzgarlo. Audité el *cómo*, no el *cuánto*.
- **El comportamiento en ejecución.** Leí las 2.784 líneas y repliqué el cálculo aparte;
  no abrí la aplicación en un navegador.

Detalle en `SUPUESTOS.md` §5.
