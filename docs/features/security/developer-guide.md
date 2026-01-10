# Security Developer Guide

## Introduction
This guide covers the implementation of security features in the MCP Platform, specifically focusing on **AshCloak** for field-level encryption and **Supabase Vault** for secrets management.

## AshCloak Implementation

### 1. Configuration
Ensure `Mcp.Vault` is configured in `config/config.exs`:

```elixir
config :mcp, Mcp.Vault,
  json_library: Jason,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: System.get_env("CLOAK_KEY")}
  ]
```

### 2. Resource Setup
To encrypt sensitive attributes in an Ash Resource:

```elixir
defmodule Mcp.Accounts.User do
  use Ash.Resource,
    extensions: [AshCloak]

  cloak do
    vault Mcp.Vault
    attributes [:totp_secret, :backup_codes]
    decrypt_by_default [:totp_secret]
  end

  attributes do
    attribute :totp_secret, :binary do
      allow_nil? true
      sensitive? true
    end
  end
end
```

### 3. Migrations
Encrypted fields must be stored as `binary`.

```elixir
add :totp_secret, :binary
```

## Secrets Management (Supabase Vault)

### 1. Architecture
We use the `supabase_vault` Postgres extension. Secrets are stored in the `vault.secrets` table and accessed via the `vault.decrypted_secrets` view.

### 2. Usage via `Mcp.Secrets.VaultClient`

```elixir
# Storing a secret
Mcp.Secrets.VaultClient.put_secret("stripe_api_key", "sk_test_...")

# Retrieving a secret
{:ok, secret} = Mcp.Secrets.VaultClient.get_secret("stripe_api_key")
```

### 3. Database Access
You can access secrets directly in SQL (e.g., for FDWs):

```sql
SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'stripe_api_key';
```

## Best Practices
- **Never log decrypted secrets.** Use `sensitive?: true` in Ash attributes.
- **Rotate Keys**: regularly rotate the `CLOAK_KEY` and re-encrypt data.
- **Least Privilege**: Only grant access to the `vault` schema to necessary database roles.
