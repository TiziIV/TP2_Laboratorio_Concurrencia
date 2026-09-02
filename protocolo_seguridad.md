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
