-- =====================================================================
-- ESQUEMA.sql — Costos TEMPO
-- Estructura completa que usa el sistema, lista para crear en una base local.
--
-- Auditoría del estado congelado en el tag `pre-auditoria-costos`
-- (commit 2e4ef99, sobre 54a62eb). Referencias `index.html:NNN`.
--
-- Motor objetivo: PostgreSQL 14 o superior (es el mismo motor que usa
-- Supabase hoy, así que la migración no cambia de tecnología).
--
-- El archivo tiene cuatro partes:
--   PARTE 1 · Réplica exacta de las tablas que existen hoy en la nube.
--             Sirve para volcar los datos actuales tal cual, sin perder nada.
--   PARTE 2 · Esquema normalizado y tipado, que es a donde conviene ir.
--   PARTE 3 · Carga de los CSV de /auditoria-costos/datos al esquema de la PARTE 2.
--   PARTE 4 · Vistas de cálculo que reproducen calc() y plCalc() en SQL,
--             y consultas de control de calidad del dato.
--
-- IMPORTANTE — lo que este esquema NO tiene, porque el sistema no lo tiene:
--   · órdenes de producción (OP), ni TEJ ni TIN
--   · kilos de tela, tejeduría, tintorería, hilo o químicos
--   · tallas ni subproductos
--   · producto en proceso (WIP) ni inventario
--   · ninguna dimensión de periodo (mes/año contable)
-- Ver MAPA.md §0 y SUPUESTOS.md. En la PARTE 5 dejo, comentado y sin crear,
-- el esqueleto mínimo que haría falta si se decide construir todo eso.
-- =====================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS costos;
SET search_path TO costos, public;


-- =====================================================================
-- PARTE 1 · Réplica exacta de las tablas que existen hoy en Supabase
-- ---------------------------------------------------------------------
-- Las 8 tablas `cst_*` tienen todas la misma forma: una clave de texto y
-- un JSON con absolutamente todo lo demás adentro. No hay columnas
-- tipadas, ni claves foráneas, ni restricciones. Se arman en
-- `filas()` — index.html:1869-1881.
--
-- La columna `actualizado` se lee en index.html:2105 (`sbGetConFecha`)
-- para decidir si un respaldo pisaría una edición más reciente, así que
-- existe en la base aunque el código nunca la escriba explícitamente.
-- =====================================================================

