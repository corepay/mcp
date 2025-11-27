# Core Foundation Enhancements

**Status:** Proposed **Date:** 2025-11-27 **Priority:** High

This document outlines 6 high-impact architectural enhancements to strengthen
the Core Foundation of the MCP platform before scaling to complex business
features. These recommendations are based on a code-first analysis of the
current implementation state.

---

## 1. 🔐 Security: Encrypt Sensitive Data (AshCloak)

**Status:** ✅ Complete

### Problem

Currently, sensitive fields in `Mcp.Accounts.User` (and potentially other
resources) are stored as plain text or simple maps. This includes:

- `totp_secret`
- `backup_codes`
- `oauth_tokens`

### Solution

Implement `AshCloak` to encrypt these fields at rest. This ensures that even if
the database is compromised, sensitive user secrets remain secure.

### Implementation Steps

1. **Add `AshCloak` to `Mcp.Accounts.User`**:
   ```elixir
   # lib/mcp/accounts/user.ex
   use Ash.Resource,
     extensions: [AshCloak, ...]

   cloak do
     vault Mcp.Vault
     attributes [:totp_secret, :backup_codes, :oauth_tokens]
     # Handle decryption on read
     decrypt_by_default [:totp_secret] 
   end
   ```
2. **Configure Vault**: Ensure `Mcp.Vault` is correctly configured in
   `config/config.exs` to use the environment-specific encryption keys.
3. **Migration**: Create a migration to convert existing columns to `binary` if
   they aren't already, or handle the data migration strategy.

---

## 2. 🏗️ Automation: Tenant Provisioning Reactor

**Status:** ✅ Complete

### Problem

The `Mcp.Platform.Tenant` resource's `create` action currently generates a
`company_schema` string (e.g., "acq_uuid") but **does not create the actual
PostgreSQL schema**. The logic exists in
`Mcp.MultiTenant.create_tenant_schema/1`, but it is disconnected from the
resource lifecycle. Creating a tenant today results in a broken state where the
tenant exists in `platform.tenants` but has no data isolation schema.

### Solution

Create an **Onboarding Reactor** (or an Ash Change) that orchestrates the full
tenant provisioning lifecycle.

### Implementation Steps

1. **Create `Mcp.Platform.Tenants.Changes.ProvisionTenant`**:
   - Call `Mcp.MultiTenant.create_tenant_schema/1`.
   - Run default tenant migrations (if using dynamic migrations).
   - Seed initial tenant data (e.g., default "Admin" role).
2. **Attach to Resource**:
   ```elixir
   # lib/mcp/platform/tenant.ex
   create :create do
     change Mcp.Platform.Tenants.Changes.ProvisionTenant
   end
   ```
3. **Error Handling**: Ensure that if schema creation fails, the Tenant record
   creation is rolled back (atomic transaction).

---

## 3. 📊 Observability: Ash Telemetry & Metrics

**Status:** ✅ Complete

### Problem

`McpWeb.Telemetry` is currently the default Phoenix boilerplate. It tracks
generic HTTP request times and Ecto query speeds but lacks visibility into **Ash
Actions**. We cannot currently answer questions like: "How long does
`Merchant.create` take?" or "What is the failure rate of `User.register`?".

### Solution

Integrate `Ash.Telemetry` to emit structured events for all Domain interactions.

### Implementation Steps

1. **Enable Telemetry in Domains**: Ensure all Domains (e.g., `Mcp.Accounts`,
   `Mcp.Platform`) have `trace_name` configured if needed (defaults are usually
   fine).
2. **Update `McpWeb.Telemetry`**: Add Ash-specific metrics to the `metrics/0`
   function:
   ```elixir
   summary("ash.action.duration",
     tags: [:resource, :action, :type],
     unit: {:native, :millisecond}
   ),
   counter("ash.action.exception.count", tags: [:resource, :action])
   ```
3. **Spans**: Configure `Ash.Telemetry` to emit spans for distributed tracing
   (if using Honeycomb/Jaeger).

---

## 4. 🧪 DX: Realistic Seeding Strategy

**Status:** ✅ Complete

### Problem

`priv/repo/seeds.exs` is effectively empty. Developers have to manually create
data to test features, leading to "works on my machine" issues and inconsistent
dev environments.

