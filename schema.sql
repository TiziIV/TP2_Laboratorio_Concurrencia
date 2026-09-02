-- ============================================================
-- schema.sql — Caso "Food Store"
-- ============================================================

-- ---------- TIPOS ----------
-- Enum para forma de pago, porque es un dominio cerrado (no cualquier texto)
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'BILLETERA_DIGITAL');

-- ---------- TABLA: Cliente ----------
CREATE TABLE Cliente (
    id_cliente  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(120) NOT NULL,      -- participación total, todo cliente tiene nombre
    correo      VARCHAR(150) NOT NULL,      -- participación total, se usa como clave candidata
    telefono    VARCHAR(20),                -- participación parcial, no todos cargan teléfono
    CONSTRAINT uq_cliente_correo UNIQUE (correo)
);

-- ---------- TABLA: Categoria ----------
CREATE TABLE Categoria (
    id_categoria     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_categoria VARCHAR(80) NOT NULL,   -- participación total
    descripcion      VARCHAR(300)            -- participación parcial, es opcional
);

-- ---------- TABLA: Producto ----------
CREATE TABLE Producto (
    id_producto     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_producto VARCHAR(120) NOT NULL,
    precio_actual   NUMERIC(10,2) NOT NULL,
    stock           INTEGER NOT NULL DEFAULT 0,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,  -- baja lógica, arranca en TRUE
    id_categoria    BIGINT NOT NULL,                -- todo producto tiene que tener categoría
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria) REFERENCES Categoria (id_categoria)
        ON DELETE RESTRICT,
        -- RESTRICT: no dejo borrar una categoría si todavía tiene productos
        -- colgando de ella, primero hay que reasignarlos o borrarlos aparte.
    CONSTRAINT chk_producto_precio_no_negativo CHECK (precio_actual >= 0),
    CONSTRAINT chk_producto_stock_no_negativo CHECK (stock >= 0)
);

-- ---------- TABLA: Pedido ----------
CREATE TABLE Pedido (
    id_pedido   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_hora  TIMESTAMPTZ NOT NULL DEFAULT now(),  -- se completa sola al insertar
    forma_pago  forma_pago_enum NOT NULL,
    id_cliente  BIGINT NOT NULL,                     -- todo pedido pertenece a un cliente
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente) REFERENCES Cliente (id_cliente)
        ON DELETE RESTRICT
        -- RESTRICT: el pedido es como un comprobante de venta, no se puede
        -- perder ese historial solo porque se borre el cliente. Si se quiere
        -- dar de baja al cliente, mejor con un campo de estado que borrándolo.
);

-- ---------- TABLA: Detalle_Pedido (entidad asociativa N:M) ----------
CREATE TABLE Detalle_Pedido (
    id_pedido       BIGINT NOT NULL,   -- obligatorio, forma parte de la PK compuesta
    id_producto     BIGINT NOT NULL,   -- obligatorio, forma parte de la PK compuesta
    cantidad        INTEGER NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT fk_detalle_pedido_pedido
        FOREIGN KEY (id_pedido) REFERENCES Pedido (id_pedido)
        ON DELETE CASCADE,
        -- CASCADE: un detalle no tiene sentido solo, si se borra el pedido
        -- (por ejemplo una anulación total) sus detalles se van con él.
    CONSTRAINT fk_detalle_pedido_producto
        FOREIGN KEY (id_producto) REFERENCES Producto (id_producto)
        ON DELETE RESTRICT,
        -- RESTRICT: si un producto ya se vendió en algún pedido no se puede
        -- borrar, se perdería el historial de esa venta. Para "eliminarlo"
        -- en realidad se usa el campo activo = FALSE (baja lógica).
    CONSTRAINT chk_detalle_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio_no_negativo CHECK (precio_unitario >= 0)
);

-- ---------- INDICES ----------

-- Ayuda cuando se busca el historial de pedidos de un cliente en particular,
-- algo que se va a consultar seguido (ej. sección "mis pedidos").
CREATE INDEX idx_pedido_id_cliente ON Pedido (id_cliente);

-- Ayuda a los reportes de ventas por producto (ej. "cuánto se vendió de tal
-- producto"), evita recorrer toda la tabla Detalle_Pedido cada vez.
CREATE INDEX idx_detalle_pedido_id_producto ON Detalle_Pedido (id_producto);