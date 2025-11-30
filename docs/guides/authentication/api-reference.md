# Authentication API Reference

Complete API specification for MCP platform authentication and authorization
system based on actual Phoenix router implementation.

## Base URL and Authentication

```elixir
# Base URL
base_url = "https://your-mcp-platform.com"

# Web-based authentication (browser sessions)
web_headers = %{
  "Content-Type" => "application/json",
  "Accept" => "application/json"
}

# API authentication with JWT token (if applicable)
api_headers = %{
  "Authorization" => "Bearer YOUR_JWT_TOKEN",
  "Content-Type" => "application/json",
  "Accept" => "application/json"
}
```

## Response Format

All API responses follow Phoenix LiveView/Controller response patterns:

```json
{
  "info": "Success message",
  "data": {
    // Response data (for success responses)
  },
  "error": {
    // Error object (for error responses)
    "type": "error_type",
    "message": "Human-readable message"
  }
}
```

## Web Authentication Endpoints

### Sign In

**Endpoint:** `POST /sign-in`

Authenticate user with email and password using Phoenix session management. Note
that this endpoint is available under each portal scope (e.g., `/admin/sign-in`,
`/tenant/sign-in`).

**Request:**

```json
{
  "session": {
    "email": "john.doe@example.com",
    "password": "SecurePassword123!"
  },
  "remember_me": true
}
```

**Response (200 OK):**

```json
{
  "info": "Successfully signed in",
  "data": {
    "user": {
      "id": "user-uuid",
      "email": "john.doe@example.com",
      "name": "John Doe",
      "status": "active",
      "last_sign_in_at": "2025-11-24T10:00:00Z"
    }
  }
}
```

### Sign Out

**Endpoint:** `DELETE /sign-out`

Sign out user and destroy session.

**Request:** (No body required) **Response (200 OK):**

```json
{
  "info": "Successfully signed out"
}
```

### Change Password

**Endpoint:** `GET /change_password`

Force password change for user session (for security compliance).

**Request:** (No body required, loads change password form) **Response:** (HTML
form rendered by ChangePasswordController)

## OAuth Authentication Endpoints

### OAuth Provider Authorization

**Endpoint:** `GET /auth/:provider`

Initiate OAuth authentication with external provider (Google, GitHub).

**Parameters:**

- `provider`: OAuth provider name (`google`, `github`)

**Response:** (Redirect to OAuth provider)

### OAuth Callback

**Endpoint:** `GET /auth/:provider/callback`

Handle OAuth callback from external provider.

**Parameters:**

- `provider`: OAuth provider name (`google`, `github`)
- `code`: Authorization code from OAuth provider
- `state`: State parameter for CSRF protection

**Response:** (Redirect to application after authentication)

## OAuth Linking Endpoints

### Link OAuth Provider

**Endpoint:** `POST /oauth/link/:provider`

Link additional OAuth provider to existing user account.

**Parameters:**

- `provider`: OAuth provider name (`google`, `github`)

**Response:** (Redirect to OAuth provider)

### OAuth Link Callback

**Endpoint:** `GET /oauth/link/:provider/callback`

Handle OAuth linking callback.

**Parameters:**

- `provider`: OAuth provider name (`google`, `github`)
- `code`: Authorization code from OAuth provider
- `state`: State parameter for CSRF protection

**Response:** (Redirect to application after linking)

### Unlink OAuth Provider

**Endpoint:** `DELETE /oauth/unlink/:provider`

Unlink OAuth provider from user account.

**Parameters:**

- `provider`: OAuth provider name (`google`, `github`)

**Response (200 OK):**

```json
{
  "info": "OAuth provider unlinked successfully",
  "data": {
    "provider": "google",
    "unlinked_at": "2025-11-24T10:00:00Z"
  }
}
```

### Get Provider Info

**Endpoint:** `GET /oauth/provider/:provider`

Get information about linked OAuth provider.

**Parameters:**

- `provider`: OAuth provider name (`google`, `github`)

**Response (200 OK):**

