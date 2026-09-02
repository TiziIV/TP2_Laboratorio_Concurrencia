# Ejercicio de Lectura Crítica de Código SQL Generado por IA (Parte 3)

Este documento analiza dos propuestas de scripts DDL generadas por modelos de Inteligencia Artificial para el proyecto FoodStore, identificando riesgos operativos, impacto en producción y proponiendo las versiones corregidas y seguras.

---

## Caso 1: Modificación Destructiva de Tipos de Datos

### Código propuesto por la IA:
```sql
ALTER TABLE Producto ALTER COLUMN precio_actual TYPE INTEGER;
```

### 1. Análisis de Riesgos y Errores
* **Pérdida irreversible de precisión decimal (Truncamiento):** La columna `precio_actual` en el esquema original es de tipo `NUMERIC(10,2)` para registrar centavos comerciales[cite: 1, 2]. Al forzarla a `INTEGER`, PostgreSQL descartará o redondeará los centavos, destruyendo datos monetarios históricos y vigentes[cite: 1, 2].
* **Falla sintáctica inmediata:** Si la tabla ya cuenta con registros, PostgreSQL arrojará un error (`ERROR: column "precio_actual" cannot be cast automatically to type integer`) exigiendo una cláusula `USING` explícita para resolver la conversión.
* **Incompatibilidad de esquema con Detalle_Pedido:** La tabla `Detalle_Pedido` almacena el `precio_unitario` histórico como `NUMERIC(10,2)`[cite: 1, 2]. Generar un catálogo con precios enteros produce inconsistencias de cálculo entre el producto y los subtotales de pedidos[cite: 1, 2].

### 2. Impacto en Producción y Bloqueos
* Ejecutar un cambio de tipo en caliente adquiere un bloqueo exclusivo de tipo `ACCESS EXCLUSIVE` sobre la tabla `Producto`.
* Esto detiene cualquier consulta concurrente de lectura (`SELECT`) y de escritura (`INSERT`, `UPDATE`), congelando la operación de venta de FoodStore durante la reescritura física de la tabla.

### 3. Solución Técnica Corregida
En un entorno de comercio electrónico, los precios no deben convertirse a enteros. Si se requiere ajustar la precisión numérica o aplicar un cast explícito controlado sin pérdida, se debe usar la siguiente sintaxis segura:

```sql
BEGIN;

-- Mantener NUMERIC pero asegurando escala y redondeo explícito si fuera estrictamente necesario
ALTER TABLE Producto 
    ALTER COLUMN precio_actual TYPE NUMERIC(10,2) 
    USING ROUND(precio_actual::numeric, 2);

ROLLBACK; -- Probar en seco según protocolo
```

---

## Caso 2: Eliminación e Inserción Descontrolada de Restricciones

### Código propuesto por la IA:
```sql
ALTER TABLE Detalle_Pedido DROP CONSTRAINT IF EXISTS chk_detalle_cantidad_positiva;
ALTER TABLE Detalle_Pedido ADD CONSTRAINT chk_detalle_cantidad_positiva CHECK (cantidad >= 0);
```

### 1. Análisis de Riesgos y Errores
* **Violación de la regla de negocio fundamental (R5/Cantidad vendida):** La regla de FoodStore establece que la cantidad vendida debe ser estrictamente mayor a cero (`cantidad > 0`)[cite: 1, 2]. Permitir `cantidad >= 0` habilita insertar líneas de pedido con cantidad 0, lo que genera registros basura, distorsión en métricas de venta y anomalías en reportes de facturación[cite: 1, 2].
* **Ventana de inconsistencia:** Al hacer un `DROP CONSTRAINT` seguido de un `ADD CONSTRAINT` sin transacción atómica, cualquier inserción concurrente que ocurra en esa fracción de segundo entra sin validación alguna.
* **Validación completa de tabla con bloqueo:** `ADD CONSTRAINT CHECK (...)` sin optimizaciones valida inmediatamente cada fila existente en `Detalle_Pedido` manteniendo un bloqueo exclusivo que degrada la base.

### 2. Solución Técnica Corregida (Patrón Seguro en PostgreSQL)
Para corregir la restricción manteniendo la regla de negocio estricta (`cantidad > 0`) y minimizando bloqueos en producción, se utiliza `NOT VALID` seguido de `VALIDATE CONSTRAINT`[cite: 1]:

```sql
BEGIN;

-- 1. Eliminar la restricción errónea
ALTER TABLE Detalle_Pedido 
    DROP CONSTRAINT IF EXISTS chk_detalle_cantidad_positiva;

-- 2. Agregar la restricción correcta sin bloquear lecturas históricas pesadas
ALTER TABLE Detalle_Pedido 
    ADD CONSTRAINT chk_detalle_cantidad_positiva 
    CHECK (cantidad > 0) NOT VALID;

-- 3. Validar los datos existentes en background con un bloqueo ligero (SHARE UPDATE EXCLUSIVE)
ALTER TABLE Detalle_Pedido 
    VALIDATE CONSTRAINT chk_detalle_cantidad_positiva;

COMMIT;
```

---

## Conclusiones de la Revisión Crítica
1. **Nunca aceptar ciegamente sugerencias de IA:** Las IAs tienden a relajar restricciones para "evitar errores de inserción" (como permitir `cantidad >= 0`), violando la semántica y el modelo relacional[cite: 1, 2].
2. **Priorizar la disponibilidad:** Todo script DDL en entornos concurrentes debe contemplar los niveles de bloqueo en PostgreSQL (`ACCESS EXCLUSIVE` vs `SHARE UPDATE EXCLUSIVE`).
3. **Validación en seco obligatoria:** La aplicación del protocolo de seguridad (`BEGIN ... ROLLBACK`) es la única garantía contra migraciones destructivas.