CREATE TABLE cst_productos (               -- index.html:1872
    id           text PRIMARY KEY,         -- = REFS[].r (la referencia)
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cst_productos IS
  'data: {r, n, marca, dep, anio, temporada, cat, sub, orden, foto, arch}';

CREATE TABLE cst_materiales (              -- index.html:1873
    id           text PRIMARY KEY,         -- = CAT[].c (código de material)
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cst_materiales IS
  'data: {c, d, k, um, p, f, fam, orden}. k ∈ (mp, ins, dec, srv). p = precio unitario.';

CREATE TABLE cst_centros (                 -- index.html:1874
    id           text PRIMARY KEY,         -- = CEN[].id
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cst_centros IS
  'data: {id, n, base, tD, tI, desde, orden}. base ∈ (min, punt).';

CREATE TABLE cst_clientes (                -- index.html:1875
    id           text PRIMARY KEY,         -- = CLI[].id
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cst_clientes IS
  'data: {id, cli, zona, meta, base, vinc, mas, modo, orden}.';

CREATE TABLE cst_fichas (                  -- index.html:1876
    id           text PRIMARY KEY,         -- = la referencia del producto
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cst_fichas IS
  'La ficha entera en un JSON: {lines:[{c,q,d,pan,p}], cen:{<id>:{on,val}}, '
  'pl:[{...cliente, lock, pct, up, pvp}], ver, saved, fecha, edit, hist:[], aprob}.';

CREATE TABLE cst_marcas (                  -- index.html:1877
    id           text PRIMARY KEY,         -- slug del nombre  ← ver VALORES_FIJOS C-10
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cst_pantones (                -- index.html:1878
    id           text PRIMARY KEY,         -- slug del código
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cst_temporadas (              -- index.html:1879
    id           text PRIMARY KEY,         -- slug del nombre
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cst_versiones (               -- index.html:1986-1993
    id           text PRIMARY KEY,         -- '<ref>-v<n>'
    data         jsonb NOT NULL,
    actualizado  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cst_versiones IS
  'Histórico. data: {ref, ver, fecha, total, sam, pvp:[{cli,pvp}], lines, cen}. '
  'OJO: guarda el total calculado y los consumos, pero NO los precios unitarios '
  'ni las tarifas con que se calculó. Ver REGLAS_NEGOCIO.md H-1.';

CREATE TABLE perfiles (                    -- index.html:1826, 2465, 2475
    id      uuid PRIMARY KEY,              -- = auth.users.id de Supabase
    email   text,
    nombre  text,
    rol     text NOT NULL DEFAULT 'consulta'
              CHECK (rol IN ('admin','planificacion','prearmado','consulta')),
    creado  timestamptz NOT NULL DEFAULT now()
);

-- Las fotos no son una tabla: viven en el bucket de Storage `cst-fotos`
-- (index.html:1930). En cst_productos.data->>'foto' queda la URL pública,
-- o bien un data: URI en base64 si todavía no se subió.


-- =====================================================================
-- PARTE 2 · Esquema normalizado y tipado (destino recomendado)
-- ---------------------------------------------------------------------
-- Mismos datos, con tipos reales, claves foráneas y las restricciones que
-- hoy no existen en ningún lado. Cada columna indica de dónde sale.
-- =====================================================================

-- ---------- Catálogos base ----------

CREATE TABLE categoria (
    categoria    text PRIMARY KEY                    -- CATEG, index.html:745
);

CREATE TABLE tipo_producto (
    categoria       text NOT NULL REFERENCES categoria(categoria)
                      ON UPDATE CASCADE ON DELETE RESTRICT,
    tipo_producto   text NOT NULL,                   -- el "sub" del código
    PRIMARY KEY (categoria, tipo_producto)
);

CREATE TABLE departamento (
    departamento text PRIMARY KEY                    -- DEPS, index.html:742 (lista cerrada)
);

CREATE TABLE marca (
    marca text PRIMARY KEY                           -- MARCAS, index.html:743
);

CREATE TABLE temporada (
    temporada text PRIMARY KEY                       -- TEMPORADAS, index.html:744
);

CREATE TABLE pantone (
    codigo  text PRIMARY KEY,                        -- PANTONES[].pan, index.html:966
    nombre  text NOT NULL DEFAULT ''
);

-- ---------- Materiales ----------

CREATE TABLE tipo_material (
    tipo    text PRIMARY KEY,                        -- KN, index.html:1032
    nombre  text NOT NULL,
    orden   int  NOT NULL                            -- orden de presentación, index.html:1199
);
INSERT INTO tipo_material (tipo, nombre, orden) VALUES
    ('mp' ,'Materia prima',0),
    ('ins','Insumos'      ,1),
    ('dec','Decoración'   ,2),
    ('srv','Servicios'    ,3);

CREATE TABLE familia_material (
    familia text PRIMARY KEY                         -- CAT[].fam (familia Odoo)
);

CREATE TABLE material (
    codigo            text PRIMARY KEY,              -- CAT[].c
    descripcion       text NOT NULL,                 -- CAT[].d
    tipo              text NOT NULL REFERENCES tipo_material(tipo),   -- CAT[].k
    unidad_medida     text NOT NULL,                 -- CAT[].um
    costo_unitario    numeric(14,6) NOT NULL DEFAULT 0,               -- CAT[].p
    fecha_costo_texto text,                          -- CAT[].f tal como lo guarda hoy ('8-sep-2026')
    fecha_costo       date,                          -- la misma fecha ya convertida; NULL si era 'provisional'
    familia           text REFERENCES familia_material(familia),      -- CAT[].fam
    origen            text NOT NULL DEFAULT 'catalogo_interno'
                        CHECK (origen IN ('catalogo_interno','odoo_cate.xlsx_MP-IN','carga_masiva','manual')),
    activo            boolean NOT NULL DEFAULT true,
    CONSTRAINT material_costo_no_negativo CHECK (costo_unitario >= 0)
);
-- El sistema actual NO exige costo > 0: hoy 69 de 140 materiales valen 0
-- (VALORES_FIJOS B-4). La restricción queda deliberadamente como >= 0 para
-- poder cargar los datos actuales; el control se hace con la vista
-- `qc_material_sin_precio` de la PARTE 4.
CREATE INDEX material_tipo_idx    ON material(tipo);
CREATE INDEX material_familia_idx ON material(familia);

-- ---------- Centros de costo ----------

CREATE TABLE centro_costo (
    centro_id       text PRIMARY KEY,                -- CEN[].id
    nombre          text NOT NULL,                   -- CEN[].n
    base_calculo    text NOT NULL CHECK (base_calculo IN ('min','punt')),   -- CEN[].base
    tarifa_mod      numeric(12,6) NOT NULL DEFAULT 0 CHECK (tarifa_mod >= 0), -- CEN[].tD
    tarifa_moi      numeric(12,6) NOT NULL DEFAULT 0 CHECK (tarifa_moi >= 0), -- CEN[].tI
    vigente_desde_texto text,                        -- CEN[].desde ('01-ago-2026')
    vigente_desde   date,
    orden           int NOT NULL DEFAULT 0
);
COMMENT ON COLUMN centro_costo.tarifa_moi IS
  'Único vehículo de CIF del sistema: los indirectos se absorben por minuto. index.html:1170';

-- Historial de tarifas. HOY NO EXISTE: el sistema pisa la tarifa vigente
-- (setTar, index.html:2554) y solo conserva la fecha del último cambio.
-- Sin esta tabla no se puede recalcular un costo histórico. Ver REGLAS_NEGOCIO H-1.
CREATE TABLE centro_costo_tarifa_hist (
    centro_id    text NOT NULL REFERENCES centro_costo(centro_id) ON DELETE CASCADE,
    vigente_desde date NOT NULL,
    tarifa_mod   numeric(12,6) NOT NULL,
    tarifa_moi   numeric(12,6) NOT NULL,
    PRIMARY KEY (centro_id, vigente_desde)
);

-- Igual para el precio de los materiales: hoy solo se guarda el precio
-- vigente y la fecha en que se tocó (setPrecio, index.html:1237).
CREATE TABLE material_precio_hist (
    codigo        text NOT NULL REFERENCES material(codigo) ON DELETE CASCADE,
    vigente_desde date NOT NULL,
    costo_unitario numeric(14,6) NOT NULL,
    PRIMARY KEY (codigo, vigente_desde)
);

-- ---------- Clientes ----------

CREATE TABLE cliente (
    cliente_id   text PRIMARY KEY,                   -- CLI[].id
    nombre       text NOT NULL,                      -- CLI[].cli
    zona         text NOT NULL,                      -- CLI[].zona
    meta_margen_pct numeric(6,3) CHECK (meta_margen_pct >= 0 AND meta_margen_pct < 100),  -- CLI[].meta
    es_base      boolean NOT NULL DEFAULT false,     -- CLI[].base
    modo         text NOT NULL DEFAULT 'margen_propio'
                   CHECK (modo IN ('margen_propio','sobrebase','puntos_sobre_base')),     -- CLI[].modo
    vinculado_a  text REFERENCES cliente(cliente_id),-- CLI[].vinc
    mas_pct      numeric(6,3),                       -- CLI[].mas
    orden        int NOT NULL DEFAULT 0,
    -- Hoy el cliente base se elige por POSICIÓN (CLI[0], index.html:1355).
    -- Aquí se fuerza a que haya exactamente uno marcado, que es lo que el
    -- código pretende pero no garantiza. Ver VALORES_FIJOS A.3.
    CONSTRAINT cliente_vinculo_coherente CHECK (
        (modo = 'margen_propio' AND vinculado_a IS NULL)
     OR (modo <> 'margen_propio' AND vinculado_a IS NOT NULL AND mas_pct IS NOT NULL)
    )
);
CREATE UNIQUE INDEX cliente_unico_base ON cliente(es_base) WHERE es_base;

-- ---------- Productos ----------

CREATE TABLE producto (
    referencia    text PRIMARY KEY,                  -- REFS[].r
    nombre        text NOT NULL,                     -- REFS[].n
    categoria     text NOT NULL,                     -- REFS[].cat
    tipo_producto text NOT NULL,                     -- REFS[].sub
    marca         text REFERENCES marca(marca),      -- REFS[].marca
    departamento  text REFERENCES departamento(departamento),          -- REFS[].dep
    anio          text,                              -- REFS[].anio  ← hoy es TEXTO LIBRE, no un número
    temporada     text REFERENCES temporada(temporada),                -- REFS[].temporada
    archivado     boolean NOT NULL DEFAULT false,    -- REFS[].arch
    orden         int NOT NULL DEFAULT 0,
    foto_url      text,                              -- FOTO[ref] cuando ya está en Storage
    FOREIGN KEY (categoria, tipo_producto)
        REFERENCES tipo_producto(categoria, tipo_producto) ON UPDATE CASCADE
);
COMMENT ON COLUMN producto.anio IS
  'Se deja como text porque el input es de texto libre (index.html:1619) y hay '
  'valores no numéricos posibles. Convertir a int solo después de limpiar.';

-- ---------- Recetas (consumos sugeridos por tipo de producto) ----------

CREATE TABLE receta_default (
    categoria       text NOT NULL,                   -- '(TODAS)' para REC_BASE
    tipo_producto   text NOT NULL,                   -- '(todos)' para la receta `def` de la categoría
    codigo_material text NOT NULL REFERENCES material(codigo),
    consumo         numeric(14,6) NOT NULL CHECK (consumo >= 0),
    desperdicio_pct numeric(6,3)  NOT NULL DEFAULT 0 CHECK (desperdicio_pct >= 0),
    PRIMARY KEY (categoria, tipo_producto, codigo_material)
);
COMMENT ON TABLE receta_default IS
  'RECETAS + REC_BASE, index.html:1036-1081. Se aplican al crear un producto '
  '(index.html:1699), en carga masiva (2311) y al cambiar la categoría (1092).';

-- ---------- Ficha de costo ----------

CREATE TABLE ficha (
    referencia   text PRIMARY KEY REFERENCES producto(referencia) ON DELETE CASCADE,
    version      int  NOT NULL DEFAULT 1 CHECK (version >= 1),        -- FICHAS[].ver
    guardada     boolean NOT NULL DEFAULT false,                      -- FICHAS[].saved
    en_recosteo  boolean NOT NULL DEFAULT false,                      -- FICHAS[].edit
    aprobacion   text CHECK (aprobacion IN ('pendiente')),            -- FICHAS[].aprob
    fecha_texto  text,                                                -- FICHAS[].fecha ('8-sep-2026')
    fecha        date,
    -- Trazabilidad que hoy no existe: de dónde salieron los consumos.
    fuente_consumos text NOT NULL DEFAULT 'manual'
        CHECK (fuente_consumos IN ('manual','ficha_precargada_PRE','receta_por_defecto_RECETAS','recuperada_historial'))
);
COMMENT ON COLUMN ficha.fuente_consumos IS
  'La aplicación NO distingue una ficha capturada por una persona de una '
  'rellenada automáticamente con la receta (fusionarSemilla, index.html:2065). '
  'Ver VALORES_FIJOS B-21.';

CREATE TABLE ficha_linea (
    referencia      text NOT NULL REFERENCES ficha(referencia) ON DELETE CASCADE,
    linea           int  NOT NULL,                   -- posición en FICHAS[].lines
    codigo_material text NOT NULL REFERENCES material(codigo) ON DELETE RESTRICT,
    consumo         numeric(14,6) NOT NULL DEFAULT 0 CHECK (consumo >= 0),   -- lines[].q
    desperdicio_pct numeric(6,3)  NOT NULL DEFAULT 0 CHECK (desperdicio_pct >= 0), -- lines[].d
    precio_servicio numeric(14,6),                   -- lines[].p, SOLO para tipo 'srv' (index.html:1031)
    pantone         text REFERENCES pantone(codigo), -- lines[].pan
    PRIMARY KEY (referencia, linea)
);
-- ON DELETE RESTRICT es deliberado: hoy borrar un material desde la nube deja
-- líneas huérfanas que calc() omite en silencio (VALORES_FIJOS B-2).

CREATE TABLE ficha_centro (
    referencia  text NOT NULL REFERENCES ficha(referencia) ON DELETE CASCADE,
    centro_id   text NOT NULL REFERENCES centro_costo(centro_id) ON DELETE RESTRICT,
    activo      boolean NOT NULL DEFAULT false,      -- cen[].on
    valor       numeric(14,4) NOT NULL DEFAULT 0 CHECK (valor >= 0),  -- cen[].val: minutos o puntadas
    PRIMARY KEY (referencia, centro_id)
);
COMMENT ON COLUMN ficha_centro.valor IS
  'Minutos si centro_costo.base_calculo = min; puntadas si = punt. index.html:1169-1170';

CREATE TABLE ficha_precio (
    referencia  text NOT NULL REFERENCES ficha(referencia) ON DELETE CASCADE,
    cliente_id  text NOT NULL REFERENCES cliente(cliente_id) ON DELETE CASCADE,
    fijado_por  text NOT NULL CHECK (fijado_por IN ('pct','pvp','up')),  -- pl[].lock
    margen_pct  numeric(6,3),                        -- pl[].pct
    recargo_pct numeric(6,3),                        -- pl[].up
    pvp         numeric(14,4),                       -- pl[].pvp
    PRIMARY KEY (referencia, cliente_id)
);

-- ---------- Historial de versiones ----------

CREATE TABLE ficha_version (
    referencia   text NOT NULL REFERENCES producto(referencia) ON DELETE CASCADE,
    version      int  NOT NULL,
    fecha_texto  text,
    fecha        date,
    costo_total  numeric(14,4) NOT NULL,             -- data.total
    sam_minutos  numeric(12,4) NOT NULL,             -- data.sam
    PRIMARY KEY (referencia, version)
);

CREATE TABLE ficha_version_linea (
    referencia      text NOT NULL,
    version         int  NOT NULL,
    linea           int  NOT NULL,
    codigo_material text NOT NULL,
    consumo         numeric(14,6) NOT NULL,
    desperdicio_pct numeric(6,3)  NOT NULL DEFAULT 0,
    pantone         text,
    -- ESTAS DOS COLUMNAS SON NUEVAS Y SON EL PUNTO DE LA AUDITORÍA:
    -- hoy la versión NO guarda con qué precio se calculó, así que un costo
    -- histórico no se puede reconstruir ni auditar. Ver REGLAS_NEGOCIO H-1.
    precio_unitario_congelado numeric(14,6),
    costo_linea_congelado     numeric(14,6),
    PRIMARY KEY (referencia, version, linea),
    FOREIGN KEY (referencia, version) REFERENCES ficha_version(referencia, version) ON DELETE CASCADE
);

CREATE TABLE ficha_version_centro (
    referencia  text NOT NULL,
    version     int  NOT NULL,
    centro_id   text NOT NULL,
    activo      boolean NOT NULL,
    valor       numeric(14,4) NOT NULL,
    -- Igual que arriba: hoy no se guarda la tarifa con la que se cerró.
    tarifa_mod_congelada numeric(12,6),
    tarifa_moi_congelada numeric(12,6),
    PRIMARY KEY (referencia, version, centro_id),
    FOREIGN KEY (referencia, version) REFERENCES ficha_version(referencia, version) ON DELETE CASCADE
);

CREATE TABLE ficha_version_precio (
    referencia  text NOT NULL,
    version     int  NOT NULL,
    cliente_id  text NOT NULL REFERENCES cliente(cliente_id),
    pvp         numeric(14,4) NOT NULL,
    PRIMARY KEY (referencia, version, cliente_id),
    FOREIGN KEY (referencia, version) REFERENCES ficha_version(referencia, version) ON DELETE CASCADE
);

-- ---------- Usuarios ----------

CREATE TABLE usuario (
    usuario_id uuid PRIMARY KEY,
    email      text UNIQUE,
    nombre     text,
    rol        text NOT NULL DEFAULT 'consulta'
                 CHECK (rol IN ('admin','planificacion','prearmado','consulta')),
    creado     timestamptz NOT NULL DEFAULT now()
);

-- ---------- Bitácora: hoy no existe en absoluto ----------
-- No hay ningún registro de quién cambió qué. `actualizado` solo dice cuándo
-- se tocó la fila por última vez. Para una base local auditable hace falta esto:
CREATE TABLE bitacora (
    bitacora_id bigserial PRIMARY KEY,
    momento     timestamptz NOT NULL DEFAULT now(),
    usuario_id  uuid REFERENCES usuario(usuario_id),
    tabla       text NOT NULL,
    clave       text NOT NULL,
    accion      text NOT NULL CHECK (accion IN ('insert','update','delete')),
    antes       jsonb,
    despues     jsonb
);
CREATE INDEX bitacora_tabla_clave_idx ON bitacora(tabla, clave, momento DESC);


-- =====================================================================
-- PARTE 3 · Carga de los CSV exportados en /auditoria-costos/datos
-- ---------------------------------------------------------------------
-- Todos los CSV son UTF-8 con BOM y separador ';'.
-- Ejecutar desde psql, desde la carpeta /auditoria-costos, con \i o \copy.
-- El orden importa por las claves foráneas.
-- =====================================================================

/*
-- 1. Catálogos base derivados de categorias.csv
CREATE TEMP TABLE _cat (categoria text, tipo_producto text);
\copy _cat FROM 'datos/categorias.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');
INSERT INTO categoria (categoria) SELECT DISTINCT categoria FROM _cat;
INSERT INTO tipo_producto (categoria, tipo_producto) SELECT DISTINCT categoria, tipo_producto FROM _cat;

INSERT INTO departamento (departamento) VALUES ('Hombre'),('Mujer'),('Niño');

-- 2. Pantones
\copy pantone (codigo, nombre) FROM 'datos/pantones.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

-- 3. Materiales (primero las familias, que salen del propio archivo)
CREATE TEMP TABLE _mat (
    codigo text, descripcion text, tipo text, unidad_medida text,
    costo_unitario numeric, fecha_costo text, familia text, origen text);
\copy _mat FROM 'datos/materiales.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

INSERT INTO familia_material (familia)
SELECT DISTINCT familia FROM _mat WHERE familia IS NOT NULL AND familia <> '';

INSERT INTO material (codigo, descripcion, tipo, unidad_medida, costo_unitario,
                      fecha_costo_texto, fecha_costo, familia, origen)
SELECT codigo, descripcion, tipo, unidad_medida, costo_unitario,
       fecha_costo,
       costos.fecha_es(fecha_costo),                  -- ver función más abajo
       NULLIF(familia,''), origen
FROM _mat;

-- 4. Centros de costo
CREATE TEMP TABLE _cen (centro_id text, nombre text, base_calculo text,
    tarifa_mod numeric, tarifa_moi numeric, tarifa_total numeric, vigente_desde text);
\copy _cen FROM 'datos/centros_costo.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');
INSERT INTO centro_costo (centro_id, nombre, base_calculo, tarifa_mod, tarifa_moi,
                          vigente_desde_texto, vigente_desde, orden)
SELECT centro_id, nombre, base_calculo, tarifa_mod, tarifa_moi,
       vigente_desde, costos.fecha_es(vigente_desde), row_number() OVER ()
FROM _cen;
-- Sembrar el historial con la tarifa vigente:
INSERT INTO centro_costo_tarifa_hist (centro_id, vigente_desde, tarifa_mod, tarifa_moi)
SELECT centro_id, COALESCE(vigente_desde, DATE '1900-01-01'), tarifa_mod, tarifa_moi
FROM centro_costo;

-- 5. Clientes (dos pasadas: primero sin vínculo, después el vínculo)
CREATE TEMP TABLE _cli (cliente_id text, nombre text, zona text, meta numeric,
    es_base text, vinculado_a text, mas_pct text, modo text);
\copy _cli FROM 'datos/clientes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');
INSERT INTO cliente (cliente_id, nombre, zona, meta_margen_pct, es_base, modo, mas_pct, orden)
SELECT cliente_id, nombre, zona,
       CASE WHEN modo = 'sobrebase' THEN NULL ELSE meta END,
       es_base = 'si',
       CASE modo WHEN 'margen_propio' THEN 'margen_propio' ELSE modo END,
       NULLIF(mas_pct,'')::numeric, row_number() OVER ()
FROM _cli;
UPDATE cliente c SET vinculado_a = t.vinculado_a
FROM _cli t WHERE t.cliente_id = c.cliente_id AND NULLIF(t.vinculado_a,'') IS NOT NULL;

-- 6. Marcas y temporadas (salen de productos.csv)
CREATE TEMP TABLE _prod (referencia text, nombre text, categoria text, tipo_producto text,
    marca text, departamento text, anio text, temporada text, archivado text);
\copy _prod FROM 'datos/productos.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');
INSERT INTO marca (marca)         SELECT DISTINCT marca     FROM _prod WHERE NULLIF(marca,'')     IS NOT NULL;
INSERT INTO temporada (temporada) SELECT DISTINCT temporada FROM _prod WHERE NULLIF(temporada,'') IS NOT NULL;
INSERT INTO producto (referencia, nombre, categoria, tipo_producto, marca,
                      departamento, anio, temporada, archivado, orden)
SELECT referencia, nombre, categoria, tipo_producto, NULLIF(marca,''),
       NULLIF(departamento,''), NULLIF(anio,''), NULLIF(temporada,''),
       archivado = 'si', row_number() OVER ()
FROM _prod;

-- 7. Recetas
\copy receta_default (categoria, tipo_producto, codigo_material, consumo, desperdicio_pct) FROM 'datos/recetas_por_defecto.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');

-- 8. Fichas
CREATE TEMP TABLE _cst (referencia text, producto text, categoria text, tipo_producto text,
    mp numeric, ins numeric, dec_ numeric, srv numeric, mod_ numeric, moi numeric,
    total numeric, sam numeric, centros_activos int, omitidas int,
    guardada text, version int, fecha text, fuente text);
\copy _cst FROM 'datos/costo_unitario_calculado.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');
INSERT INTO ficha (referencia, version, guardada, fecha_texto, fecha, fuente_consumos)
SELECT referencia, version, guardada = 'si', NULLIF(fecha,''),
       costos.fecha_es(NULLIF(fecha,'')), fuente
FROM _cst;

CREATE TEMP TABLE _lin (referencia text, producto text, codigo_material text,
    descripcion text, tipo text, unidad text, consumo numeric, desperdicio numeric,
    precio numeric, costo_linea text, pantone text, fuente text);
\copy _lin FROM 'datos/fichas_lineas_materiales.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');
INSERT INTO ficha_linea (referencia, linea, codigo_material, consumo, desperdicio_pct, pantone)
SELECT referencia,
       row_number() OVER (PARTITION BY referencia ORDER BY codigo_material),
       codigo_material, consumo, desperdicio, NULLIF(pantone,'')
FROM _lin;

CREATE TEMP TABLE _fc (referencia text, centro_id text, centro text, activo text,
    valor numeric, base text, tmod numeric, tmoi numeric, cmod numeric, cmoi numeric);
\copy _fc FROM 'datos/fichas_centros_tiempos.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');
INSERT INTO ficha_centro (referencia, centro_id, activo, valor)
SELECT referencia, centro_id, activo = 'si', valor FROM _fc;
*/

-- Conversión de las fechas en español que usa el sistema ('8-sep-2026').
-- Devuelve NULL para 'provisional' y para cualquier texto no reconocido,
-- en vez de inventar una fecha.
CREATE OR REPLACE FUNCTION costos.fecha_es(txt text) RETURNS date
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
      WHEN txt IS NULL OR btrim(txt) = '' OR lower(btrim(txt)) = 'provisional' THEN NULL
      WHEN btrim(txt) ~ '^\d{1,2}-[a-zA-Z]{3}-\d{4}$' THEN
        make_date(
          split_part(btrim(txt),'-',3)::int,
          CASE lower(split_part(btrim(txt),'-',2))
            WHEN 'ene' THEN 1 WHEN 'feb' THEN 2  WHEN 'mar' THEN 3  WHEN 'abr' THEN 4
            WHEN 'may' THEN 5 WHEN 'jun' THEN 6  WHEN 'jul' THEN 7  WHEN 'ago' THEN 8
            WHEN 'sep' THEN 9 WHEN 'oct' THEN 10 WHEN 'nov' THEN 11 WHEN 'dic' THEN 12
          END,
          split_part(btrim(txt),'-',1)::int)
      ELSE NULL
    END;
$$;


-- =====================================================================
-- PARTE 4 · Vistas de cálculo y de control de calidad
-- ---------------------------------------------------------------------
-- Reproducen en SQL exactamente lo que hace calc() (index.html:1161-1173)
-- y plCalc() (index.html:1358-1368), para poder contrastar el resultado
-- de la aplicación contra la base.
-- =====================================================================

-- Costo de cada línea de material — equivale a index.html:1164
CREATE OR REPLACE VIEW v_costo_linea AS
SELECT
    fl.referencia,
    fl.linea,
    fl.codigo_material,
    m.tipo,
    fl.consumo,
    fl.desperdicio_pct,
    fl.consumo * (1 + fl.desperdicio_pct / 100.0)                   AS consumo_real,
    -- Los servicios pueden llevar precio propio en la línea (index.html:1031)
    COALESCE(CASE WHEN m.tipo = 'srv' THEN fl.precio_servicio END, m.costo_unitario)
                                                                     AS precio_unitario,
    fl.consumo * (1 + fl.desperdicio_pct / 100.0)
      * COALESCE(CASE WHEN m.tipo = 'srv' THEN fl.precio_servicio END, m.costo_unitario)
                                                                     AS costo_linea
FROM ficha_linea fl
JOIN material m ON m.codigo = fl.codigo_material;

-- Mano de obra por centro — equivale a index.html:1165-1171
CREATE OR REPLACE VIEW v_costo_centro AS
SELECT
    fc.referencia,
    fc.centro_id,
    cc.base_calculo,
    fc.valor,
    CASE WHEN cc.base_calculo = 'punt' THEN fc.valor / 1000.0 ELSE fc.valor END
      * cc.tarifa_mod                                                AS costo_mod,
    CASE WHEN cc.base_calculo = 'punt' THEN fc.valor / 1000.0 ELSE fc.valor END
      * cc.tarifa_moi                                                AS costo_moi,
    -- Los centros medidos en puntadas NO suman al SAM (index.html:1170)
    CASE WHEN cc.base_calculo = 'min' THEN fc.valor ELSE 0 END       AS minutos_sam
FROM ficha_centro fc
JOIN centro_costo cc ON cc.centro_id = fc.centro_id
WHERE fc.activo AND fc.valor <> 0;                -- misma guarda que index.html:1167

-- Costo unitario total — equivale a index.html:1172
CREATE OR REPLACE VIEW v_costo_unitario AS
SELECT
    p.referencia,
    p.nombre,
    p.categoria,
    p.tipo_producto,
    COALESCE(ml.mp ,0) AS mp_usd,
    COALESCE(ml.ins,0) AS insumos_usd,
    COALESCE(ml.dec,0) AS decoracion_usd,
    COALESCE(ml.srv,0) AS servicios_usd,
    COALESCE(ce.mod,0) AS mod_usd,
    COALESCE(ce.moi,0) AS moi_usd,
    COALESCE(ml.mp,0)+COALESCE(ml.ins,0)+COALESCE(ml.dec,0)+COALESCE(ml.srv,0)
      +COALESCE(ce.mod,0)+COALESCE(ce.moi,0)                         AS costo_total_usd,
    COALESCE(ce.sam,0) AS minutos_sam,
    COALESCE(ce.n  ,0) AS centros_activos
FROM producto p
LEFT JOIN (
    SELECT referencia,
           SUM(costo_linea) FILTER (WHERE tipo='mp' ) AS mp,
           SUM(costo_linea) FILTER (WHERE tipo='ins') AS ins,
           SUM(costo_linea) FILTER (WHERE tipo='dec') AS dec,
           SUM(costo_linea) FILTER (WHERE tipo='srv') AS srv
    FROM v_costo_linea GROUP BY referencia
) ml ON ml.referencia = p.referencia
LEFT JOIN (
    SELECT referencia, SUM(costo_mod) AS mod, SUM(costo_moi) AS moi,
           SUM(minutos_sam) AS sam, COUNT(*) AS n
    FROM v_costo_centro GROUP BY referencia
) ce ON ce.referencia = p.referencia;

-- Precio de venta por cliente — equivale a basePvp()/plCalc(), index.html:1354-1368
CREATE OR REPLACE VIEW v_precio_venta AS
WITH base AS (
    SELECT cu.referencia, cu.costo_total_usd,
           cu.costo_total_usd / (1 - b.meta_margen_pct/100.0) AS pvp_base
    FROM v_costo_unitario cu
    CROSS JOIN (SELECT meta_margen_pct FROM cliente WHERE es_base LIMIT 1) b
    WHERE b.meta_margen_pct < 100
)
SELECT
    b.referencia,
    c.cliente_id,
    c.nombre AS cliente,
    c.zona,
    b.costo_total_usd,
    CASE
      WHEN c.modo = 'sobrebase' THEN b.pvp_base * (1 + c.mas_pct/100.0)
      WHEN c.meta_margen_pct >= 100 THEN 0            -- index.html:1365: se fuerza a 0
      ELSE b.costo_total_usd / (1 - c.meta_margen_pct/100.0)
    END AS pvp,
    CASE
      WHEN c.modo = 'sobrebase' THEN b.pvp_base * (1 + c.mas_pct/100.0)
      WHEN c.meta_margen_pct >= 100 THEN 0
      ELSE b.costo_total_usd / (1 - c.meta_margen_pct/100.0)
    END - b.costo_total_usd AS ganancia_usd
FROM base b CROSS JOIN cliente c;

-- ---------- Control de calidad del dato ----------
-- Estas vistas existen porque la aplicación NO reporta ninguna de estas
-- situaciones: las resuelve en silencio. Ver VALORES_FIJOS §B.

CREATE OR REPLACE VIEW qc_material_sin_precio AS
SELECT codigo, descripcion, tipo, unidad_medida, familia, fecha_costo_texto
FROM material WHERE costo_unitario = 0 ORDER BY tipo, codigo;

CREATE OR REPLACE VIEW qc_ficha_sin_materiales AS
SELECT p.referencia, p.nombre
FROM producto p LEFT JOIN ficha_linea fl ON fl.referencia = p.referencia
WHERE NOT p.archivado GROUP BY p.referencia, p.nombre HAVING COUNT(fl.linea) = 0;

CREATE OR REPLACE VIEW qc_ficha_sin_tiempos AS
SELECT p.referencia, p.nombre
FROM producto p LEFT JOIN v_costo_centro vc ON vc.referencia = p.referencia
WHERE NOT p.archivado GROUP BY p.referencia, p.nombre HAVING COUNT(vc.centro_id) = 0;

CREATE OR REPLACE VIEW qc_ficha_con_costo_material_cero AS
SELECT referencia, nombre, costo_total_usd, mod_usd + moi_usd AS mano_obra_usd
FROM v_costo_unitario
WHERE mp_usd + insumos_usd + decoracion_usd + servicios_usd = 0;

-- Prefijo del código contra el tipo declarado. Es el equivalente más cercano
-- a "detectar OPs mal clasificadas": una convención que nadie verifica.
-- Ver VALORES_FIJOS C-1 y REGLAS_NEGOCIO R-4.
CREATE OR REPLACE VIEW qc_material_prefijo_incoherente AS
SELECT codigo, descripcion, tipo AS tipo_declarado,
       CASE
         WHEN codigo LIKE 'MP-%' THEN 'mp'
         WHEN codigo LIKE 'IN-%' THEN 'ins'
         WHEN codigo LIKE 'SV-%' THEN 'srv'
         WHEN codigo LIKE 'SG-%' OR codigo LIKE 'DC-%' THEN 'dec'
       END AS tipo_segun_prefijo
FROM material
WHERE CASE
        WHEN codigo LIKE 'MP-%' THEN 'mp'
        WHEN codigo LIKE 'IN-%' THEN 'ins'
        WHEN codigo LIKE 'SV-%' THEN 'srv'
        WHEN codigo LIKE 'SG-%' OR codigo LIKE 'DC-%' THEN 'dec'
      END IS DISTINCT FROM tipo;

-- Doble conteo potencial de tintura: la ficha lleva a la vez una tela ya
-- tinturada y el servicio de tinturado. Ver REGLAS_NEGOCIO R-2.
CREATE OR REPLACE VIEW qc_posible_doble_conteo_tintura AS
WITH tintura AS (
    SELECT fl.referencia, fl.codigo_material, m.tipo, m.descripcion
    FROM ficha_linea fl
    JOIN material m ON m.codigo = fl.codigo_material
    WHERE (m.descripcion ILIKE '%tintur%' OR m.familia ILIKE '%TINTUR%')
      AND m.tipo IN ('mp','srv')
)
SELECT referencia,
       array_agg(codigo_material ORDER BY codigo_material)                       AS codigos,
       array_agg(descripcion     ORDER BY codigo_material)                       AS descripciones,
       count(*) FILTER (WHERE tipo = 'mp')  AS lineas_tela_tinturada,
       count(*) FILTER (WHERE tipo = 'srv') AS lineas_servicio_tintura
FROM tintura
GROUP BY referencia
HAVING count(*) FILTER (WHERE tipo = 'mp')  > 0
   AND count(*) FILTER (WHERE tipo = 'srv') > 0;

CREATE OR REPLACE VIEW qc_cliente_sin_base AS
SELECT 'No hay exactamente un cliente marcado como base' AS problema, COUNT(*) AS marcados
FROM cliente WHERE es_base HAVING COUNT(*) <> 1;

-- Versión cerrada cuyo costo actual ya no coincide con el que se guardó:
-- detecta el problema H-1 (los costos NO quedan congelados al guardar).
CREATE OR REPLACE VIEW qc_version_desfasada AS
SELECT fv.referencia, fv.version, fv.costo_total AS costo_guardado,
       cu.costo_total_usd AS costo_recalculado_hoy,
       cu.costo_total_usd - fv.costo_total AS diferencia
FROM ficha_version fv
JOIN v_costo_unitario cu ON cu.referencia = fv.referencia
WHERE round(fv.costo_total,4) <> round(cu.costo_total_usd,4);

COMMIT;


-- =====================================================================
-- PARTE 5 · Lo que NO existe hoy (esqueleto, deliberadamente comentado)
-- ---------------------------------------------------------------------
-- No lo creo porque no hay una sola línea de código ni un solo dato que lo
-- respalde: crearlo sería inventar un modelo que nadie definió. Lo dejo
-- escrito para que se vea con precisión la distancia entre lo que hay y lo
-- que la auditoría esperaba encontrar. Ver SUPUESTOS.md §3.
-- =====================================================================
/*
CREATE TABLE orden_produccion (
    op_id          text PRIMARY KEY,
    tipo_op        text NOT NULL CHECK (tipo_op IN ('TEJ','TIN','CONF','OTRO')),
    periodo        date NOT NULL,              -- mes contable
    producto_ref   text,
    kg_producidos  numeric(14,4),
    unidades       numeric(14,4),
    estado         text
);
CREATE TABLE op_consumo (
    op_id           text REFERENCES orden_produccion(op_id),
    codigo_material text REFERENCES material(codigo),
    cantidad        numeric(14,6),
    unidad          text,
    costo           numeric(14,6),
    PRIMARY KEY (op_id, codigo_material)
);
CREATE TABLE op_servicio (                     -- la OP TIN consumida por la OP siguiente
    op_consumidora text REFERENCES orden_produccion(op_id),
    op_servicio    text REFERENCES orden_produccion(op_id),
    costo          numeric(14,6),
    PRIMARY KEY (op_consumidora, op_servicio)
);
CREATE TABLE talla (talla text PRIMARY KEY, orden int);
CREATE TABLE op_salida_talla (                 -- subproductos por talla
    op_id     text REFERENCES orden_produccion(op_id),
    talla     text REFERENCES talla(talla),
    unidades  numeric(14,4),
    costo_asignado numeric(14,6),
    PRIMARY KEY (op_id, talla)
);
CREATE TABLE producto_en_proceso (
    periodo       date NOT NULL,
    op_id         text REFERENCES orden_produccion(op_id),
    saldo_inicial numeric(14,4),
    entradas      numeric(14,4),
    salidas       numeric(14,4),
    saldo_final   numeric(14,4),
    PRIMARY KEY (periodo, op_id)
);
*/