```json
{
  "info": "OAuth provider information",
  "data": {
    "provider": "google",
    "linked": true,
    "email": "john.doe@gmail.com",
    "last_used": "2025-11-24T10:00:00Z"
  }
}
```

### Get Linked Providers

**Endpoint:** `GET /oauth/providers`

Get list of all linked OAuth providers for current user.

**Response (200 OK):**

```json
{
  "info": "Linked OAuth providers",
  "data": [
    {
      "provider": "google",
      "linked": true,
      "email": "john.doe@gmail.com"
    },
    {
      "provider": "github",
      "linked": false
    }
  ]
}
```

### Refresh OAuth Token

**Endpoint:** `POST /oauth/refresh/:provider`

Refresh OAuth access token for linked provider.

**Parameters:**

- `provider`: OAuth provider name (`google`, `github`)

**Response (200 OK):**

```json
{
  "info": "OAuth token refreshed successfully",
  "data": {
    "provider": "google",
    "refreshed_at": "2025-11-24T10:00:00Z"
  }
}
```

## Two-Factor Authentication Endpoints

### 2FA Setup

**Endpoint:** `live /2fa/setup`

Phoenix LiveView interface for setting up two-factor authentication.

**Features:**

- QR code generation for TOTP apps
- Backup code generation
- Verification process
- Security settings

### 2FA Management

**Endpoint:** `live /2fa`

Phoenix LiveView interface for managing existing 2FA setup.

**Features:**

- View current 2FA status
- Generate new backup codes
- Disable 2FA (with confirmation)
- View 2FA usage history

## User Session Management

### Get Current User Session

**Endpoint:** (Session available in Phoenix LiveView/Controller context)

Access current authenticated user session information.

**Response (Available in conn.assigns.current_user):**

```elixir
%Mcp.Accounts.User{
  id: "user-uuid",
  email: "john.dpose@example.com",
  name: "John Doe",
  status: "active"
}
```

### Session Validation

Phoenix handles session validation automatically through:

- Session cookies with JWT tokens
- Session timeout and expiration
- CSRF protection for form submissions
- User status checks

## API Authentication

### API Key Authentication

For programmatic access, use the `X-API-Key` header.

**Header:** `X-API-Key: YOUR_API_KEY`

**Response (401 Unauthorized):**

```json
{
  "error": {
    "type": "authentication_error",
    "message": "Invalid or missing API key"
  }
}
```

**Response (429 Too Many Requests):**

```json
{
  "error": {
    "type": "rate_limit_exceeded",
    "message": "Rate limit exceeded"
  }
}
```

### JWT Authentication (Future Implementation)

Currently the platform uses Phoenix session-based authentication. JWT token API
authentication is planned for future releases and will be added to `/api/`
routes when implemented.

## Error Handling

### Authentication Errors

**400 Bad Request:**

```json
{
  "error": {
    "type": "authentication_error",
    "message": "Invalid credentials provided"
  }
}
```

**401 Unauthorized:**

```json
{
  "error": {
    "type": "authentication_error",
    "message": "You are not authorized to access this resource"
  }
}
```

**403 Forbidden:**

```json
{
  "error": {
    "type": "authorization_error",
    "message": "You do not have permission to perform this action"
  }
}
```

## LiveView Authentication Helpers

### Current User Access

In Phoenix LiveViews, access current user through `assigns`:

```elixir
defmodule McpWeb.DashboardLive do
  use McpWeb, :live_view

  def mount(_params, session, socket) do
    # Current user is available in assigns.current_user
    {:ok, assign(socket, :current_user, session["current_user"])}
  end
end
```

### Authentication Required

```elixir
defmodule McpWeb.RequireAuth do
  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView
      alias McpWeb.Authentication

      def on_mount(_params, session, socket) do
        case session["current_user"] do
          nil ->
            socket
            |> put_flash(:error, "You must be signed in to access this page.")
            |> push_redirect(to: "/tenant/sign-in")
            {:halt, :stop}
          user ->
            assign(socket, :current_user, user)
        end
      end
    end
  end
end
```

This API reference documentation reflects the actual Phoenix router
implementation and includes all actual authentication endpoints, OAuth
integration, 2FA management, and session management features from the real
codebase.
