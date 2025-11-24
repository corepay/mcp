# Secrets Management & Vault Integration - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP vault and secrets management system. Includes actual API functions, HashiCorp Vault integration, tenant isolation, and secret management patterns based on the real codebase.

## System Architecture

The secrets management system uses a multi-layered architecture:

- **Mcp.Vault**: High-level Vault GenServer for basic secret operations
- **Mcp.Secrets.VaultClient**: Advanced Vault client with tenant isolation and authentication
- **Mcp.Secrets.Supervisor**: Supervision tree for all secrets services
- **Tenant Isolation**: Per-tenant secret paths (`tenants/{tenant_id}`)
- **Mock Implementation**: Development-friendly mock responses for testing

## Core Vault API

### Main Vault GenServer Functions

The `Mcp.Vault` module provides the primary interface:

```elixir
# Read secret from Vault
Vault.read_secret(path)

# Write secret to Vault
Vault.write_secret(path, data)

# Delete secret from Vault
Vault.delete_secret(path)

# List secrets at path
Vault.list_secrets(path \\ "")

# Generate secure password
Vault.generate_password(length \\ 32)
```

### Advanced Vault Client Functions

The `Mcp.Secrets.VaultClient` provides tenant-aware secret management:

```elixir
# Authentication with Vault
VaultClient.authenticate(token \\ @vault_token)

# Get secret with tenant isolation
VaultClient.get_secret(path, opts \\ [])

# Set secret with tenant isolation
VaultClient.set_secret(path, value, opts \\ [])

# Delete secret with tenant isolation
VaultClient.delete_secret(path, opts \\ [])

# List secrets with tenant isolation
VaultClient.list_secrets(path_prefix, opts \\ [])

# Create multiple tenant secrets
VaultClient.create_tenant_secrets(tenant_id, secrets, opts \\ [])

# Get all tenant secrets
VaultClient.get_tenant_secrets(tenant_id, opts \\ [])
```

## Integration Examples

### Basic Secret Operations

```elixir
# Example: Store and retrieve database credentials
def store_database_credentials(tenant_id, db_config) do
  secret_data = %{
    "username" => db_config.username,
    "password" => db_config.password,
    "host" => db_config.host,
    "database" => db_config.database
  }

  case Mcp.Secrets.VaultClient.set_secret(
         "database/credentials",
         secret_data,
         tenant_id: tenant_id
       ) do
    :ok ->
      {:ok, "Database credentials stored successfully"}
    {:error, reason} ->
      {:error, "Failed to store credentials: #{inspect(reason)}"}
  end
end

def get_database_credentials(tenant_id) do
  case Mcp.Secrets.VaultClient.get_secret(
         "database/credentials",
         tenant_id: tenant_id
       ) do
    {:ok, credentials} ->
      {:ok, credentials}
    {:error, reason} ->
      {:error, "Failed to retrieve credentials: #{inspect(reason)}"}
  end
end
```

### Tenant Secret Management

```elixir
# Example: Initialize tenant with default secrets
def initialize_tenant_secrets(tenant_id, config) do
  default_secrets = %{
    "smtp/password" => config.smtp_password,
    "api/external_key" => config.api_key,
    "database/readonly_user" => config.db_readonly_password,
    "encryption/key" => generate_encryption_key()
  }

  case Mcp.Secrets.VaultClient.create_tenant_secrets(
         tenant_id,
         default_secrets
       ) do
    {:ok, results} ->
      successful = Enum.count(results, &match?({:ok, _}, &1))
      Logger.info("Initialized #{successful}/#{length(default_secrets)} secrets for tenant #{tenant_id}")
      {:ok, results}
    {:error, reason} ->
      {:error, "Failed to initialize tenant secrets: #{inspect(reason)}"}
  end
end
```

### Phoenix Controller Integration

```elixir
defmodule McpWeb.SecretsController do
  use McpWeb, :controller

  def create_secret(conn, %{"secret" => secret_params}) do
    tenant_id = conn.assigns.current_tenant.id

    case Mcp.Secrets.VaultClient.set_secret(
           secret_params["path"],
           secret_params["value"],
           tenant_id: tenant_id
         ) do
      :ok ->
        json(conn, %{success: true, message: "Secret stored successfully"})

      {:error, reason} ->
        json(conn, %{success: false, error: inspect(reason)})
    end
  end

  def get_secret(conn, %{"path" => path}) do
    tenant_id = conn.assigns.current_tenant.id

    case Mcp.Secrets.VaultClient.get_secret(path, tenant_id: tenant_id) do
      {:ok, value} ->
        json(conn, %{success: true, data: value})

      {:error, reason} ->
        json(conn, %{success: false, error: inspect(reason)})
    end
  end

  def list_secrets(conn, %{"prefix" => prefix}) do
    tenant_id = conn.assigns.current_tenant.id

    case Mcp.Secrets.VaultClient.list_secrets(prefix, tenant_id: tenant_id) do
      {:ok, secrets} ->
        json(conn, %{success: true, data: secrets})

      {:error, reason} ->
        json(conn, %{success: false, error: inspect(reason)})
    end
  end
end
```

