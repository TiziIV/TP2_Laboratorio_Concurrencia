# Protocolo de Seguridad Operativa sobre Base de Datos (Parte 0)

Este protocolo define las directivas y comandos obligatorios que se ejecutan antes, durante y después de aplicar cualquier script DDL o DML sobre la base de datos del proyecto FoodStore.

---

## 1. Copia de Trabajo (Entorno Aislado)

Nunca se interactúa ni se prueban modificaciones sobre la base productiva. Todo cambio propuesto se ejecuta sobre una base duplicada para pruebas.

### Comandos de ejecución:
```bash
# Cerrar conexiones activas si la base origen está en uso
psql -U postgres -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'foodstore_db' AND pid <> pg_backend_pid();"

# Crear la base de trabajo a partir del template
createdb -U postgres -T foodstore_db foodstore_dev_concurrencia
```

---

## 2. Transacción de Prueba (Validación en Seco)

Todo script generado por IA o escrito manualmente se corre en primera instancia dentro de un bloque transaccional explícito que se aborta con ROLLBACK.

### Secuencia de inspección:
```sql
BEGIN;

ALTER TABLE Detalle_Pedido 
ADD CONSTRAINT chk_precio_unitario_positivo CHECK (precio_unitario > 0);

SELECT conname, contype, conrelid::regclass 
FROM pg_constraint 
WHERE conrelid = 'Detalle_Pedido'::regclass;

ROLLBACK;
```

---

## 3. Respaldo Estructural y Lógico (Snapshot previo a DDL)

Antes de ejecutar sentencias estructurales permanentes (ALTER TABLE, DROP, migraciones de tipos o índices pesados), se genera un dump lógico de la base de trabajo.

### Comandos de ejecución:
```bash
mkdir -p ./backups

pg_dump -U postgres -d foodstore_dev_concurrencia --format=plain --file="./backups/foodstore_pre_ddl_$(date +%Y%m%d_%H%M%S).sql"
```

---

## Verificación de Cumplimiento
* [x] Base de pruebas creada y verificada con \l en psql.
* [x] Todo script DDL/DML testeado con BEGIN ... ROLLBACK antes de persistir.
* [x] Directorio ./backups configurado con volcado previo a los cambios de la Unidad 1.