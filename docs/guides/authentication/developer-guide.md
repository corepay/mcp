# Authentication Developer Guide

## Implementation Overview

This guide provides detailed technical implementation instructions for the MCP platform's authentication system. It covers code patterns, integration steps, and best practices for developers and LLM agents implementing authentication features.

## Prerequisites

### System Requirements

- **Elixir 1.15+**: Functional programming language
- **Phoenix 1.7+**: Web framework for the application layer
- **PostgreSQL 15+**: Database for user and session storage
- **Redis 7+**: Caching layer for performance optimization
- **Vault**: Secrets management for secure credential storage

### Dependencies

Add these dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    {:phoenix, "~> 1.7.0"},
    {:ash, "~> 2.15"},
    {:ash_postgres, "~> 0.45"},
    {:guardian, "~> 2.3"},
    {:ueberauth, "~> 0.10"},
    {:ueberauth_google, "~> 0.10"},
    {:ueberauth_microsoft, "~> 0.10"},
    {:comeonin, "~> 5.3"},
    {:bcrypt_elixir, "~> 3.0"},
    {:totpex, "~> 1.2"},
    {:webauthx, "~> 0.1"},
    {:bamboo, "~> 2.2"},
    {:swoosh, "~> 1.3"}
  ]
end
```

## Core Implementation

### 1. User Resource Implementation

#### Database Migration

```elixir
# priv/repo/migrations/20251124000001_create_users.exs
defmodule Mcp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string
      add :name, :string
      add :status, :string, default: "pending", null: false
      add :totp_secret, :string
      add :backup_codes, :string_array, default: []
      add :mfa_enabled_at, :utc_datetime_usec
      add :metadata, :jsonb, default: "{}"
      add :tenant_id, :binary_id, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
    create index(:users, [:status])
    create index(:users, [:tenant_id])
    create index(:users, [:mfa_enabled_at])

    # Full-text search index
    execute("CREATE INDEX idx_users_email_fts ON users USING gin(to_tsvector('english', email))")
  end
end
```

#### Ash Resource Definition

```elixir
# lib/mcp/accounts/user.ex
defmodule Mcp.Accounts.User do
  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication, AshJsonApi.Resource]

  postgres do
    table "users"
    repo Mcp.Repo

    custom_indexes do
      index [:email], unique: true
      index [:status]
      index [:tenant_id]
      index [:mfa_enabled_at]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :citext do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      sensitive? true
      allow_nil? true
      writable? false
    end

    attribute :name, :string do
      allow_nil? true
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :active, :suspended, :deleted]
      default :pending
      allow_nil? false
      public? true
    end

    attribute :totp_secret, :string do
      sensitive? true
      allow_nil? true
      writable? false
    end

    attribute :backup_codes, {:array, :string} do
      default []
      allow_nil? false
      sensitive? true
    end

    attribute :mfa_enabled_at, :utc_datetime_usec do
      allow_nil? true
    end

    attribute :metadata, :map do
      default %{}
      allow_nil? false
    end

    attribute :tenant_id, :uuid do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Mcp.Tenants.Tenant do
      allow_nil? false
    end

    has_many :sessions, Mcp.Accounts.Session
    has_many :roles, Mcp.Accounts.UserRole
    has_many :audit_logs, Mcp.Accounts.AuditLog
  end

  actions do
    defaults [:read, :update, :destroy]

    create :register do
      accept [:email, :name, :tenant_id]
      argument :password, :string do
        allow_nil? false
        constraints min_length: 12
      end

      argument :password_confirmation, :string do
        allow_nil? false
      end

      validate match(:password, ~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/),
        message: "must contain at least one lowercase letter, one uppercase letter, one digit, and one special character"

      validate confirm(:password, :password_confirmation)

      change set_attribute(:status, :pending)
      change set_attribute(:hashed_password, &argon2_hash_pwd_salt/1)
    end

    read :by_email do
      argument :email, :citext do
        allow_nil? false
      end

      get_by :email
    end

    update :change_password do
      accept []
      argument :current_password, :string do
        allow_nil? false
      end

      argument :new_password, :string do
        allow_nil? false
        constraints min_length: 12
      end

      argument :new_password_confirmation, :string do
        allow_nil? false
      end

      validate confirm(:new_password, :new_password_confirmation)
      validate matching_current_password(:current_password)

      change set_attribute(:hashed_password, &argon2_hash_pwd_salt/1)
    end

    update :enable_mfa do
      accept [:totp_secret, :backup_codes]
      change set_attribute(:mfa_enabled_at, &DateTime.utc_now/0)
    end

    update :disable_mfa do
      accept []
      change set_attribute(:totp_secret, nil)
      change set_attribute(:backup_codes, [])
      change set_attribute(:mfa_enabled_at, nil)
    end
  end

  code_interface do
    define_for Mcp.Accounts

    def register(email, password, password_confirmation, tenant_id) do
      Mcp.Accounts.User
      |> Ash.Changeset.for_create(:register, %{
        email: email,
        password: password,
        password_confirmation: password_confirmation,
        tenant_id: tenant_id
      })
      |> Ash.create()
    end

    def authenticate(email, password) do
      case Mcp.Accounts.User.by_email(email) do
        {:ok, user} ->
          if Bcrypt.verify_pass(password, user.hashed_password) do
            {:ok, user}
          else
            {:error, :invalid_credentials}
          end
        {:error, _} ->
          # Bypass timing attacks
          Bcrypt.no_user_verify()
          {:error, :invalid_credentials}
      end
    end

    def change_password(user, current_password, new_password, new_password_confirmation) do
      user
      |> Ash.Changeset.for_update(:change_password, %{
        current_password: current_password,
        new_password: new_password,
        new_password_confirmation: new_password_confirmation
      })
      |> Ash.update()
    end
  end

  policies do
    policy always() do
      authorize_if expr(id == ^actor(:user_id))
      authorize_if expr(has_role(:admin))
    end
  end

  defp argon2_hash_pwd_salt(password) do
    Argon2.hash_pwd_salt(password)
  end

  defp matching_current_password(current_password) do
    validate fn changeset, resource ->
      if Bcrypt.verify_pass(current_password, resource.hashed_password) do
        changeset
      else
        Ash.Changeset.add_error(changeset, :current_password, "is incorrect")
      end
    end
  end
