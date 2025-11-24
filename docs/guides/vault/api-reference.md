# Secrets Management & Vault Integration API Reference

## Overview

The Secrets Management API provides comprehensive functions for secure credential storage, tenant-isolated secret management, and Vault operations. All operations require proper authentication and appropriate secret access permissions.

## Authentication

Most secret operations require tenant context and proper authentication:

```elixir
# Authentication token (if using token-based auth)
token = System.get_env("VAULT_TOKEN", "dev-root-token")

# Tenant context for isolation
tenant_id = "your_tenant_id"
```

## Base Vault Operations

### Mcp.Vault GenServer API

Basic vault operations for general secret management:

```elixir
# Read secret from vault
Mcp.Vault.read_secret("secret/path")

# Write data to vault
Mcp.Vault.write_secret("secret/path", %{key: "value", data: "secret"})

# Delete secret from vault
Mcp.Vault.delete_secret("secret/path")

# List secrets at path (mock implementation)
Mcp.Vault.list_secrets("path/prefix")

# Generate secure password
Mcp.Vault.generate_password(32)
```

### Mcp.Secrets.VaultClient Advanced API

Tenant-aware secret management with authentication:

#### Authentication

```elixir
# Authenticate with vault
Mcp.Secrets.VaultClient.authenticate("your-vault-token")
```

#### Secret Operations

**Get Secret:**
```elixir
# Get secret with tenant isolation
{:ok, value} = Mcp.Secrets.VaultClient.get_secret(
  "database/credentials",
  tenant_id: "tenant_123"
)

# Get secret without tenant (global secrets)
{:ok, value} = Mcp.Secrets.VaultClient.get_secret("platform/config")
```

**Set Secret:**
```elixir
# Store secret with tenant isolation
:ok = Mcp.Secrets.VaultClient.set_secret(
  "api/external_key",
  %{api_key: "secret-key-value", endpoint: "https://api.example.com"},
  tenant_id: "tenant_123"
)
```

**Delete Secret:**
```elixir
# Delete secret with tenant isolation
:ok = Mcp.Secrets.VaultClient.delete_secret(
  "old/secret/path",
  tenant_id: "tenant_123"
)
```

**List Secrets:**
```elixir
# List secrets under path with tenant isolation
{:ok, secrets} = Mcp.Secrets.VaultClient.list_secrets(
  "database/",
  tenant_id: "tenant_123"
)
# Returns: ["database/readonly", "database/admin", "database/backup"]
```

#### Tenant Secret Management

**Create Multiple Tenant Secrets:**
```elixir
secrets = %{
  "smtp/password" => %{value: "smtp_secret_password"},
  "api/payment_key" => %{key: "payment_api_key_value", environment: "production"},
  "encryption/key" => %{key: Base.encode64(:crypto.strong_rand_bytes(32))}
}

{:ok, results} = Mcp.Secrets.VaultClient.create_tenant_secrets(
  "tenant_456",
  secrets
)
# Returns: [{:ok, "smtp/password"}, {:ok, "api/payment_key"}, {:ok, "encryption/key"}]
```

**Get All Tenant Secrets:**
```elixir
{:ok, all_secrets} = Mcp.Secrets.VaultClient.get_tenant_secrets("tenant_456")
# Returns: [
#   {"smtp/password", %{value: "smtp_secret_password"}},
#   {"api/payment_key", %{key: "payment_api_key_value"}},
#   {"encryption/key", %{key: "..."}}
# ]
```

## Response Patterns

### Success Responses

```elixir
# Secret read success
{:ok, %{"value" => "secret-data", "metadata" => "extra-info"}}

# Secret write success
:ok

# Multiple operations success
{:ok, [{:ok, "secret1"}, {:ok, "secret2"}, {:error, {"secret3", :not_found}}]}
```

### Error Responses

