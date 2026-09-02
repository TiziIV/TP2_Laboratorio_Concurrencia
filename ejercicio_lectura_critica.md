# Ejercicio de Lectura Crítica de Código SQL Generado por IA (Parte 3)

Este documento analiza dos scripts SQL generados por modelos de Inteligencia Artificial para tareas de mantenimiento sobre el esquema genérico de cátedra, identificando el impacto real de su ejecución, los errores conceptuales y sus versiones corregidas.

---

## Script 1: Baja de funciones de películas retiradas de cartel

### Código propuesto por la IA:
```sql
UPDATE funcion
SET activa = FALSE;
```

### 1. Filas que afectaría realmente
Afecta a **todas y cada una de las filas de la tabla `funcion`** sin excepción, independientemente de la película asociada o del estado en cartelera.

### 2. Por qué no coincide con la consigna
La consigna solicita dar de baja únicamente las funciones correspondientes a películas que fueron *retiradas de cartel*. Al omitir por completo la cláusula `WHERE`, el comando produce un impacto destructivo total en el sistema: desactiva funciones futuras de películas en estreno, funciones vendidas y funciones activas de películas que siguen en cartel.

### 3. Versión técnica corregida
Se asocia la tabla `funcion` con `pelicula` mediante una subconsulta o condición `WHERE` que filtre por el estado de la película:

```sql
BEGIN;

UPDATE funcion
SET activa = FALSE
WHERE id_pelicula IN (
    SELECT id_pelicula 
    FROM pelicula 
    WHERE en_cartel = FALSE
);

ROLLBACK; -- Validación en seco según protocolo
```

---

## Script 2: Limpieza de categorías sin productos asociados

### Código propuesto por la IA:
```sql
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### 1. Filas que afectaría realmente
En un entorno real con datos imperfectos, este script **no borra ninguna fila** (0 registros afectados). Si la tabla `producto` contiene al menos un solo registro con `categoria_id IS NULL`, toda la condición devuelve `UNKNOWN` (falso lógico en filtros) para cada fila de `categoria`.

### 2. Por qué no coincide con la consigna
En la lógica trivaluada de SQL (`TRUE`, `FALSE`, `UNKNOWN`), evaluar `v NOT IN (val1, val2, NULL)` se traduce internamente como:
`v <> val1 AND v <> val2 AND v <> NULL`.

Cualquier comparación de desigualdad contra `NULL` resulta en `UNKNOWN`, y la conjunción lógica `AND` con un término `UNKNOWN` nunca puede ser `TRUE`. En consecuencia:
* Si hay un producto sin categoría asignada (`NULL`), no se borra ninguna categoría huérfana.
* Si no hubiera `NULL`, la consulta realiza un *Full Table Scan* ineficiente de la tabla `producto` por cada fila de `categoria`.

### 3. Versión técnica corregida
Existen dos alternativas estándar seguras que no caen en la trampa del `NULL`. La solución recomendada por rendimiento y semántica en PostgreSQL es usar `NOT EXISTS`:

```sql
BEGIN;

-- Opción 1: Con NOT EXISTS (Recomendada y segura ante NULLs)
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 
    FROM producto p 
    WHERE p.categoria_id = c.id
);

-- Opción 2: Con NOT IN filtrando explícitamente los nulos
-- DELETE FROM categoria 
-- WHERE id NOT IN (SELECT categoria_id FROM producto WHERE categoria_id IS NOT NULL);

ROLLBACK; -- Validación en seco según protocolo
```

---

## Declaración de Uso de IA (DUIA - Parte 3)

| Campo | Detalle |
| :--- | :--- |
| **Herramienta** | OpenCode / Asistente IA (LLM) |
| **Spec o prompt utilizado** | *"Analizar el comportamiento destructivo de `UPDATE funcion SET activa = FALSE;` y la falla con NULL en `DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);` proponiendo la versión segura con NOT EXISTS."* |
| **Qué generó** | Explicación teórica del UPDATE sin WHERE y de la lógica trivaluada en NOT IN con NULL, junto a los scripts corregidos. |
| **Qué se aceptó** | La justificación matemática de la lógica trivaluada de SQL y la sintaxis con `NOT EXISTS`. |
| **Qué se modificó o descartó** | Se descartó el uso de subconsultas pesadas sin índices y se estructuró bajo el protocolo de transacción en seco (`BEGIN ... ROLLBACK`). |
| **Verificación realizada** | Prueba sobre tabla simulada con valores `NULL` comprobando que `NOT IN` devuelve 0 filas borradas mientras que `NOT EXISTS` elimina únicamente las categorías sin productos. |