end
```

### 2. JWT Token Implementation

```elixir
# lib/mcp/auth/jwt.ex
defmodule Mcp.Auth.JWT do
  @moduledoc """
  JWT token generation and verification for MCP platform authentication.
  """

  use Joken.Config

  @impl true
  def token_config do
    %{
      default_signer: :hs256,
      secret_key: Application.get_env(:mcp, Mcp.Auth.JWT)[:secret_key],
      issuer: "mcp-platform",
      audience: "mcp-users"
    }
  end

  @doc "Generate access token for user"
  def generate_access_token(user, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, :timer.hours(1))

    extra_claims = %{
      "sub" => user.id,
      "email" => user.email,
      "name" => user.name,
      "tenant_id" => user.tenant_id,
      "roles" => get_user_roles(user.id),
      "type" => "access"
    }

    token
    |> Joken.encode(extra_claims)
    |> Joken.with_signer(default_signer())
    |> Joken.with_validation("exp", &(&1 > current_time()))
    |> Joken.with_claim("exp", current_time() + ttl)
    |> Joken.sign()
    |> case Joken.verify_and_validate(token) do
      {:ok, token} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Generate refresh token for user"
  def generate_refresh_token(user, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, :timer.days(30))

    extra_claims = %{
      "sub" => user.id,
      "tenant_id" => user.tenant_id,
      "type" => "refresh"
    }

    token
    |> Joken.encode(extra_claims)
    |> Joken.with_signer(default_signer())
    |> Joken.with_claim("exp", current_time() + ttl)
    |> Joken.sign()
  end

  @doc "Verify and decode JWT token"
  def verify_token(token) do
    token
    |> Joken.decode_and_verify(default_signer())
    |> case Joken.validate(token, token_config()) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Extract user from JWT claims"
  def extract_user_from_claims(claims) do
    case Mcp.Accounts.User.read!(%{
      id: claims["sub"],
      tenant_id: claims["tenant_id"]
    }) do
      {:ok, user} -> {:ok, user}
      {:error, _} = error -> error
    end
  end

  defp current_time do
    DateTime.utc_now() |> DateTime.to_unix()
  end

  defp get_user_roles(user_id) do
    Mcp.Accounts.UserRole
    |> Ash.Query.filter(user_id: user_id)
    |> Ash.Query.load(:role)
    |> Ash.read!()
    |> Enum.map(& &1.role.name)
  end
