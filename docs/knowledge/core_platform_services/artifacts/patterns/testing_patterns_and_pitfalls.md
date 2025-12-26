# Testing Patterns and Pitfalls for Multi-Tenancy

Integration and unit testing in a multi-tenant environment (using `multitenancy strategy :context`) requires careful management of connection state, host resolution, and mock expectations.

## 1. The "Host Resolution" Trap
In standard Phoenix tests (`ConnCase`), the `conn` defaults to `www.example.com`.
Our platform's `ContextPlug` uses the host to lookup the tenant. 
**Symptom**: Standard tests fail with **404 Organization not found** because `www.example.com` matches no tenant in the database.

### 1.1. Pattern: The "Integration Tenant" Setup
For all integration tests (Controllers, LiveViews, Plugs), you **must** create a tenant and configure the `conn` to use its subdomain.

```elixir
setup %{conn: conn} do
  tenant = Mcp.Platform.Tenant.create!(%{
    name: "Integration Tenant",
    slug: "test-#{System.unique_integer([:positive])}",
    subdomain: "test-#{System.unique_integer([:positive])}"
  }, authorize?: false)

  # Spoof the host to match the tenant subdomain
  host = "#{tenant.subdomain}.localhost"

  {:ok,
   conn: Map.put(conn, :host, host),
   tenant: tenant}
end
```

### 1.2. Pattern: Async Task Context
Requests made inside background tasks (e.g., `Task.async`) create fresh connection structs. These connections do **not** inherit the `:host` configuration from the setup phase.

```elixir
# ✅ Correct Async Connection Setup
Task.async(fn ->
  conn = 
    build_conn()
    |> Map.put(:host, "#{tenant.subdomain}.localhost")
    |> post("/sign-in", params)
  
  assert response(conn, 302)
end)
```

## 2. Controller Validation Gates
Controllers often perform parameter validation *before* reaching the business logic or `Mox` call-sites. 

**Pitfall**: A test for an OAuth callback fails with "mock not invoked" because the request omitted a required parameter (like `code`), causing the controller to redirect early.

**Best Practice**: Ensure test requests are well-formed enough to pass controller guards, even when testing error paths (e.g., pass a valid-looking but failing `code`).

## 3. Mocking and Process Ownership (Mox)
When using `Mox` (e.g., for `OAuthMock` or `DnsVerifierMock`):
- Ensure `Mox.allow/3` is used if the mock is triggered in a different process.
- Verify that changes in host or redirection don't result in the mock being called on a connection that was halted early (diagnose by checking for 404/halted response).

## 4. Performance Sensitivity
Tests that assert on execution time (e.g., `avg_time < 300ms`) can be flaky in shared test environments or under concurrent load due to `ContextPlug` (middleware) and DB pool contention.

**Policy**:
- Treat timing assertions as "soft" signals unless strictly required by SLA.
- Prefer margins (e.g., 2x target latency) in CI.
- Use specialized `@tag :performance` to isolate timing-sensitive tests.

## 5. Ash-Specific Pitfalls

### 5.1. Ash.ToTenant Protocol
Passing a `Tenant` struct to an action might fail if Ash expects the schema string.
**Fix**: Pass `tenant: tenant.company_schema`.

### 5.2. Missing Membership Links (Policy Failure)
Policies often rely on membership chains (User -> TeamMember -> Team -> Tenant). If you only create a `Tenant` and `User` in your test, policy checks will fail because the user is not "enrolled" in the tenant's team.
**Solution**: Perform **Full Manual Enrollment** (Create Tenant, Team, and TeamMember) in your test setup.

### 5.3. Foundational Attribute Requirements
Platform resources like `Tenant` have strict requirements for `slug` and `subdomain` for routing purposes. Omitting these in test creation will result in validation errors.

## 6. LiveView Resolution
For `Phoenix.LiveViewTest.live/2`, ensure `conn.host` matches the tenant's expected subdomain. If resolution remains flaky, verify `Mcp.Platform.Tenant.by_subdomain` manually within the test to isolate if the issue is in the logic or the harness.