### Solution

Create a robust, idempotent seed script that generates a **complete multi-tenant
environment**.

### Implementation Steps

1. **Create `priv/repo/seeds/` directory**: Split seeds by domain.
2. **Implement `Mcp.Seeder` module**:
   - **Platform**: 1 Super Admin, 3 Plans (Starter, Pro, Enterprise).
   - **Tenants**: 2 Tenants ("Acme Corp", "Globex").
   - **Merchants**: 5 Merchants per Tenant.
   - **Transactions**: 50 mock transactions per Merchant (using `Faker`).
3. **Dev Workflow**: Update `mix setup` to run these seeds automatically.

---

## 5. � AI: Vector Embeddings Resource

**Status:** ✅ Complete

### Problem

The infrastructure (`pgvector` in Docker) is ready, and `Mcp.MultiTenant` has
helper functions (`create_vector_index`), but no Ash Resource is currently using
them. There is a disconnect between the infra capabilities and the application
layer.

### Solution

Create a foundational `Mcp.Ai.Document` resource to handle embeddings.

### Implementation Steps

1. **Create Resource**: `lib/mcp/ai/document.ex`.
2. **Attributes**:
   - `content`: Text content.
   - `embedding`: Vector(1536) (or 768 for Llama).
   - `ref_id` / `ref_type`: Polymorphic association to other entities (e.g.,
     Merchant, Transaction).
3. **AshAi Integration**: Use `AshAi` to automatically generate the `embedding`
   from `content` on create/update.
4. **Index**: Ensure the `ivfflat` or `hnsw` index is created via
   `Mcp.MultiTenant` helpers.

---

## 6. 🧹 Security & Cleanup: Remove Mocks & Migrate Vault

**Status**: ✅ Complete

### Problem

- HashiCorp Vault is over-engineered and underutilized.
- Mock implementations in `EmailService`, `SmsService`, `S3Client`, and `QorPay` create a false sense of security and hide integration issues.

### Solution

- Migrate to `supabase/vault` (Postgres extension) for secrets management.
- Remove `vault` service from Docker Compose.
- Replace mocks with real adapters (`ExAws`, `Swoosh`, `Req`) or functional local implementations.

### Implementation Steps

1.  [x] **Infrastructure**:
    -   Add `pgsodium` and `supabase/vault` to `docker/postgres/Dockerfile`.
    -   Remove `vault` service from `docker-compose.yml`.
    -   Update `initial_schema.sql` and migrations to create extensions.
2.  [x] **Vault Migration**:
    -   Rewrite `Mcp.Secrets.VaultClient` to use `vault.decrypted_secrets` view.
    -   Remove `Vaultex` dependency (cleanup later).
3.  [x] **Mock Removal**:
    -   **Email**: Switch to `Swoosh.Adapters.Local` (mailbox).
    -   **SMS**: Switch to Console Logger.
    -   **S3**: Switch to `ExAws` (MinIO).
    -   **Payments**: Implement real QorPay API calls (sandbox).
4.  [x] **Verification**:
    -   Verify extensions are installed (`pgsodium`, `supabase_vault`).
    -   Verify `VaultClient` can store and retrieve secrets.

---

## 7. 🧹 Maintenance: Standardize Soft Deletes (AshArchival)

**Status**: ✅ Complete

### Problem

Soft delete logic is inconsistent. `Mcp.Accounts.User` has a manual `soft_delete` action and `status` attribute. `Mcp.Platform.Tenant` has similar manual logic. This leads to query bugs where "deleted" items accidentally show up in lists.

### Solution

Adopt **AshArchival** globally for resources that require soft deletion.

### Implementation Steps

1.  [x] **Add Extension**:
    -   Added `AshArchival` to `Mcp.Accounts.User` and `Mcp.Platform.Tenant`.
2.  [x] **Remove Manual Logic**:
    -   Removed `soft_delete` actions.
    -   Removed `:deleted` from `status` constraints.
    -   Updated `active_users` to rely on AshArchival's default filtering.
3.  [x] **Update Indices**:
    -   Added `archived_at` column to `users` and `tenants` tables via migration `20251127100000_add_ash_archival.exs`.
    -   Backfilled `archived_at` for existing deleted records.
