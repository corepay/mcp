# Security API Reference

## AshCloak Extension

### `cloak` DSL
Configuration block for the `AshCloak` extension.

| Option | Type | Description |
| :--- | :--- | :--- |
| `vault` | `module` | The Cloak Vault module to use for encryption. |
| `attributes` | `list(atom)` | List of attributes to encrypt. |
| `decrypt_by_default` | `list(atom)` | Attributes to automatically decrypt on read. |
| `on_decrypt_error` | `atom` | Action to take on decryption failure (`:error` or `:nil`). |

## Mcp.Secrets.VaultClient

### `get_secret/1`
Retrieves a decrypted secret by name.

**Signature**: `get_secret(name :: String.t()) :: {:ok, String.t()} | {:error, term()}`

**Example**:
```elixir
Mcp.Secrets.VaultClient.get_secret("my_secret")
```

### `put_secret/2`
Stores a new secret or updates an existing one.

**Signature**: `put_secret(name :: String.t(), value :: String.t(), description :: String.t() \\ "") :: {:ok, map()} | {:error, term()}`

**Example**:
```elixir
Mcp.Secrets.VaultClient.put_secret("api_key", "12345", "Production API Key")
```

## Database Schema (`vault`)

### `vault.secrets`
The underlying table storing encrypted secrets.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `uuid` | Unique identifier. |
| `name` | `text` | Unique name of the secret. |
| `secret` | `text` | The encrypted secret value. |
| `description` | `text` | Optional description. |
| `created_at` | `timestamptz` | Creation timestamp. |
| `updated_at` | `timestamptz` | Last update timestamp. |

### `vault.decrypted_secrets`
View that returns decrypted secrets (requires appropriate permissions).
