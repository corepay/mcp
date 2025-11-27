# Security User Guide

## Overview
This guide is intended for System Administrators and DevOps engineers responsible for managing the security configuration of the MCP Platform.

## Managing Encryption Keys

### Environment Variables
The application uses the `CLOAK_KEY` environment variable for data encryption.
- **Production**: This key should be generated securely (e.g., `32` random bytes, base64 encoded) and injected via the deployment platform's secrets manager.
- **Development**: A default key is provided in `config/dev.exs` for convenience.

**Generating a Key**:
```bash
openssl rand -base64 32
```

> [!WARNING]
> If you lose the `CLOAK_KEY`, all data encrypted with it will be irretrievably lost. Back up your keys securely!

## Managing Secrets (Vault)

### Adding a Secret
You can add secrets via the Elixir console or SQL.

**Via SQL**:
```sql
SELECT vault.create_secret('my_api_key', 'secret_value', 'Description of key');
```

### Rotating Secrets
1. Generate a new secret value.
2. Update the secret in the Vault.
3. Restart the application if the secret is cached or loaded at startup.

## Troubleshooting

### Decryption Errors
If you encounter errors like `Cloak.MissingCipher`, it usually means:
1. The `CLOAK_KEY` environment variable is missing or incorrect.
2. The data was encrypted with an old key that has been rotated out without re-encrypting the data.

### Vault Access Denied
If the application cannot read secrets:
1. Check that the database user has `SELECT` permissions on `vault.decrypted_secrets`.
2. Verify that the `pgsodium` extension is properly loaded.
