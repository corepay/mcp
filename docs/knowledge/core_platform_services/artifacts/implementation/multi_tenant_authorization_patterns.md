# Multi-Tenant Authorization Patterns

Strict tenant isolation is enforced through centralized policy helpers and custom Ash checks.

## 1. Centralized Helper: `TenantHelpers`
To avoid logic drift, all tenant-to-actor lookups are centralized in `Mcp.Platform.TenantHelpers`.

```elixir
def get_actor_tenant_ids(%Mcp.Accounts.User{id: user_id}) do
  # Traverse membership chain: User -> TeamMember -> Team -> Tenant
  TeamMember
  |> Ash.Query.filter(user_id == ^user_id)
  |> Ash.read!(authorize?: false)
  |> Enum.map(& &1.team_id)
  # ... further resolution to Tenant entity_id
end
```

## 2. Pattern: Cross-Resource Relationship Authorization
When a resource (e.g., `WebhookDelivery`) belongs to a parent (e.g., `WebhookEndpoint`), policies must verify access via the parent's `tenant_id`.

**Pattern**: Create a `FilterCheck` that fetches or utilizes assigned parent data to verify the actor's permission against the parent's organization.

## 3. Best Practices
- **Pinning Values**: Always call Elixir functions (like `Helpers.get_actor_tenant_ids(actor)`) outside an `expr` and pin the result (`^ids`) within the expression to ensure policy performance.
- **Actor Propagation**: When calling internal actions within manual blocks, explicitly pass the `actor` context to satisfy downstream policies.
- **Creation Guards**: For `create` actions, prefer simple changeset-based checks over `FilterCheck` modules to avoid query-time crashes (`CannotFilterCreates`).