```elixir
# Authentication failure
{:error, :not_authenticated}

# Secret not found
{:error, :not_found}

# Vault connection error
{:error, :connection_failed}

# Permission denied
{:error, :access_denied}

# Invalid input
{:error, :invalid_path}
```

## Common Use Cases

### Database Credentials Management

```elixir
# Store database credentials for tenant
def setup_tenant_database(tenant_id, db_config) do
  credentials = %{
    username: db_config.username,
    password: db_config.password,
    host: db_config.host,
    database: db_config.database,
    port: db_config.port
  }

  Mcp.Secrets.VaultClient.set_secret(
    "database/main",
    credentials,
    tenant_id: tenant_id
  )
end

# Retrieve database credentials
def get_tenant_database_creds(tenant_id) do
  case Mcp.Secrets.VaultClient.get_secret("database/main", tenant_id: tenant_id) do
    {:ok, creds} -> {:ok, creds}
    {:error, _} -> {:error, :database_credentials_not_found}
  end
end
```

### API Key Management

```elixir
# Store external API keys
def store_api_keys(tenant_id, service_configs) do
  secrets = %{
    "stripe/secret_key" => %{key: service_configs.stripe_secret},
    "google/analytics" => %{key: service_configs.ga_key, tracking_id: service_configs.ga_id},
    "sendgrid/api_key" => %{key: service_configs.sendgrid_key}
  }

  Mcp.Secrets.VaultClient.create_tenant_secrets(tenant_id, secrets)
end
```

### Encryption Key Management

```elixir
# Generate and store encryption keys
def setup_tenant_encryption(tenant_id) do
  encryption_key = :crypto.strong_rand_bytes(32) |> Base.encode64()

  Mcp.Secrets.VaultClient.set_secret(
    "encryption/data_key",
    %{key: encryption_key, algorithm: "AES-256-GCM"},
    tenant_id: tenant_id
  )
end
```

## Error Handling Patterns

### Safe Secret Retrieval

```elixir
def get_secret_with_defaults(tenant_id, path, default \\ nil) do
  case Mcp.Secrets.VaultClient.get_secret(path, tenant_id: tenant_id) do
    {:ok, value} -> {:ok, value}
    {:error, :not_found} when not is_nil(default) -> {:ok, default}
    error -> error
  end
end
```

### Batch Secret Operations

```elixir
def get_multiple_secrets(tenant_id, paths) do
  paths
  |> Enum.map(fn path ->
    {path, Mcp.Secrets.VaultClient.get_secret(path, tenant_id: tenant_id)}
  end)
  |> Enum.filter(fn {_path, result} -> match?({:ok, _}, result) end)
  |> Enum.map(fn {path, {:ok, value}} -> {path, value} end)
end
```

## Security Considerations

### Secret Access Validation

```elixir
def can_access_secret?(user, tenant_id, secret_path) do
  cond do
    user.role == :admin -> true
    user.tenant_id == tenant_id and allowed_secret_path?(user, secret_path) -> true
    true -> false
  end
end
```

### Audit Logging

```elixir
def log_secret_access(user, tenant_id, secret_path, action) do
  Logger.info("Secret access", %{
    user_id: user.id,
    tenant_id: tenant_id,
    secret_path: secret_path,
    action: action,
    timestamp: DateTime.utc_now()
  })
end
```

## Configuration

### Vault Client Configuration

```elixir
# config/config.exs
config :vaultex, :vaultex,
  vault_address: System.get_env("VAULT_ADDR", "http://localhost:44567"),
  vault_token: System.get_env("VAULT_TOKEN", "dev-root-token"),
  auth_method: :token
```

### Environment Variables

```bash
# Vault connection
VAULT_ADDR=http://localhost:44567
VAULT_TOKEN=dev-root-token

# Optional: Production configuration
VAULT_TLS_VERIFY=true
VAULT_TIMEOUT=5000
```

This API reference provides comprehensive documentation for the actual vault and secrets management functions implemented in the MCP platform, including GenServer-based operations, tenant isolation, and secret lifecycle management.