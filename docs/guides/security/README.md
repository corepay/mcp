# Security & Data Protection

## Overview
The MCP Platform prioritizes security through a multi-layered approach, leveraging **AshCloak** for application-level encryption and **Supabase Vault** for secure secrets management. This ensures that sensitive customer data (PII) and system credentials are protected at rest and in transit, meeting enterprise compliance standards.

## Key Capabilities

### 1. Application-Level Encryption (AshCloak)
- **Automatic Encryption**: Sensitive fields (e.g., `totp_secret`, `backup_codes`) are encrypted before being written to the database.
- **Transparent Decryption**: Authorized resources can seamlessly read encrypted data without complex decryption logic.
- **Key Management**: Uses environment-specific keys managed securely.

### 2. Secrets Management (Supabase Vault)
- **Secure Storage**: API keys, tokens, and other system secrets are stored in a dedicated, encrypted Vault table.
- **Postgres Integration**: Secrets are accessible to the database for operations but protected from unauthorized access.
- **No Hardcoding**: Eliminates the risk of checking secrets into version control.

## Quick Start

### Encrypting a Field
To encrypt a field in an Ash Resource:
1. Add `AshCloak` to the resource extensions.
2. Define the `cloak` block with the vault and attributes.
3. Run migrations to ensure the column is `binary`.

### Managing Secrets
Secrets are managed via the `Mcp.Secrets.VaultClient` or directly in the Supabase dashboard (if available).

## Related Resources
- [Authentication Guide](../authentication/README.md)
- [GDPR Compliance](../gdpr-compliance/README.md)