4.  [x] **Extend to Platform Domain**:
    -   Added `AshArchival` to `Mcp.Platform.Merchant`, `Mcp.Platform.Store`, and `Mcp.Platform.Customer`.
    -   Created missing tables `merchants`, `stores`, `customers` via migration `20251127110000_add_ash_archival_platform.exs`.
    -   Added `archived_at` column to all three tables.
5.  [x] **Global Expansion**:
    -   Added `AshArchival` to `Reseller`, `Developer`, `MID`, `Vendor`.
    -   Created missing tables `mids`, `vendors` via migration `20251127120000_add_ash_archival_global.exs`.
    -   Added `archived_at` column to all four tables.
6.  [x] **Finance & AI/Chat**:
    -   Added `AshArchival` to `Mcp.Finance.Account`, `Mcp.Ai.Document`, `Mcp.Chat.Conversation`, `Mcp.Chat.Message`.
    -   Added `archived_at` column via migration `20251127130000_add_ash_archival_finance_ai_chat.exs`.
7.  [x] **Global Tables**:
    -   Created `Mcp.Platform.Address`, `Mcp.Platform.Email`, `Mcp.Platform.Phone` resources (previously only tables).
    -   Added `AshArchival` to these new resources.
    -   Added `archived_at` column via migration `20251127140000_add_ash_archival_global_tables.exs`.

---

## 8. 🛠️ Tooling: Supabase Ecosystem Evaluation

**Status**: ✅ Complete

### Problem

The Supabase ecosystem offers many powerful tools (`supavisor`, `realtime`, `wrappers`, etc.), but it was unclear which ones would benefit the current Elixir/Ash architecture and which would be redundant.

### Solution

Evaluated key Supabase tools and adopted **Splinter** for database linting while rejecting others that overlap with Elixir's native strengths.

### Evaluation Results

| Tool | Verdict | Reasoning |
| :--- | :--- | :--- |
| **Splinter** (SQL Linter) | ✅ **Adopt** | Excellent "health check" for DB schema (missing indexes, RLS gaps). |
| **Supavisor** (Pooler) | ❌ Reject | Elixir's `DBConnection` / `Postgrex` handles pooling efficiently. |
| **Realtime** (WebSockets) | ❌ Reject | Phoenix Channels / `Ash.Notifier.PubSub` provide superior, native real-time. |
| **Wrappers** (FDW) | ❌ Reject | Ash Resources + API Clients provide better type safety and logic control than SQL FDWs. |
| **pg_net** (Async HTTP) | ❌ Reject | Oban + Req is a far more robust solution for async HTTP jobs. |
| **pg_jsonschema** | ❌ Reject | Ash Resources handle schema validation at the application layer. |
| **gen_rpc** | ❌ Reject | Standard Erlang Distribution is sufficient for current scale. |

### Implementation Steps

1.  [x] **Setup Splinter**:
    -   Downloaded `splinter.sql` to `priv/repo/splinter.sql`.
    -   Created `mix db.lint` task to run the linter against the local DB.
2.  [x] **Fix Linter Issues**:
    -   **Function Search Paths**: Fixed 10+ functions in `platform` schema (e.g., `trigger_tenant_settings_schema`) having mutable search paths via migration `20251127150000_fix_function_search_paths.exs`.
    -   **RLS Policies**: Added `Ash.Policy.Authorizer` to `Address`, `Email`, and `Phone` resources to satisfy RLS requirements.

    -   **RLS Policies**: Added `Ash.Policy.Authorizer` to `Address`, `Email`, and `Phone` resources to satisfy RLS requirements.

---

## 9. 🧩 Infrastructure: Clustering (Libcluster Postgres)

**Status**: ✅ Complete

### Problem

The platform needs to support distributed features (real-time notifications, distributed caching, background job coordination) across multiple nodes. However, deploying to PaaS environments like Render or Heroku often lacks stable IP addressing or native service discovery, making standard Erlang clustering difficult.

### Solution

Implement **Postgres-based Service Discovery** using `libcluster_postgres`. This allows nodes to discover each other by registering in a shared database table and communicating via Postgres `LISTEN/NOTIFY`.