end
```

### 3. Two-Factor Authentication (2FA)

```elixir
# lib/mcp/auth/totp.ex
defmodule Mcp.Auth.TOTP do
  @moduledoc """
  Time-based One-Time Password (TOTP) implementation for 2FA.
  """

  def generate_totp_secret do
    :crypto.strong_rand_bytes(20) |> Base.encode32()
  end

  def generate_qr_code(user_email, secret) do
    issuer = "MCP Platform"
    account_name = user_email

    otp_uri = "otpauth://totp/#{issuer}:#{account_name}?secret=#{secret}&issuer=#{issuer}"

    QRCode.generate(otp_uri, :png)
  end

  def verify_totp(secret, token) do
    Totpex.verify_totp(secret, token, window: 1)
  end

  def generate_backup_codes do
    for _ <- 1..10 do
      :crypto.strong_rand_bytes(4) |> Base.encode16()
    end
  end

  def validate_backup_codes(backup_codes, provided_code) do
    if provided_code in backup_codes do
      {:ok, List.delete(backup_codes, provided_code)}
    else
      {:error, :invalid_backup_code}
    end
  end
end
```

### 4. OAuth 2.0 Provider Setup

```elixir
# lib/mcp_web/auth/oauth.ex
defmodule McpWeb.Auth.OAuth do
  @moduledoc """
  OAuth 2.0 authentication provider setup and callbacks.
  """

  use Ueberauth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {McpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :oauth do
    plug Ueberauth
  end

  scope "/auth" do
    pipe_through [:browser, :oauth]

    get "/:provider", McpWeb.AuthController, :request
    get "/:provider/callback", McpWeb.AuthController, :callback
  end

  # Ueberauth configuration
  @ueberauth_providers %{
    google: [
      client_id: System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
      strategy: Ueberauth.Strategy.Google,
      default_scope: "email profile"
    ],
    microsoft: [
      client_id: System.get_env("MICROSOFT_CLIENT_ID"),
      client_secret: System.get_env("MICROSOFT_CLIENT_SECRET"),
      strategy: Ueberauth.Strategy.Microsoft,
      default_scope: "email profile openid User.Read"
    ]
  }

  def configure_ueberauth_providers! do
    Enum.each(@ueberauth_providers, fn {provider, config} ->
      if config[:client_id] && config[:client_secret] do
        config :ueberauth, provider, config
      end
    end)
  end
end
```

### 5. Session Management

```elixir
# lib/mcp/accounts/session.ex
defmodule Mcp.Accounts.Session do
  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table "sessions"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :session_token, :string do
      allow_nil? false
      public? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    attribute :ip_address, :string
    attribute :user_agent, :string
    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
    end

    attribute :last_accessed_at, :utc_datetime_usec

    attribute :metadata, :map do
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Mcp.Accounts.User
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:session_token, :user_id, :ip_address, :user_agent, :expires_at, :metadata]
      change set_attribute(:last_accessed_at, &DateTime.utc_now/0)
    end

    update :extend do
      accept []
      argument :ttl_seconds, :integer do
        allow_nil? false
      end
      change set_attribute(:expires_at, fn ->
        DateTime.add(DateTime.utc_now(), Keyword.get(opts, :ttl_seconds), :second)
      end)
    end

    read :active do
      filter expr(expires_at > ^DateTime.utc_now())
    end
  end

  code_interface do
    define_for Mcp.Accounts

    def create_session(user, token, ip_address, user_agent, opts \\ []) do
      ttl = Keyword.get(opts, :ttl, :timer.hours(24))

      Mcp.Accounts.Session
      |> Ash.Changeset.for_create(:create, %{
        session_token: token,
        user_id: user.id,
        ip_address: ip_address,
        user_agent: user_agent,
        expires_at: DateTime.add(DateTime.utc_now(), ttl, :second),
        metadata: %{
          tenant_id: user.tenant_id
        }
      })
      |> Ash.create()
    end

    def validate_session(token) do
      case Mcp.Accounts.Session.active()
           |> Ash.Query.filter(session_token: token)
           |> Ash.Query.filter(expires_at > DateTime.utc_now())
           |> Ash.read_one() do
        {:ok, session} ->
          # Update last accessed time
          session
          |> Ash.Changeset.for_update(:update, %{last_accessed_at: DateTime.utc_now()})
          |> Ash.update()

          {:ok, session}
        {:error, _} ->
          {:error, :session_not_found}
      end
    end

    def revoke_session(token) do
      case Mcp.Accounts.Session.read_one(%{session_token: token}) do
        {:ok, session} -> Ash.destroy(session)
        error -> error
      end
    end

    def revoke_user_sessions(user_id) do
      Mcp.Accounts.Session
      |> Ash.Query.filter(user_id: user_id)
      |> Ash.read!()
      |> Enum.each(&Ash.destroy/1)
    end
  end