### Background Job Secret Processing

```elixir
defmodule Mcp.Jobs.RotateSecrets do
  use Oban.Worker
  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id}}) do
    # Rotate sensitive secrets periodically
    case Mcp.Secrets.VaultClient.get_tenant_secrets(tenant_id) do
      {:ok, secrets} ->
        Enum.each(secrets, fn {secret_name, _current_value} ->
          if should_rotate_secret?(secret_name) do
            rotate_secret(tenant_id, secret_name)
          end
        end)

        Logger.info("Secret rotation completed for tenant #{tenant_id}")

      {:error, reason} ->
        Logger.error("Failed to retrieve secrets for rotation: #{inspect(reason)}")
    end
  end

  defp should_rotate_secret?(secret_name) do
    String.contains?(secret_name, "password") or
    String.contains?(secret_name, "key") or
    String.contains?(secret_name, "token")
  end

  defp rotate_secret(tenant_id, secret_name) do
    new_value = generate_secure_secret(secret_name)

    case Mcp.Secrets.VaultClient.set_secret(
           secret_name,
           new_value,
           tenant_id: tenant_id
         ) do
      :ok ->
        Logger.info("Rotated secret: #{secret_name} for tenant #{tenant_id}")
      {:error, reason} ->
        Logger.error("Failed to rotate secret #{secret_name}: #{inspect(reason)}")
    end
  end

  defp generate_secure_secret("password"), do: Mcp.Vault.generate_password(24)
  defp generate_secure_secret("api_key"), do: :crypto.strong_rand_bytes(32) |> Base.encode64()
  defp generate_secure_secret(_), do: Mcp.Vault.generate_password(32)
end
```

## Configuration and Setup

### Vault Configuration

```elixir
# config/config.exs
config :vaultex, :vaultex,
  vault_address: System.get_env("VAULT_ADDR", "http://localhost:44567"),
  vault_token: System.get_env("VAULT_TOKEN", "dev-root-token"),
  auth_method: :token

# Secrets configuration
config :mcp, Mcp.Secrets.VaultClient,
  vault_addr: System.get_env("VAULT_ADDR", "http://localhost:44567"),
  vault_token: System.get_env("VAULT_TOKEN", "mock-token"),
  auth_timeout: 5000
```

### Environment Variables

```bash
# Vault connection
VAULT_ADDR=http://localhost:44567
VAULT_TOKEN=dev-root-token

# Secrets management
SECRETS_ENCRYPTION_KEY=your-encryption-key
SECRET_ROTATION_INTERVAL=86400  # 24 hours in seconds
```

### Docker Compose Vault Setup

```yaml
# docker-compose.yml
services:
  vault:
    image: vault:1.15.0
    container_name: mcp-vault
    ports:
      - "44567:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=dev-root-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    volumes:
      - vault_data:/vault/data
    command: vault server -dev

volumes:
  vault_data:
```

## Testing Vault Operations

### Unit Tests

