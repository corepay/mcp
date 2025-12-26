# Authentication Pipeline

## 1. API Authentication (`ApiAuthPlug`)
This plug secures `/api/*` routes.

### Logic Flow
1. **Check Headers**: Looks for `X-API-Key` or `Authorization: Bearer <sk_...>`.
2. **Lookup Key**: Calls `Mcp.Platform.ApiKey.authenticate/1`.
    - Key is hashed (SHA256) and compared against stored hash.
3. **Validate Scope**: Checks if key has permission for the requested resource (todo).
4. **Assign Context**:
    - `conn.assigns.current_api_key`
    - `conn.assigns.current_tenant` (if key is tenant-scoped)
5. **Rate Limiting**: (Planned) Check usage limits via `Mcp.Billing`.

## 2. Browser Authentication (`SessionPlug`)
This plug secures browser routes.

### Logic Flow
1. **Session Fetch**: Reads `user_token` from encrypted session cookie.
2. **Validation**: verifies `AshAuthentication` token.
3. **Tenant Check**: Ensures user belongs to the tenant resolved by `ContextPlug`.
4. **Resolution**: Sets `conn.assigns.current_user`.

## 3. Context Caching (Redis)
To ensure performance, `ContextPlug` caches tenant resolution:

- **Key**: `tenant_host:<hostname>`
- **Value**: `serialized_tenant_struct`
- **TTL**: 60 seconds (short TTL to allow "instant" revocation/updates).
- **Backend**: `Redix` via `Mcp.Infrastructure.CacheManager`.

### Code Reference
```elixir
# lib/mcp_web/plugs/context_plug.ex
def call(conn, _opts) do
  host = conn.host
  case CacheManager.fetch("tenant_host:#{host}", fn -> TenantManager.get_by_host(host) end) do
    {:ok, tenant} -> assign(conn, :current_tenant, tenant)
    _ -> 
      conn 
      |> send_resp(404, "Organization not found") 
      |> halt()
  end
end
```
