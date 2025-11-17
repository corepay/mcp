# MCP Project Code Patterns

This memory documents specific code patterns and conventions used in this MCP (Model Context Protocol) project.

## Project Architecture

### Service Pattern
All communication services follow this pattern:
- GenServer-based with `handle_call/3` for synchronous operations
- Mock implementations that always return `{:ok, _}` tuples
- Provider-specific implementations in private functions
- Rate limiting and tenant isolation support

### Service File Structure
```elixir
defmodule Mcp.Communication.ServiceName do
  use GenServer
  require Logger

  # Module attributes (comment out if unused)
  # @providers [:provider1, :provider2]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # Public API functions
  def send_message(data, opts \\ []) do
    GenServer.call(__MODULE__, {:send_message, data, opts})
  end

  # GenServer callbacks
  @impl true
  def init(_init_arg) do
    Logger.info("Starting Communication ServiceName")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:operation, data, opts}, _from, state) do
    # Implementation
  end

  # Private helper functions
  defp do_operation_via_provider(data, provider, tenant_id) do
    # Provider-specific implementation
  end
end
```

## Mock Implementation Guidelines

### Always-Success Mock Pattern
For mock providers that always succeed:

```elixir
defp mock_operation(_data, _tenant_id) do
  # Mock implementation - always returns success
  # Real implementation would handle error cases
  result_id = "mock_#{generate_random_id()}"
  {:ok, %{id: result_id, status: :success, provider: "mock"}}
end
```

### Error Handling in Mocks
Since mocks always succeed, document this in the calling code:

```elixir
# mock_operation always returns {:ok, _}, so no error handling needed
result = mock_operation(data, tenant_id)
{:reply, {:ok, result}, state}
```

## Parameter Patterns

### Options Parameter (`opts`)
Most functions accept an `opts \\ []` parameter for:
- `tenant_id` - For multi-tenancy support
- Provider-specific options
- Timeout configurations
- Debug/logging flags

```elixir
def send_data(data, opts \\ []) do
  tenant_id = Keyword.get(opts, :tenant_id, "global")
  timeout = Keyword.get(opts, :timeout, 5000)
  # ...
end
```

### Unused Parameters
When parameters are needed for interface compatibility but not used:

```elixir
# For parameters that might be used in future implementations
defp provider_specific(_data, "mock", _tenant_id) do
  # Currently unused but kept for interface consistency
end

# For parameters that are only used in logging
defp process_with_metadata(data, opts) do
  Logger.debug("Processing with opts: #{inspect(opts)}")
  # opts not otherwise used in current implementation
end
```

## Multi-Tenancy Patterns

### Tenant Context Extraction
```elixir
def extract_tenant_context(opts) do
  tenant_id = Keyword.get(opts, :tenant_id, "global")
  user_id = Keyword.get(opts, :user_id)
  request_id = Keyword.get(opts, :request_id, generate_request_id())
  
  %{
    tenant_id: tenant_id,
    user_id: user_id, 
    request_id: request_id
  }
end
```

### Path Construction for Tenants
```elixir
defp build_tenant_path(base_path, nil), do: base_path
defp build_tenant_path(base_path, tenant_id) do
  if String.starts_with?(base_path, "tenants/") do
    base_path  # Already tenant-specific
  else
    "tenants/#{tenant_id}/#{base_path}"
  end
end
```

## Rate Limiting Patterns

### Internal Rate Limiting
```elixir
defp check_rate_limit_internal(rate_limits, tenant_id, key, opts) do
  # Default limits
  default_limit = %{
    requests_per_minute: 60,
    requests_per_hour: 1000
  }
  
  # Merge with opts
  limits = Keyword.get(opts, :rate_limits, default_limit)
  
  # Check and update limits
  # Implementation would go here
  {:ok, :allowed}
end
```

## Error Handling Patterns

### Provider Abstraction
When abstracting multiple providers:

```elixir
defp send_via_provider(data, provider, tenant_id) do
  case provider do
    "mock" -> send_via_mock(data, tenant_id)
    "provider1" -> send_via_provider1(data, tenant_id)
    "provider2" -> send_via_provider2(data, tenant_id)
    _ -> {:error, {:unsupported_provider, provider}}
  end
end
```

### Graceful Degradation
```elixir
defp get_with_fallback(primary_func, fallback_func, opts) do
  case primary_func.(opts) do
    {:ok, result} -> {:ok, result}
    {:error, _reason} -> 
      Logger.warning("Primary failed, using fallback")
      fallback_func.(opts)
  end
end
```

## Testing Patterns

### Mock Service Testing
```elixir
defmodule MyServiceTest do
  use ExUnit.Case
  
  test "mock provider always succeeds" do
    # Test that mock implementations follow the always-success pattern
    assert {:ok, result} = MyService.send_operation(%{}, provider: "mock")
    assert result.status == :success
    assert result.provider == "mock"
  end
end
```

## Configuration Patterns

### Environment Variable Defaults
```elixir
@config_attr System.get_env("VAR_NAME", "default_value")
# Comment out if unused:
# @unused_config System.get_env("UNUSED_VAR", "default")  # Currently unused
```

## Linting Compliance

This project follows strict linting rules:
- No unused variables (use underscore prefix)
- No unreachable clauses in mock implementations  
- Group function clauses by arity
- Use module attributes or comment them out
- Document mock behavior patterns

These patterns ensure consistent, maintainable code across all MCP services.