end
```

### 6. Authentication Plugs

```elixir
# lib/mcp_web/plugs/auth_plug.ex
defmodule McpWeb.Plugs.AuthPlug do
  @moduledoc """
  Authentication plugs for protecting routes and managing user sessions.
  """

  import Plug.Conn

  def fetch_current_user(conn, _opts) do
    case get_session_token(conn) do
      nil ->
        conn |> assign(:current_user, nil)
      token ->
        case Mcp.Auth.JWT.verify_token(token) do
          {:ok, claims} ->
            case Mcp.Auth.JWT.extract_user_from_claims(claims) do
              {:ok, user} -> conn |> assign(:current_user, user) |> assign(:jwt_claims, claims)
              error ->
                Logger.error("Failed to extract user from JWT: #{inspect(error)}")
                conn |> assign(:current_user, nil)
            end
          {:error, reason} ->
            Logger.error("Invalid JWT token: #{inspect(reason)}")
            conn |> assign(:current_user, nil)
        end
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: %{type: "authentication_required", message: "Authentication required"}})
      |> halt()
    end
  end

  def require_role(conn, opts) do
    required_roles = Keyword.get(opts, :roles, [])
    current_user = conn.assigns[:current_user]

    if current_user && user_has_role?(current_user, required_roles) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: %{type: "insufficient_permissions", message: "Insufficient permissions"}})
      |> halt()
    end
  end

  defp get_session_token(conn) do
    case get_req_header(conn, "authorization") do
      "Bearer " <> token -> token
      _ -> get_session(conn, :access_token)
    end
  end

  defp user_has_role?(user, required_roles) do
    user_roles = get_user_roles(user.id)
    Enum.any?(required_roles, &(&1 in user_roles))
  end

  defp get_user_roles(user_id) do
    # Implement role retrieval logic
    # This would typically query the database or cache
    []
  end
end
```

## Testing Implementation

### Unit Tests

```elixir
# test/mcp/accounts/user_test.exs
defmodule Mcp.Accounts.UserTest do
  use ExUnit.Case, async: true

  alias Mcp.Accounts.User

  describe "user registration" do
    test "creates user with valid attributes" do
      tenant = insert(:tenant)
      attrs = %{
        email: "test@example.com",
        password: "SecurePassword123!",
        password_confirmation: "SecurePassword123!",
        tenant_id: tenant.id
      }

      assert {:ok, user} = User.register(attrs.email, attrs.password, attrs.password_confirmation, attrs.tenant_id)
      assert user.email == attrs.email
      assert user.status == :pending
    end

    test "rejects weak passwords" do
      tenant = insert(:tenant)
      attrs = %{
        email: "test@example.com",
        password: "weak",
        password_confirmation: "weak",
        tenant_id: tenant.id
      }

      assert {:error, changeset} = User.register(attrs.email, attrs.password, attrs.password_confirmation, attrs.tenant_id)
      assert changeset.errors[:password]
    end
  end

  describe "user authentication" do
    test "authenticates user with valid credentials" do
      user = insert(:user, hashed_password: Bcrypt.hash_pwd_salt("SecurePassword123!"))

      assert {:ok, authenticated_user} = User.authenticate(user.email, "SecurePassword123!")
      assert authenticated_user.id == user.id
    end

    test "rejects invalid credentials" do
      assert {:error, :invalid_credentials} = User.authenticate("nonexistent@example.com", "password")
    end
  end
