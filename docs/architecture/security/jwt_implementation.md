# JWT Session Management Implementation

This document describes the comprehensive JWT session management system implemented for Story 2.6 of the Base MCP project.

## Overview

The JWT session management system provides:
- **JWT-based authentication** with access and refresh tokens
- **Multi-tenant authorization** with current_context and authorized_contexts
- **Sliding session refresh** for improved user experience
- **Encrypted cookie storage** for secure token management
- **Comprehensive security validation** and monitoring
- **Error handling** with user-friendly messages
- **Session management** with device fingerprinting

## Architecture

### Core Components

1. **JWT Utilities (`lib/mcp/accounts/jwt.ex`)**
   - Token creation, signing, and verification
   - Context management for multi-tenant authorization
   - Sliding refresh logic
   - Token encryption for secure cookie storage

2. **Enhanced Auth Module (`lib/mcp/accounts/auth.ex`)**
   - JWT session creation with context and metadata
   - Token verification and refresh
   - Session revocation
   - Legacy token compatibility

3. **Updated Token Resource (`lib/mcp/accounts/token.ex`)**
   - JWT-specific fields (jti, session_id, device_id, last_used_at)
   - JWT token tracking and metadata storage
   - Session grouping and device management

4. **Security Module (`lib/mcp/accounts/security.ex`)**
   - Login attempt validation
   - Suspicious activity detection
   - Rate limiting and IP reputation checking
   - Security incident handling

5. **Error Handling (`lib/mcp/accounts/auth_errors.ex`)**
   - Standardized error types and messages
   - User-friendly error formatting
   - Recovery instructions
   - Security event logging

6. **Session Storage (`lib/mcp_web/auth/session_plug.ex`)**
   - Encrypted cookie management
   - Automatic token refresh
   - Phoenix Plug integration

7. **LiveView Integration (`lib/mcp_web/auth/live_auth.ex`)**
   - LiveView authentication hooks
   - Tenant context switching
   - Real-time session management

8. **Authorization Middleware (`lib/mcp_web/auth/authorization_plug.ex`)**
   - Tenant authorization checking
   - Permission validation
   - Context switching

9. **Background Scheduler (`lib/mcp/accounts/session_scheduler.ex`)**
   - Token cleanup
   - Session monitoring
   - Maintenance tasks

## Database Schema

### JWT Fields Added to auth_tokens table:

```sql
-- JWT identification fields
jti VARCHAR(255)              -- JWT ID for revocation tracking
session_id VARCHAR(255)       -- Session identifier for token grouping
device_id VARCHAR(255)        -- Device fingerprint for device-specific tokens
last_used_at TIMESTAMP        -- Last usage time for sliding refresh

-- Indexes for performance
CREATE UNIQUE INDEX idx_auth_tokens_jti ON auth_tokens(jti) WHERE jti IS NOT NULL;
CREATE INDEX idx_auth_tokens_session_id ON auth_tokens(session_id);
CREATE INDEX idx_auth_tokens_device_id ON auth_tokens(device_id);
```

## JWT Token Structure

### Access Token Claims:

```json
{
  "sub": "user_id",
  "email": "user@example.com",
  "type": "access",
  "iat": 1640995200,
  "exp": 1641081600,
  "jti": "jwt_id_123",
  "iss": "mcp-platform",
  "aud": "mcp-users",
  "current_context": {
    "tenant_id": "tenant_abc",
    "user_id": "user_123",
    "email": "user@example.com",
    "role": "member",
    "permissions": ["read:data", "write:data"]
  },
  "authorized_contexts": [
    {
      "tenant_id": "tenant_abc",
      "tenant_name": "Primary Organization",
      "role": "member",
      "permissions": ["read:data", "write:data"]
    },
    {
      "tenant_id": "tenant_xyz",
      "tenant_name": "Secondary Organization",
      "role": "admin",
      "permissions": ["read:all", "write:all", "manage:users"]
    }
  ],
  "session_id": "session_456",
  "device_id": "device_789"
}
```