### Implementation Steps

1.  [x] **Dependency**: Added `libcluster_postgres` to `mix.exs`.
2.  [x] **Configuration**:
    -   Configured `libcluster` topology in `config/config.exs` to use `LibclusterPostgres.Strategy`.
    -   Used environment variables (`POSTGRES_USER`, `POSTGRES_HOST`, etc.) to ensure 12-factor compliance.
3.  [x] **Supervision**: Added `Cluster.Supervisor` to `Mcp.Application` supervision tree.
4.  [x] **Documentation**: Created comprehensive guides in `docs/guides/cluster/`:
    -   `README.md` (Overview)
    -   `developer-guide.md` (Setup & Local Dev)
    -   `api-reference.md` (Configuration Options)
    -   `stakeholder-guide.md` (Business Value)
    -   `user-guide.md` (Operations)

---

## 10. 🧠 AI: Performance Tuning (Index Advisor)

**Status**: ✅ Complete

### Problem

Developers need a way to identify missing indexes for slow queries without guessing or running expensive production experiments.

### Solution

Install **Supabase Index Advisor**, which uses `hypopg` to simulate index creation and checks if the Postgres Query Planner would use them.

### Implementation Steps

1.  [x] **Infrastructure**:
    -   Updated `Dockerfile` to install `hypopg` and `index_advisor` extensions from source.
2.  [x] **Tooling**:
    -   Created `mix db.analyze "SQL QUERY"` task.
    -   This task runs the query through `index_advisor` and prints cost improvements and `CREATE INDEX` suggestions.
3.  [x] **Configuration**:
    -   Ensured `config/config.exs` respects `POSTGRES_PORT` env var to allow connecting to the Docker container correctly.

---

## 11. 🏗️ Architecture Refactoring: Core Foundation Hardening

**Status**: ✅ Completed

### Assessment Findings
A "Code Only" review identified that while the foundation is technologically strong (Ash, Timescale, Vector, Graph), the `Mcp.MultiTenant` module has become a "God Object" (470+ lines) that couples infrastructure with business logic.

### Goals
1.  **Decouple Infrastructure**: Split `Mcp.MultiTenant` into focused services (`TenantManager`, `Context`).
2.  **Ash-Native Logic**: Move raw SQL wrappers for Graph, Vector, and Analytics into Ash Resources and Actions.
3.  **Security Hardening**: Eliminate string interpolation in SQL queries to prevent injection risks.
4.  **Event-Driven Architecture**: Adopt `AshEvents` or `Reactor` for complex workflows instead of chained function calls.

### Implementation Plan
1.  **Refactor `Mcp.MultiTenant`**:
    -   Extract schema management to `Mcp.Infrastructure.TenantManager`.
    -   Extract context switching to `Mcp.Infrastructure.Context`.
2.  **Migrate Business Logic**:
    -   Move Graph queries to `Mcp.Platform.Graph` or domain resources.
    -   Move Vector search to `Mcp.AI.VectorStore`.
    -   Move Time-series analytics to `Mcp.Analytics` domain.
3.  **Harden Security**:
    -   Audit and replace string interpolation with parameterized queries.

---

## 12. 🏁 Final Polish: Completing the Foundation

**Status**: ✅ Completed

### Problem
The `Mcp.MultiTenant` module promises advanced capabilities (TimescaleDB, PostGIS), but the underlying Docker environment is missing these extensions, causing tests to be skipped. Additionally, the `Mcp.Platform.Tenant` resource lacks standard lifecycle actions (`suspend`, `activate`) required for operational management.

### Solution
1.  **Docker Environment**: Install `timescaledb` and `postgis` extensions in the custom Postgres image.
2.  **Platform Domain**: Implement missing actions in `Mcp.Platform.Tenant` to fully support the tenant lifecycle.

### Implementation Steps
1.  **Docker**:
    -   Update `docker/postgres/Dockerfile` to install `timescaledb` and `postgis`.
    -   Rebuild the container.
2.  **Platform**:
    -   Add `suspend`, `activate`, `cancel` actions to `Mcp.Platform.Tenant`.
    -   Ensure these actions update the `status` attribute correctly.



