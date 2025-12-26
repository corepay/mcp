# Multi-tenant Backup and Restoration

Automated systems for organizational disaster recovery and data portabilty.

## 1. Strategy
Backup operations utilize PostgreSQL `pg_dump` within a tenant-specific context.

### A. Contextual Execution
All backup functions utilize `Mcp.Infrastructure.Context.with_tenant_context` (or `TenantManager` helpers) to ensure only the target organization's schema is targeted.

### B. Verification
Captures metadata (size, table count, timestamp) to facilitate integrity checks and point-in-time recovery.

## 2. Simulation Pattern (Test Mode)
To support testing without a live DB shell, `BackupService` implements a simulation pattern:
- Detects `:test` environment.
- Writes dummy artifacts.
- Returns valid metadata to test the rest of the pipeline (notifications, storage).

## 3. Zero Defects Implementation
Uses the **Service Dispatch Decomposition** pattern:
- **Orchestrators**: handle context and lifecycle.
- **Discrete Helpers**: perform the actual shell commands or simulations, keeping cyclomatic complexity low (≤ 9).