### Refresh Token Claims:

```json
{
  "sub": "user_id",
  "email": "user@example.com",
  "type": "refresh",
  "iat": 1640995200,
  "exp": 1643587200,
  "jti": "jwt_id_124",
  "session_id": "session_456",
  "device_id": "device_789",
  "last_used_at": 1640995200
}
```

## Token Lifetimes

- **Access Token**: 24 hours
- **Refresh Token**: 30 days
- **Sliding Refresh Threshold**: 12 hours (refresh tokens older than this get new refresh tokens)
- **Cleanup Window**: 7 days (expired tokens kept for 7 days for audit purposes)

## Security Features

### 1. Token Security
- HMAC SHA-256 signing with application secret
- JTI (JWT ID) for individual token tracking and revocation
- Short access token lifetimes
- Token encryption for cookie storage
- Secure cookie settings (HttpOnly, Secure, SameSite)

### 2. Session Security
- Session-based token grouping
- Device fingerprinting for suspicious activity detection
- IP address and user agent tracking
- Geographic anomaly detection
- Rate limiting per IP and user

### 3. Authorization Security
- Multi-tenant context isolation
- Role-based access control (RBAC)
- Permission validation per tenant
- Tenant authorization checking

### 4. Monitoring and Alerting
- Suspicious activity detection
- Security event logging
- Automatic session revocation on threats
- Security incident handling

## Usage Examples

### User Authentication

```elixir
# Create JWT session for authenticated user
{:ok, session_data} = Auth.create_user_session(user, ip_address, [
  tenant_id: "primary_tenant",
  user_agent: user_agent_string,
  device_type: "web"
])

# Returns:
# %{
#   access_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   encrypted_access_token: "encrypted_...",
#   encrypted_refresh_token: "encrypted_...",
#   session_id: "session_abc123",
#   expires_at: ~U[2024-01-01 12:00:00Z],
#   user: %{id: "user_123", email: "user@example.com"},
#   current_context: %{tenant_id: "primary_tenant", role: "member"},
#   authorized_contexts: [...]
# }
```

### Token Verification

```elixir
# Verify JWT access token
{:ok, claims} = Auth.verify_jwt_access_token(access_token)

# Check tenant authorization
if Auth.authorized_for_tenant?(claims, "target_tenant") do
  # User authorized for this tenant
  current_context = Auth.get_current_context(claims)
  authorized_contexts = Auth.get_authorized_contexts(claims)
end
```

### Session Refresh

```elixir
# Refresh session using refresh token
{:ok, new_session} = Auth.refresh_jwt_session(refresh_token, [
  user_agent: new_user_agent,
  ip_address: new_ip_address
])

# Returns updated session data with new tokens
```

### Session Revocation

```elixir
# Revoke specific session by session_id or JTI
Auth.revoke_jwt_session("session_abc123")

# Revoke all user sessions
Auth.revoke_user_sessions(user_id)
```

## Phoenix Integration

### Router Configuration

```elixir
# In router.ex
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, {McpWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug McpWeb.Auth.SessionPlug, protected_routes: ["/admin", "/api"]
  plug McpWeb.Auth.AuthorizationPlug, tenant_required: true
end

pipeline :api do
  plug :accepts, ["json"]
  plug McpWeb.Auth.SessionPlug
  plug McpWeb.Auth.AuthorizationPlug
end
```

### LiveView Configuration

```elixir
# In live_view.ex
defmodule McpWeb.AppLive do
  use McpWeb, :live_view

  on_mount {McpWeb.Auth.LiveAuth, :require_authenticated}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("switch_tenant", %{"tenant_id" => tenant_id}, socket) do
    if McpWeb.Auth.LiveAuth.authorized_for_tenant?(socket, tenant_id) do
      {:noreply, McpWeb.Auth.LiveAuth.switch_tenant(socket, tenant_id)}
    else
      {:noreply, put_flash(socket, :error, "Not authorized for this tenant")}
    end
  end
end
```