```elixir
defmodule Mcp.Secrets.VaultClientTest do
  use ExUnit.Case, async: true
  alias Mcp.Secrets.VaultClient

  describe "secret operations" do
    test "stores and retrieves secrets successfully" do
      tenant_id = "test_tenant_123"
      path = "test/secret"
      value = %{"data" => "secret_value", "type" => "test"}

      # Store secret
      assert :ok = VaultClient.set_secret(path, value, tenant_id: tenant_id)

      # Retrieve secret
      assert {:ok, retrieved_value} = VaultClient.get_secret(path, tenant_id: tenant_id)
      assert retrieved_value == value
    end

    test "handles tenant isolation correctly" do
      tenant1 = "tenant_1"
      tenant2 = "tenant_2"
      path = "shared/secret"
      value1 = %{"data" => "tenant1_value"}
      value2 = %{"data" => "tenant2_value"}

      # Store different values for different tenants
      VaultClient.set_secret(path, value1, tenant_id: tenant1)
      VaultClient.set_secret(path, value2, tenant_id: tenant2)

      # Verify isolation
      assert {:ok, retrieved1} = VaultClient.get_secret(path, tenant_id: tenant1)
      assert {:ok, retrieved2} = VaultClient.get_secret(path, tenant_id: tenant2)
      assert retrieved1 != retrieved2
    end

    test "lists secrets correctly" do
      tenant_id = "test_tenant_list"
      prefix = "test/"

      # Store multiple secrets
      VaultClient.set_secret("#{prefix}secret1", %{"value" => "data1"}, tenant_id: tenant_id)
      VaultClient.set_secret("#{prefix}secret2", %{"value" => "data2"}, tenant_id: tenant_id)

      # List secrets
      assert {:ok, secrets} = VaultClient.list_secrets(prefix, tenant_id: tenant_id)
      assert length(secrets) > 0
    end
  end

  describe "tenant secret management" do
    test "creates multiple tenant secrets" do
      tenant_id = "multi_secret_tenant"
      secrets = %{
        "db/password" => %{"value" => "db_pass"},
        "api/key" => %{"value" => "api_key_value"},
        "smtp/pass" => %{"value" => "smtp_password"}
      }

      assert {:ok, results} = VaultClient.create_tenant_secrets(tenant_id, secrets)
      assert length(results) == 3
    end
  end
end
```

### Integration Tests

```elixir
defmodule Mcp.VaultIntegrationTest do
  use ExUnit.Case, async: false

  describe "vault integration" do
    test "vault genserver operations" do
      # Test basic Vault GenServer
      assert {:ok, _password} = Mcp.Vault.generate_password(16)

      path = "test/integration"
      data = %{"test_key" => "test_value"}

      # Note: These will use mock implementation in test environment
      assert {:ok, _result} = Mcp.Vault.write_secret(path, data)
      assert {:ok, _data} = Mcp.Vault.read_secret(path)
      assert :ok = Mcp.Vault.delete_secret(path)
    end
  end
end
```

## Security Best Practices

### Secret Path Organization

```elixir
# Recommended secret path structure
defmodule SecretPaths do
  def tenant_database(tenant_id), do: "tenants/#{tenant_id}/database"
  def tenant_api_keys(tenant_id), do: "tenants/#{tenant_id}/api_keys"
  def tenant_encryption(tenant_id), do: "tenants/#{tenant_id}/encryption"
  def tenant_integrations(tenant_id), do: "tenants/#{tenant_id}/integrations"
  def platform_secrets(), do: "platform/secrets"
  def system_keys(), do: "system/keys"
end
```

### Access Control Patterns

```elixir
defmodule Mcp.Secrets.AccessControl do
  def can_access_secret?(user, tenant_id, secret_path) do
    cond do
      is_admin?(user) -> true
      is_tenant_owner?(user, tenant_id) -> true
      has_secret_permission?(user, secret_path) -> true
      true -> false
    end
  end

  defp is_admin?(user), do: :admin in user.roles
  defp is_tenant_owner?(user, tenant_id), do: user.tenant_id == tenant_id
  defp has_secret_permission?(user, secret_path), do: secret_path in user.allowed_secrets
end
```

## Performance Considerations

### Secret Caching

```elixir
defmodule Mcp.Secrets.Cache do
  use GenServer
  require Logger

  # Cache frequently accessed secrets
  def get_cached_secret(tenant_id, path) do
    cache_key = "#{tenant_id}:#{path}"

    case :ets.lookup(:secrets_cache, cache_key) do
      [{^cache_key, value, timestamp}] ->
        if timestamp > (DateTime.utc_now() |> DateTime.add(-300, :second)) do
          {:ok, value}
        else
          # Cache expired, fetch fresh
          fetch_and_cache(tenant_id, path, cache_key)
        end
      [] ->
        fetch_and_cache(tenant_id, path, cache_key)
    end
  end

  defp fetch_and_cache(tenant_id, path, cache_key) do
    case Mcp.Secrets.VaultClient.get_secret(path, tenant_id: tenant_id) do
      {:ok, value} ->
        :ets.insert(:secrets_cache, {cache_key, value, DateTime.utc_now()})
        {:ok, value}
      error ->
        error
    end
  end
end
```

This developer guide provides comprehensive technical implementation details for the vault and secrets management system, including actual API usage patterns, tenant isolation, GenServer architecture, and integration examples based on the real HashiCorp Vault integration in the MCP platform.