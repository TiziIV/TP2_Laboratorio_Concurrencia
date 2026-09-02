-- =============================================================================
-- PARTE 1: RESTRICCIONES DE INTEGRIDAD Y DISPARADORES
-- Proyecto: FoodStore
-- =============================================================================

-- R1: El stock de un producto no puede ser negativo
ALTER TABLE Producto
    ADD CONSTRAINT chk_producto_stock_no_negativo
        CHECK (stock >= 0);

-- R2: El precio actual de un producto debe ser estrictamente positivo
ALTER TABLE Producto
    ADD CONSTRAINT chk_producto_precio_positivo
        CHECK (precio_actual > 0);

-- R3: El estado de un pedido solo puede ser 'PENDIENTE', 'PAGADO', 'EN_PREPARACION', 'ENVIADO' o 'ENTREGADO'
ALTER TABLE Pedido
    ADD CONSTRAINT chk_pedido_estado_valido
        CHECK (estado IN ('PENDIENTE', 'PAGADO', 'EN_PREPARACION', 'ENVIADO', 'ENTREGADO'));

-- R4: El precio unitario histórico en Detalle_Pedido debe ser estrictamente positivo
ALTER TABLE Detalle_Pedido
    ADD CONSTRAINT chk_detalle_precio_positivo
        CHECK (precio_unitario > 0);

-- R5: La cantidad vendida en un detalle de pedido debe ser estrictamente mayor a 0
ALTER TABLE Detalle_Pedido
    ADD CONSTRAINT chk_detalle_cantidad_positiva
        CHECK (cantidad > 0);

-- -----------------------------------------------------------------------------
-- R6: Validación de consistencia temporal en Pedido
-- Regla: fecha_entrega no puede ser anterior a fecha_pedido.
-- -----------------------------------------------------------------------------
ALTER TABLE Pedido
    ADD CONSTRAINT chk_pedido_fechas_coherentes
        CHECK (fecha_entrega IS NULL OR fecha_entrega >= fecha_pedido);

-- -----------------------------------------------------------------------------
-- R7: Garantía de stock suficiente ante inserción en Detalle_Pedido
-- Implementación: Disparador (Trigger) a nivel de fila antes de INSERT.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_stock_pedido()
RETURNS TRIGGER AS $$
DECLARE
v_stock_disponible INT;
BEGIN
SELECT stock INTO v_stock_disponible
FROM Producto
WHERE id_producto = NEW.id_producto;

IF v_stock_disponible < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto ID %: Disponible %, Solicitado %',
            NEW.id_producto, v_stock_disponible, NEW.cantidad;
END IF;

    -- Descontar el stock de forma atómica en la misma operación
UPDATE Producto
SET stock = stock - NEW.cantidad
WHERE id_producto = NEW.id_producto;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_stock_pedido ON Detalle_Pedido;

CREATE TRIGGER trg_validar_stock_pedido
    BEFORE INSERT ON Detalle_Pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_stock_pedido();