## Error Handling

### Error Types and Responses

```elixir
# Authentication errors
{:error, :invalid_credentials}     # 401 - Login failed
{:error, :account_locked}         # 423 - Account temporarily locked
{:error, :token_expired}          # 401 - Session expired
{:error, :insufficient_permissions} # 403 - Not authorized

# Security errors
{:error, :suspicious_activity}    # 403 - Suspicious login patterns
{:error, :rate_limit_exceeded}    # 429 - Too many attempts
{:error, :device_untrusted}       # 401 - Unrecognized device
```

### User-Friendly Error Messages

```elixir
# Format user-friendly error messages
message = Mcp.Accounts.AuthErrors.format_user_error(:token_expired)
# "Your session has expired. Please sign in again."

# Get recovery instructions
instructions = Mcp.Accounts.AuthErrors.get_recovery_instructions(:account_locked)
# ["Wait 15 minutes for automatic unlock", "Use account recovery..."]
```

## Security Monitoring

### Security Events

```elixir
# Log security events
Mcp.Accounts.Security.log_security_event(:suspicious_login, %{
  user_id: user.id,
  ip_address: "192.168.1.1",
  user_agent: suspicious_ua
})

# Handle security incidents
Mcp.Accounts.Security.handle_security_incident(:token_theft_attempt, user_id, details)
```

### Background Maintenance

```elixir
# Get session statistics
{:ok, stats} = Mcp.Accounts.SessionScheduler.get_session_stats()

# Force cleanup
Mcp.Accounts.SessionScheduler.cleanup_expired_tokens()
```

## Migration Notes

### Database Migration

Run the migration to add JWT fields:

```bash
mix ecto.migrate
```

### Dependency Update

Add Joken to dependencies (use appropriate version for your setup):

```elixir
# mix.exs
{:joken, "~> 6.0"}
```

### Configuration

No additional configuration required - uses existing `secret_key_base` from Phoenix endpoint.

## Testing

Run comprehensive tests:

```bash
# Run JWT-specific tests
mix test test/mcp/accounts/jwt_test.exs

# Run all authentication tests
mix test test/mcp/accounts/

# Run with coverage
mix test --cover
```

## Performance Considerations

### Token Storage
- Database indexes on JTI, session_id, and device_id for efficient lookups
- Periodic cleanup of expired tokens (6-hour intervals)
- Redis-based rate limiting in production

### Session Refresh
- Sliding refresh threshold reduces unnecessary token creation
- Session grouping minimizes database queries
- Background cleanup prevents database bloat

### Security Monitoring
- Efficient anomaly detection algorithms
- Minimal performance impact on authentication flow
- Asynchronous security event logging

## Compliance and Standards

- **JWT Standard**: RFC 7519 compliant
- **Cookie Security**: Secure, HttpOnly, SameSite cookies
- **Data Protection**: Token encryption and secure storage
- **Audit Trail**: Comprehensive logging of security events
- **Rate Limiting**: Industry-standard rate limiting
- **Multi-tenancy**: Proper tenant isolation and authorization

## Future Enhancements

1. **OAuth Integration**: Support for external identity providers
2. **Advanced Threat Detection**: Machine learning-based anomaly detection
3. **Biometric Authentication**: Support for hardware security keys
4. **Session Analytics**: Advanced session behavior analysis
5. **GDPR Compliance**: Enhanced data protection and privacy controls

## Conclusion

This JWT session management implementation provides a comprehensive, secure, and scalable authentication system for the Base MCP platform. It maintains backward compatibility with existing authentication flows while adding modern JWT-based features, multi-tenant support, and robust security measures.

The implementation follows security best practices and provides a solid foundation for future authentication enhancements.