end
```

### Integration Tests

```elixir
# test/mcp_web/auth_controller_test.exs
defmodule McpWeb.AuthControllerTest do
  use McpWeb.ConnCase

  describe "POST /auth/register" do
    test "creates new user account", %{conn: conn} do
      tenant = insert(:tenant)

      attrs = %{
        "user" => %{
          "email" => "newuser@example.com",
          "password" => "SecurePassword123!",
          "password_confirmation" => "SecurePassword123!",
          "tenant_id" => tenant.id
        }
      }

      conn = post(conn, "/sign_in", attrs)

      assert %{"status" => "success"} = json_response(conn, 201)
    end
  end

  describe "POST /auth/login" do
    test "authenticates user and returns tokens", %{conn: conn} do
      user = insert(:user, hashed_password: Bcrypt.hash_pwd_salt("SecurePassword123!"))

      attrs = %{
        "auth" => %{
          "email" => user.email,
          "password" => "SecurePassword123!"
        }
      }

      conn = post(conn, "/sign_in", attrs)

      response = json_response(conn, 200)
      assert %{"status" => "success"} = response
      assert %{"access_token" => access_token} = response["data"]["tokens"]
      assert is_binary(access_token)
    end
  end
end
```

## Security Best Practices

### 1. Password Security

```elixir
# Strong password requirements
def validate_password_strength(password) do
  requirements = [
    {String.length(password) >= 12, "Password must be at least 12 characters"},
    {Regex.match?(~r/[A-Z]/, password), "Password must contain uppercase letter"},
    {Regex.match?(~r/[a-z]/, password), "Password must contain lowercase letter"},
    {Regex.match?(~r/[0-9]/, password), "Password must contain number"},
    {Regex.match?(~r/[!@#$%^&*(),.?":{}|<>]/, password), "Password must contain special character"}
  ]

  case Enum.find(requirements, fn {valid?, _} -> not valid? end) do
    nil -> :ok
    {_, error_message} -> {:error, error_message}
  end
end
```

### 2. Rate Limiting

```elixir
# lib/mcp/auth/rate_limiter.ex
defmodule Mcp.Auth.RateLimiter do
  def check_login_attempts(ip_address, email) do
    key = "login_attempts:#{ip_address}:#{email}"

    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} ->
        Redix.command(:redix, ["SETEX", key, "1", "300", "1"]) # 1 attempt in 5 minutes
        :ok
      {:ok, attempts} ->
        attempts = String.to_integer(attempts)
        if attempts >= 5 do
          {:error, :rate_limited}
        else
          Redix.command(:redix, ["INCR", key])
          :ok
        end
    end
  end

  def reset_login_attempts(ip_address, email) do
    key = "login_attempts:#{ip_address}:#{email}"
    Redix.command(:redix, ["DEL", key])
  end
end
```

### 3. Audit Logging

```elixir
# lib/mcp/accounts/audit_log.ex
defmodule Mcp.Accounts.AuditLog do
  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :user_id, :uuid
    attribute :action, :string
    attribute :resource_type, :string
    attribute :resource_id, :string
    attribute :ip_address, :string
    attribute :user_agent, :string
    attribute :metadata, :map
    attribute :timestamp, :utc_datetime_usec

    timestamps()
  end

  def log_authentication_event(user_id, action, metadata \\ %{}) do
    %__MODULE__{}
    |> Ecto.Changeset.change(%{
      user_id: user_id,
      action: action,
      resource_type: "authentication",
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent],
      metadata: metadata,
      timestamp: DateTime.utc_now()
    })
    |> Mcp.Repo.insert()
  end
end
```

## Configuration

### Application Configuration

```elixir
# config/config.exs
config :mcp, Mcp.Auth.JWT,
  secret_key: System.get_env("JWT_SECRET_KEY") || "your-secret-key-here"

config :mcp, McpWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# OAuth providers
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

config :ueberauth, Ueberauth.Strategy.Microsoft.OAuth,
  client_id: System.get_env("MICROSOFT_CLIENT_ID"),
  client_secret: System.get_env("MICROSOFT_CLIENT_SECRET")
```

### Environment Variables

```bash
# Authentication secrets
JWT_SECRET_KEY=your-super-secret-jwt-key
SECRET_KEY_BASE=your-secret-key-base

# OAuth providers
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
MICROSOFT_CLIENT_ID=your-microsoft-client-id
MICROSOFT_CLIENT_SECRET=your-microsoft-client-secret

# Security
BCRYPT_LOG_ROUNDS=12
SESSION_TIMEOUT_HOURS=24
MAX_LOGIN_ATTEMPTS=5
```

This developer guide provides comprehensive technical implementation details for the authentication system, including code examples, security best practices, testing strategies, and configuration instructions.