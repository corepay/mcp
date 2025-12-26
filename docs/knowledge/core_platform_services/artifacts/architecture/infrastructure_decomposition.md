# Multi-Tenant Infrastructure Decomposition

To adhere to "Zero Defects" quality standards (complexity ≤ 9, nesting ≤ 2) and improve maintainability, the foundational multi-tenant logic was decomposed from the monolithic `Mcp.MultiTenant` into specialized services.

## 1. The Legacy Monolith
Previously, `Mcp.MultiTenant` served as a "God Object" responsible for database schema lifecycle, migration management, and global process context. This created tight coupling between the storage layer and the request lifecycle.

## 2. The Decomposed Architecture

### 2.1. `Mcp.Infrastructure.TenantManager`
Responsible for the **Database/Schema Lifecycle** of organization nodes.
- **Operations**: `create_tenant_schema/1`, `drop_tenant_schema/1`, `run_tenant_migrations/1`.
- **Logic**: Handles the `acq_` prefixing used in Postgres and coordinates with `Ecto.Migrator`.
- **Environment Safety**: respects `config :mcp, :run_tenant_migrations` to prevent destructive operations in the test environment.

### 2.2. `Mcp.Infrastructure.Context`
Responsible for **Request Identity and Context propagation**.
- **Operations**: `put_tenant/1`, `get_tenant/0`, `clear_tenant/0`.
- **Mechanism**: Combines `Registry` (for cross-process registration) and `Process` dictionary (for high-performance local resolution).

### 2.3. Direct Repo Usage
Legacy query delegates in the multi-tenant module were removed. Codebase patterns now favor using `Mcp.Repo` directly with an explicit `prefix` or relying on Ash Framework's native multitenancy for resource operations.

## 3. Zero Defects Achievement
This decomposition ensures that infrastructure operations are atomic, testable in isolation, and maintain low cyclomatic complexity. Infrastructure-specific tests are located at `test/mcp/infrastructure/tenant_manager_test.exs`.
