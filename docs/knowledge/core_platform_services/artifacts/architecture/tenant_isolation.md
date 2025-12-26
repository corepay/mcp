# Tenant Isolation Architecture

## The Concept: "Schema-Based Multi-Tenancy"
We utilize PostgreSQL schemas to isolate tenant data.
- **Public Schema (`public`)**: Shared data (Users, Tenants, API Keys, Platform Settings).
- **Tenant Schemas (`tenant_<uuid>`)**: Isolated business data (Orders, Products, CRM).

## Request Lifecycle

```mermaid
graph TD
    A[Request] --> B(Endpoint)
    B --> C{ContextPlug}
    
    C -- Host Lookup --> D[Redis Cache]
    D -- Hit --> C
    D -- Miss --> E[DB: Tenants]
    E --> D
    
    C --> F{Valid Tenant?}
    F -- No --> G[404 Not Found]
    F -- Yes --> H[Assign: conn.assigns.current_tenant]
    
    H --> I{Public/App Route?}
    I -- Public --> J[Execute Controller]
    I -- App/Tenant --> K[Ash.set_tenant(tenant.schema)]
    K --> L[Execute Action]
```

## `TenantManager` Service
Located at `lib/mcp/infrastructure/tenant_manager.ex`.

This service is the single source of truth for resolving tenants.
- **`get_tenant_by_host/1`**: Resolves tenant from a hostname (e.g., `acme.mcp.com`).
- **`get_tenant_by_slug/1`**: Resolves tenant from a URL path slug (e.g., `/app/acme`).
- **Caching**: heavily cached via Redis to ensure sub-millisecond resolution.

## `Context` Struct
Located at `lib/mcp/infrastructure/context.ex`.

Instead of passing `conn` or `socket` deep into services, we extract a `Context` struct:
```elixir
%Mcp.Infrastructure.Context{
  tenant_id: "...",
  user_id: "...",
  permissions: [:admin, :write],
  api_key_id: "..." (optional)
}
```
This ensures services remain framework-agnostic.
