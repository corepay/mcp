# Testing Strategies for Multi-Tenancy

## The "Host Resolution" Trap
In standard Phoenix tests, `conn` defaults to `www.example.com`.
In our platform, `ContextPlug` uses the host to lookup the tenant.
**Problem**: Standard tests fail with 404 because `www.example.com` matches no tenant.

## Pattern: The "Integration Tenant" Setup

When writing integration tests (Controllers, LiveViews, Plugs), you **must** create a tenant and configure the `conn` to use its subdomain.

### Example Setup Block

```elixir
setup %{conn: conn} do
  # 1. Create a real tenant for this test context
  tenant =
    Mcp.Platform.Tenant.create!(%{
      name: "Integration Tenant",
      # Use unique slugs to avoid conflicts
      slug: "test-#{System.unique_integer([:positive])}",
      subdomain: "test-#{System.unique_integer([:positive])}"
    }, authorize?: false)

  # 2. Spoof the host header
  # Note the .localhost suffix which is standard for local dev
  host = "#{tenant.subdomain}.localhost"

  {:ok,
   conn: Map.put(conn, :host, host), # CRITICAL STEP
   tenant: tenant}
end
```

### Pattern: Async Performance Tests
When using `Task.async` in tests, the process dictionary (and `conn`) are not automatically shared/cloned in a way that preserves the specific modified `conn` struct unless explicitly passed.

If creating *new* connections inside a `Task`, remember to apply the host:

```elixir
Task.async(fn ->
  # BAD: Defaults to www.example.com -> 404
  # conn = build_conn() 

  # GOOD:
  conn = 
    build_conn()
    |> Map.put(:host, "#{tenant.subdomain}.localhost")
    
  get(conn, "/path")
end)
```

## Mocking External Services (OAuth)
When testing controllers that use `Ueberauth` or other providers:
1. Ensure mocks (`Mox`) are set up in `test_helper.exs`.
2. Validate incoming parameters matches strict controller expectations (e.g., if controller expects `code` param, don't send `nil` or it might bypass the mock call logic and fail verification).
