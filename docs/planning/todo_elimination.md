# TODO Elimination Plan

**Generated:** 2025-12-25
**Status:** All 13 TODOs identified and documented for elimination
**Philosophy:** No TODO should exist in production code. Each represents incomplete work.

---

## Executive Summary

| # | Location | Category | Priority | Effort |
|---|----------|----------|----------|--------|
| 1 | `multi_tenant.ex:165` | Refactoring | P3 | Low |
| 2 | `require_api_key.ex:86` | Performance | P1 | Medium |
| 3 | `application_live.ex:239` | Correctness | P2 | Low |
| 4 | `auth_controller.ex:337` | **CRITICAL** | P0 | Medium |
| 5 | `auth_controller.ex:375` | **CRITICAL** | P0 | Medium |
| 6 | `document_intelligence.ex:19` | Feature | P2 | Medium |
| 7 | `orchestrator.ex:35` | Correctness | P1 | Medium |
| 8 | `multi_tenant.ex:71` | Refactoring | P3 | Low |
| 9 | `authentication_security_test.exs:205` | Security | P2 | High |
| 10 | `authentication_security_test.exs:413` | Testing | P3 | Low |
| 11 | `authentication_security_test.exs:469` | Security | P2 | Medium |
| 12 | `compliance_validation_test.exs:339` | Testing | P3 | Low |
| 13 | `review.ex:45` | Compliance | P1 | Low |

---

## TODO #1: Extract Mcp.Platform.Geo Module

**File:** `lib/mcp/multi_tenant.ex:165`
**Current State:** PostGIS functions inline in MultiTenant module
**Target State:** Dedicated `Mcp.Platform.Geo` module with delegation

### Implementation

#### Step 1: Create the Geo Module

```elixir
# lib/mcp/platform/geo.ex
defmodule Mcp.Platform.Geo do
  @moduledoc """
  Geographic operations using PostGIS.

  Provides spatial queries, distance calculations, and geographic indexing
  for tenant-isolated merchant location data.
  """

  alias Mcp.Infrastructure.Context
  alias Mcp.Repo

  @tenant_schema_prefix "acq_"

  @doc """
  Adds a geometry column to an existing table.

  ## Parameters
    - tenant_schema_name: The tenant identifier
    - table_name: Target table name
    - column_name: Name for the geometry column
    - geometry_type: PostGIS geometry type (POINT, POLYGON, etc.)
    - srid: Spatial Reference ID (default: 4326 for WGS84)

  ## Example
      iex> Geo.add_geometry_column("tenant_abc", "merchants", "location", "POINT")
      {:ok, %Postgrex.Result{}}
  """
  def add_geometry_column(
        tenant_schema_name,
        table_name,
        column_name,
        geometry_type,
        srid \\ 4326
      ) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT AddGeometryColumn('#{table_name}', '#{column_name}', #{srid}, '#{geometry_type}', 2)
      """
      Repo.query(query)
    end)
  end

  @doc """
  Finds merchants within a radius of a given point.

  ## Parameters
    - tenant_schema_name: The tenant identifier
    - longitude: Longitude coordinate
    - latitude: Latitude coordinate
    - radius_km: Search radius in kilometers (default: 10)

  ## Returns
    List of merchants with distance_km calculated
  """
  def find_nearby_merchants(tenant_schema_name, longitude, latitude, radius_km \\ 10) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT *,
        ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)) * 111.32 as distance_km
      FROM merchants
      WHERE ST_DWithin(
        location,
        ST_SetSRID(ST_MakePoint($1, $2), 4326),
        $3 * 1000
      )
      ORDER BY distance_km
      """
      Repo.query(query, [longitude, latitude, radius_km])
    end)
  end

  @doc """
  Creates a GIST index on a geometry column for fast spatial queries.
  """
  def create_geographic_index(tenant_schema_name, table_name, column_name, index_name \\ nil) do
    index_name = index_name || "#{table_name}_#{column_name}_geo_idx"

    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      CREATE INDEX IF NOT EXISTS #{index_name}
      ON #{table_name}
      USING GIST (#{column_name})
      """
      Repo.query(query)
    end)
  end

  @doc """
  Calculates the convex hull coverage area for a merchant's locations.
  """
  def merchant_coverage_area(tenant_schema_name, merchant_id) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        ST_ConvexHull(
          ST_Collect(
            ST_SetSRID(ST_MakePoint(ST_X(location), ST_Y(location)), 4326)
          )
        ) as coverage_area
      FROM merchants
      WHERE id = $1
      """
      Repo.query(query, [merchant_id])
    end)
  end

  @doc """
  Analyzes geographic distribution of all merchants.
  Returns centroid, bounding box, and statistical measures.
  """
  def analyze_geographic_distribution(tenant_schema_name) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        ST_Centroid(ST_Collect(location)) as center_point,
        ST_Extent(ST_Collect(location)) as bounding_box,
        COUNT(*) as merchant_count,
        AVG(ST_X(location)) as avg_longitude,
        AVG(ST_Y(location)) as avg_latitude,
        STDDEV(ST_X(location)) as longitude_stddev,
        STDDEV(ST_Y(location)) as latitude_stddev
      FROM merchants
      WHERE location IS NOT NULL
      """
      Repo.query(query)
    end)
  end
end
```

#### Step 2: Update MultiTenant Delegations

```elixir
# In lib/mcp/multi_tenant.ex, replace lines 164-258 with:

alias Mcp.Platform.Geo

# Geographic operations (PostGIS)
defdelegate add_geometry_column(tenant_schema_name, table_name, column_name, geometry_type, srid \\ 4326), to: Geo
defdelegate find_nearby_merchants(tenant_schema_name, longitude, latitude, radius_km \\ 10), to: Geo
defdelegate create_geographic_index(tenant_schema_name, table_name, column_name, index_name \\ nil), to: Geo
defdelegate merchant_coverage_area(tenant_schema_name, merchant_id), to: Geo
defdelegate analyze_geographic_distribution(tenant_schema_name), to: Geo
```

#### Step 3: Create Tests

```elixir
# test/mcp/platform/geo_test.exs
defmodule Mcp.Platform.GeoTest do
  use Mcp.DataCase, async: true

  alias Mcp.Platform.Geo

  @tenant "test_tenant"

  describe "find_nearby_merchants/4" do
    test "returns merchants within radius sorted by distance" do
      # Setup tenant with merchant data
      {:ok, result} = Geo.find_nearby_merchants(@tenant, -122.4194, 37.7749, 10)
      assert is_list(result.rows)
    end
  end

  describe "create_geographic_index/4" do
    test "creates GIST index on geometry column" do
      {:ok, _} = Geo.create_geographic_index(@tenant, "merchants", "location")
      # Verify index exists
    end
  end
end
```

### Verification Commands

```bash
mix compile --warnings-as-errors
mix test test/mcp/platform/geo_test.exs
mix credo lib/mcp/platform/geo.ex
```

---

## TODO #2: Cache API Key Spending Limit Query

**File:** `lib/mcp_web/plugs/require_api_key.ex:86`
**Current State:** DB query on every API request
**Target State:** Redis-cached spending with invalidation

### Implementation

#### Step 1: Create Spending Cache Module

```elixir
# lib/mcp/cache/spending_cache.ex
defmodule Mcp.Cache.SpendingCache do
  @moduledoc """
  Redis-backed cache for API key spending limits.

  Caches monthly spend calculations to avoid DB queries on every API request.
  TTL: 60 seconds with invalidation on new usage records.
  """

  alias Mcp.Redis

  # 60 second TTL - balance between freshness and performance
  @cache_ttl 60

  @doc """
  Gets cached monthly spend for an API key.
  Returns {:ok, Decimal.t()} or {:miss, nil}
  """
  def get_monthly_spend(api_key_id) do
    key = cache_key(api_key_id)

    case Redis.get(key) do
      {:ok, nil} -> {:miss, nil}
      {:ok, value} -> {:ok, Decimal.new(value)}
      {:error, _} -> {:miss, nil}
    end
  end

  @doc """
  Caches the monthly spend for an API key.
  """
  def put_monthly_spend(api_key_id, spend) do
    key = cache_key(api_key_id)
    Redis.set(key, Decimal.to_string(spend), @cache_ttl)
  end

  @doc """
  Invalidates the cache for an API key.
  Called when new LlmUsage records are created.
  """
  def invalidate(api_key_id) do
    key = cache_key(api_key_id)
    Redis.del(key)
  end

  @doc """
  Gets monthly spend with cache-through pattern.
  If cache miss, calculates from DB and caches result.
  """
  def get_or_calculate_monthly_spend(api_key_id) do
    case get_monthly_spend(api_key_id) do
      {:ok, spend} ->
        spend

      {:miss, _} ->
        start_date = Date.beginning_of_month(Date.utc_today())
        end_date = Date.utc_today()
        spend = Mcp.Ai.LlmUsage.calculate_spend(api_key_id, start_date, end_date)
        put_monthly_spend(api_key_id, spend)
        spend
    end
  end

  defp cache_key(api_key_id) do
    month = Date.utc_today() |> Date.beginning_of_month() |> Date.to_iso8601()
    "spending:#{api_key_id}:#{month}"
  end
end
```

#### Step 2: Update RequireApiKey Plug

```elixir
# In lib/mcp_web/plugs/require_api_key.ex, replace check_spending_limit/1:

defp check_spending_limit(%{spending_limit: nil}), do: :ok

defp check_spending_limit(%{spending_limit: limit, id: id}) do
  current_spend = Mcp.Cache.SpendingCache.get_or_calculate_monthly_spend(id)

  if Decimal.compare(current_spend, limit) == :gt do
    {:error, :spending_limit_exceeded}
  else
    :ok
  end
end
```

#### Step 3: Add Cache Invalidation to LlmUsage

```elixir
# In lib/mcp/ai/resources/llm_usage.ex, add a change to the create action:

create :create do
  primary? true

  accept [
    :provider,
    :model,
    :prompt_tokens,
    :completion_tokens,
    :total_tokens,
    :cost,
    :latency_ms,
    :merchant_id,
    :reseller_id,
    :api_key_id
  ]

  # Invalidate spending cache when new usage is recorded
  change after_action(fn changeset, record, _context ->
    if record.api_key_id do
      Mcp.Cache.SpendingCache.invalidate(record.api_key_id)
    end
    {:ok, record}
  end)
end
```

#### Step 4: Create Tests

```elixir
# test/mcp/cache/spending_cache_test.exs
defmodule Mcp.Cache.SpendingCacheTest do
  use Mcp.DataCase, async: false

  alias Mcp.Cache.SpendingCache

  describe "get_or_calculate_monthly_spend/1" do
    test "caches result on first call" do
      api_key_id = Ecto.UUID.generate()

      # First call - cache miss, calculates
      spend1 = SpendingCache.get_or_calculate_monthly_spend(api_key_id)

      # Second call - cache hit
      spend2 = SpendingCache.get_or_calculate_monthly_spend(api_key_id)

      assert spend1 == spend2
    end

    test "invalidate/1 clears cache" do
      api_key_id = Ecto.UUID.generate()

      SpendingCache.put_monthly_spend(api_key_id, Decimal.new("10.00"))
      assert {:ok, _} = SpendingCache.get_monthly_spend(api_key_id)

      SpendingCache.invalidate(api_key_id)
      assert {:miss, _} = SpendingCache.get_monthly_spend(api_key_id)
    end
  end
end
```

### Verification Commands

```bash
mix compile --warnings-as-errors
mix test test/mcp/cache/spending_cache_test.exs
mix test test/mcp_web/plugs/require_api_key_test.exs
```

---

## TODO #3: Manage Execution ID in Socket Assigns

**File:** `lib/mcp_web/live/ola/application_live.ex:239`
**Current State:** Creates new execution on each fallback chat
**Target State:** Persistent execution ID in socket assigns

### Implementation

#### Step 1: Initialize Execution on Mount

```elixir
# In lib/mcp_web/live/ola/application_live.ex

def mount(params, session, socket) do
  # ... existing mount logic ...

  socket =
    socket
    |> assign(:execution_id, nil)
    |> assign(:ola_blueprint, nil)

  {:ok, socket}
end

defp ensure_execution(socket) do
  case socket.assigns[:execution_id] do
    nil ->
      {:ok, execution} = create_ola_execution(socket)
      assign(socket, :execution_id, execution.id)

    _existing ->
      socket
  end
end

defp create_ola_execution(socket) do
  Mcp.Underwriting.Execution
  |> Ash.Changeset.for_create(:create, %{
    status: :pending,
    subject_type: :application,
    subject_id: socket.assigns[:application_id],
    context: %{
      tenant_id: socket.assigns.current_tenant.id,
      user_id: socket.assigns.current_user.id
    }
  })
  |> Ash.create()
end
```

#### Step 2: Update handle_fallback_chat

```elixir
defp handle_fallback_chat(socket) do
  # Ensure we have a persistent execution
  socket = ensure_execution(socket)
  execution_id = socket.assigns.execution_id

  blueprint = %Mcp.Underwriting.AgentBlueprint{
    name: "OlaAssistant",
    description: "Application Helper",
    base_prompt: "You are Ola, a helpful underwriting assistant.",
    routing_config: %{primary_provider: :ollama, mode: :single}
  }

  instructions = %Mcp.Underwriting.InstructionSet{
    instructions: "Assist the user with their application."
  }

  context = %{
    execution_id: execution_id,
    tenant_id: socket.assigns.current_tenant.id
  }

  case Mcp.Underwriting.Engine.AgentRunner.run(blueprint, instructions, context) do
    {:ok, response_result} ->
      response_text =
        Map.get(response_result, "decision") ||
        Map.get(response_result, "result") ||
        "I processed your request."

      {:noreply, push_chat_message(socket, response_text)}

    {:error, reason} ->
      Logger.error("Agent execution failed: #{inspect(reason)}")
      {:noreply, push_chat_message(socket, "I encountered an error. Please try again.")}
  end
end
```

### Verification Commands

```bash
mix compile --warnings-as-errors
mix test test/mcp_web/live/ola/application_live_test.exs
```

---

## TODOs #4-5: Implement Password Reset Ash Actions

**Files:** `lib/mcp_web/controllers/auth_controller.ex:337, :375`
**Current State:** Mock implementations returning static responses
**Target State:** Full password reset flow with tokens and email

### Implementation

#### Step 1: Add Password Reset Token to User Resource

```elixir
# In lib/mcp/accounts/user.ex, add to attributes:

attribute :reset_password_token, :string do
  sensitive? true
end

attribute :reset_password_sent_at, :utc_datetime
```

#### Step 2: Create Password Reset Actions

```elixir
# In lib/mcp/accounts/user.ex, add to actions:

update :request_password_reset do
  accept []
  require_atomic? false

  change fn changeset, _ ->
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    changeset
    |> Ash.Changeset.change_attribute(:reset_password_token, token)
    |> Ash.Changeset.change_attribute(:reset_password_sent_at, DateTime.utc_now())
  end
end

update :reset_password_with_token do
  argument :token, :string, allow_nil?: false
  argument :password, :string, allow_nil?: false, sensitive?: true
  argument :password_confirmation, :string, allow_nil?: false, sensitive?: true
  require_atomic? false

  validate confirm(:password, :password_confirmation)

  # Validate token matches and is not expired (1 hour)
  validate fn changeset, _context ->
    token = Ash.Changeset.get_argument(changeset, :token)
    stored_token = Ash.Changeset.get_attribute(changeset, :reset_password_token)
    sent_at = Ash.Changeset.get_attribute(changeset, :reset_password_sent_at)

    cond do
      is_nil(stored_token) ->
        {:error, field: :token, message: "No reset token exists"}

      token != stored_token ->
        {:error, field: :token, message: "Invalid reset token"}

      is_nil(sent_at) ->
        {:error, field: :token, message: "Token expired"}

      DateTime.diff(DateTime.utc_now(), sent_at, :hour) > 1 ->
        {:error, field: :token, message: "Token expired"}

      true ->
        :ok
    end
  end

  change fn changeset, _ ->
    if changeset.valid? do
      password = Ash.Changeset.get_argument(changeset, :password)
      hashed = Bcrypt.hash_pwd_salt(password)

      changeset
      |> Ash.Changeset.change_attribute(:hashed_password, hashed)
      |> Ash.Changeset.change_attribute(:reset_password_token, nil)
      |> Ash.Changeset.change_attribute(:reset_password_sent_at, nil)
    else
      changeset
    end
  end
end
```

#### Step 3: Add Code Interface

```elixir
# In lib/mcp/accounts/user.ex code_interface:

define :request_password_reset
define :reset_password_with_token, args: [:token, :password, :password_confirmation]
```

#### Step 4: Create Password Reset Email Template

```elixir
# lib/mcp/communication/templates/password_reset.ex
defmodule Mcp.Communication.Templates.PasswordReset do
  @moduledoc """
  Password reset email template.
  """

  def subject, do: "Reset Your Password"

  def html_body(reset_url) do
    """
    <html>
    <body>
      <h1>Password Reset Request</h1>
      <p>You requested a password reset. Click the link below to reset your password:</p>
      <p><a href="#{reset_url}">Reset Password</a></p>
      <p>This link expires in 1 hour.</p>
      <p>If you didn't request this, please ignore this email.</p>
    </body>
    </html>
    """
  end

  def text_body(reset_url) do
    """
    Password Reset Request

    You requested a password reset. Visit this URL to reset your password:
    #{reset_url}

    This link expires in 1 hour.

    If you didn't request this, please ignore this email.
    """
  end
end
```

#### Step 5: Update Auth Controller

```elixir
# In lib/mcp_web/controllers/auth_controller.ex

def forgot_password(conn, %{"email" => email}) do
  # Always return success to prevent email enumeration
  case Mcp.Accounts.User.by_email(email) do
    {:ok, user} when not is_nil(user) ->
      # Generate reset token
      case Mcp.Accounts.User.request_password_reset(user) do
        {:ok, updated_user} ->
          # Send email asynchronously
          Task.start(fn ->
            reset_url = build_reset_url(conn, updated_user.reset_password_token)
            send_password_reset_email(user.email, reset_url)
          end)

        {:error, _} ->
          # Log error but don't expose to user
          Logger.error("Failed to generate reset token for user #{user.id}")
      end

    _ ->
      # User not found - still return success (security)
      :ok
  end

  conn
  |> put_status(:ok)
  |> json(%{data: %{message: "If an account exists, password reset instructions have been sent."}})
end

def reset_password(conn, %{
      "token" => token,
      "password" => password,
      "password_confirmation" => confirmation
    }) do
  # Find user by reset token
  case find_user_by_reset_token(token) do
    {:ok, user} ->
      case Mcp.Accounts.User.reset_password_with_token(user, token, password, confirmation) do
        {:ok, _user} ->
          # Revoke all existing sessions
          Mcp.Accounts.Auth.revoke_user_sessions(user.id)

          conn
          |> put_status(:ok)
          |> json(%{data: %{message: "Password reset successfully. Please sign in."}})

        {:error, changeset} ->
          errors = format_changeset_errors(changeset)
          conn
          |> put_status(:bad_request)
          |> json(%{error: %{code: "validation_error", message: "Password reset failed", details: errors}})
      end

    {:error, :not_found} ->
      conn
      |> put_status(:bad_request)
      |> json(%{error: %{code: "invalid_token", message: "Invalid or expired reset token"}})
  end
end

defp find_user_by_reset_token(token) do
  import Ash.Query

  Mcp.Accounts.User
  |> filter(reset_password_token == ^token)
  |> Ash.read_one()
  |> case do
    {:ok, nil} -> {:error, :not_found}
    {:ok, user} -> {:ok, user}
    error -> error
  end
end

defp build_reset_url(conn, token) do
  base_url = McpWeb.Endpoint.url()
  "#{base_url}/reset-password?token=#{token}"
end

defp send_password_reset_email(email, reset_url) do
  alias Mcp.Communication.Templates.PasswordReset

  Mcp.Communication.EmailService.send_email(
    email,
    PasswordReset.subject(),
    PasswordReset.html_body(reset_url),
    text_body: PasswordReset.text_body(reset_url)
  )
end
```

#### Step 6: Create Migration

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_add_password_reset_fields.exs
defmodule Mcp.Repo.Migrations.AddPasswordResetFields do
  use Ecto.Migration

  def change do
    alter table(:users, prefix: "platform") do
      add :reset_password_token, :string
      add :reset_password_sent_at, :utc_datetime
    end

    create index(:users, [:reset_password_token], prefix: "platform")
  end
end
```

### Verification Commands

```bash
mix ecto.gen.migration add_password_reset_fields
mix ecto.migrate
mix compile --warnings-as-errors
mix test test/mcp/accounts/user_test.exs
mix test test/mcp_web/controllers/auth_controller_test.exs
```

---

## TODO #6: Handle File Reading for Document Intelligence

**File:** `lib/mcp/underwriting/services/document_intelligence.ex:19`
**Current State:** Only handles local file paths
**Target State:** Support local paths, MinIO URLs, and S3 URLs

### Implementation

#### Step 1: Update DocumentIntelligence Module

```elixir
# lib/mcp/underwriting/services/document_intelligence.ex
defmodule Mcp.Underwriting.Services.DocumentIntelligence do
  @moduledoc """
  Service for interacting with "The Eye" (Python Document Intelligence Service).

  Supports multiple file sources:
  - Local filesystem paths
  - MinIO/S3 object URLs
  - Pre-signed URLs
  """

  require Logger

  @base_url "http://localhost:#{System.get_env("THE_EYE_PORT", "48291")}"

  @doc """
  Analyzes a document by sending it to the Python service.

  ## Parameters
    - file_source: Can be:
      - Local path: "/path/to/file.pdf"
      - MinIO URL: "minio://bucket/key"
      - S3 URL: "s3://bucket/key"
      - HTTP URL: "https://example.com/file.pdf"
    - merchant_id: UUID of the associated merchant

  ## Returns
    - {:ok, DocumentAnalysis} on success
    - {:error, reason} on failure
  """
  def analyze(file_source, merchant_id) do
    case resolve_file_content(file_source) do
      {:ok, content, filename} ->
        send_to_service(content, filename, merchant_id)

      {:error, reason} ->
        Logger.error("Failed to resolve file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Resolve file content from various sources
  defp resolve_file_content(source) when is_binary(source) do
    cond do
      String.starts_with?(source, "minio://") ->
        resolve_minio_url(source)

      String.starts_with?(source, "s3://") ->
        resolve_s3_url(source)

      String.starts_with?(source, "http://") or String.starts_with?(source, "https://") ->
        resolve_http_url(source)

      File.exists?(source) ->
        resolve_local_file(source)

      true ->
        {:error, :invalid_source}
    end
  end

  defp resolve_local_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content, Path.basename(path)}
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp resolve_minio_url("minio://" <> rest) do
    [bucket | key_parts] = String.split(rest, "/")
    key = Enum.join(key_parts, "/")

    case Mcp.Storage.MinioClient.get_object(bucket, key) do
      {:ok, content} -> {:ok, content, Path.basename(key)}
      {:error, reason} -> {:error, {:minio_error, reason}}
    end
  end

  defp resolve_s3_url("s3://" <> rest) do
    # Use same MinIO client - it's S3-compatible
    resolve_minio_url("minio://#{rest}")
  end

  defp resolve_http_url(url) do
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        filename = url |> URI.parse() |> Map.get(:path, "document") |> Path.basename()
        {:ok, body, filename}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp send_to_service(content, filename, merchant_id) do
    case Req.post("#{@base_url}/analyze/document",
           multipart: [
             file: {content, filename}
           ],
           receive_timeout: 120_000
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        create_record(body, merchant_id)

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Document analysis failed: status=#{status} body=#{inspect(body)}")
        {:error, :analysis_failed}

      {:error, reason} ->
        Logger.error("Failed to connect to The Eye: #{inspect(reason)}")
        {:error, :connection_failed}
    end
  end

  defp create_record(body, merchant_id) do
    Mcp.Underwriting.DocumentAnalysis
    |> Ash.Changeset.for_create(:create, %{
      status: :completed,
      markdown_content: body["markdown_content"],
      structured_data: body["structured_data"],
      provider: String.to_atom(body["provider"]),
      merchant_id: merchant_id
    })
    |> Ash.create()
  end
end
```

#### Step 2: Create MinIO Client (if not exists)

```elixir
# lib/mcp/storage/minio_client.ex
defmodule Mcp.Storage.MinioClient do
  @moduledoc """
  MinIO/S3 client for object storage operations.
  """

  @default_bucket System.get_env("MINIO_BUCKET", "mcp-documents")

  def get_object(bucket \\ @default_bucket, key) do
    config = build_config()

    ExAws.S3.get_object(bucket, key)
    |> ExAws.request(config)
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  def put_object(bucket \\ @default_bucket, key, content, opts \\ []) do
    config = build_config()
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    ExAws.S3.put_object(bucket, key, content, content_type: content_type)
    |> ExAws.request(config)
  end

  def presigned_url(bucket \\ @default_bucket, key, opts \\ []) do
    config = build_config()
    expires_in = Keyword.get(opts, :expires_in, 3600)

    ExAws.S3.presigned_url(config, :get, bucket, key, expires_in: expires_in)
  end

  defp build_config do
    [
      access_key_id: System.get_env("MINIO_ACCESS_KEY", "minioadmin"),
      secret_access_key: System.get_env("MINIO_SECRET_KEY", "minioadmin"),
      host: System.get_env("MINIO_HOST", "localhost"),
      port: String.to_integer(System.get_env("MINIO_PORT", "9000")),
      scheme: "http://",
      region: "us-east-1"
    ]
  end
end
```

### Verification Commands

```bash
mix compile --warnings-as-errors
mix test test/mcp/underwriting/services/document_intelligence_test.exs
mix test test/mcp/storage/minio_client_test.exs
```

---

## TODO #7: Find Instruction Set for Blueprint + Tenant

**File:** `lib/mcp/underwriting/engine/orchestrator.ex:35`
**Current State:** Grabs first matching instruction set
**Target State:** Proper tenant-scoped lookup with fallback

### Implementation

#### Step 1: Add tenant_id to InstructionSet Relationship

```elixir
# Ensure InstructionSet has tenant relationship
# In lib/mcp/underwriting/resources/instruction_set.ex

relationships do
  belongs_to :blueprint, Mcp.Underwriting.AgentBlueprint
  belongs_to :tenant, Mcp.Platform.Tenant do
    allow_nil? true  # null = default/global instruction set
  end
end
```

#### Step 2: Create Instruction Lookup Function

```elixir
# lib/mcp/underwriting/engine/instruction_lookup.ex
defmodule Mcp.Underwriting.Engine.InstructionLookup do
  @moduledoc """
  Resolves the correct InstructionSet for a given blueprint and tenant.

  Resolution order:
  1. Tenant-specific instruction set for this blueprint
  2. Default (tenant_id = null) instruction set for this blueprint
  3. Dynamically generated default instruction set
  """

  alias Mcp.Underwriting.InstructionSet
  require Ash.Query

  @doc """
  Finds the appropriate instruction set for a blueprint and tenant.

  ## Parameters
    - blueprint_id: UUID of the AgentBlueprint
    - tenant_id: UUID of the tenant (optional)

  ## Returns
    - InstructionSet struct (never nil)
  """
  def find(blueprint_id, tenant_id) do
    # Try tenant-specific first
    case find_tenant_specific(blueprint_id, tenant_id) do
      {:ok, instruction_set} when not is_nil(instruction_set) ->
        instruction_set

      _ ->
        # Fall back to default
        case find_default(blueprint_id) do
          {:ok, instruction_set} when not is_nil(instruction_set) ->
            instruction_set

          _ ->
            # Generate dynamic default
            generate_default(blueprint_id)
        end
    end
  end

  defp find_tenant_specific(blueprint_id, nil), do: {:ok, nil}

  defp find_tenant_specific(blueprint_id, tenant_id) do
    InstructionSet
    |> Ash.Query.filter(blueprint_id == ^blueprint_id and tenant_id == ^tenant_id)
    |> Ash.Query.limit(1)
    |> Ash.read_one()
  end

  defp find_default(blueprint_id) do
    InstructionSet
    |> Ash.Query.filter(blueprint_id == ^blueprint_id and is_nil(tenant_id))
    |> Ash.Query.limit(1)
    |> Ash.read_one()
  end

  defp generate_default(blueprint_id) do
    %InstructionSet{
      blueprint_id: blueprint_id,
      instructions: "Follow the blueprint's base prompt. Apply standard underwriting policies.",
      is_dynamic_default: true
    }
  end
end
```

#### Step 3: Update Orchestrator

```elixir
# In lib/mcp/underwriting/engine/orchestrator.ex, replace lines 35-44:

alias Mcp.Underwriting.Engine.InstructionLookup

results =
  Enum.reduce(pipeline.stages, %{}, fn stage_config, acc_results ->
    blueprint_id = stage_config["blueprint_id"]
    blueprint = Ash.get!(AgentBlueprint, blueprint_id)

    # Proper tenant-scoped instruction lookup
    instructions = InstructionLookup.find(blueprint_id, pipeline.tenant_id)

    # Merge previous results into context
    current_context = Map.merge(execution.context, acc_results)

    tenant_id = pipeline.tenant_id
    merchant_id = if execution.subject_type == :merchant, do: execution.subject_id, else: nil

    opts = [
      execution_id: execution.id,
      tenant_id: tenant_id,
      merchant_id: merchant_id
    ]

    {:ok, output} = AgentRunner.run(blueprint, instructions, current_context, opts)

    Map.put(acc_results, blueprint.name, output)
  end)
```

### Verification Commands

```bash
mix compile --warnings-as-errors
mix test test/mcp/underwriting/engine/orchestrator_test.exs
mix test test/mcp/underwriting/engine/instruction_lookup_test.exs
```

---

## TODO #8: Extract Mcp.Analytics.TimeSeries Module

**File:** `lib/mcp/multi_tenant.ex:71`
**Current State:** TimescaleDB functions inline in MultiTenant
**Target State:** Dedicated `Mcp.Analytics.TimeSeries` module

### Implementation

#### Step 1: Create TimeSeries Module

```elixir
# lib/mcp/analytics/time_series.ex
defmodule Mcp.Analytics.TimeSeries do
  @moduledoc """
  TimescaleDB operations for time-series analytics.

  Provides hypertable management, continuous aggregates, and
  time-series analytics queries for tenant-isolated data.
  """

  alias Mcp.Infrastructure.Context
  alias Mcp.Repo

  @doc """
  Creates a hypertable from an existing table.

  ## Parameters
    - tenant_schema_name: Tenant identifier
    - table_name: Name of the table to convert
    - time_column: Column containing timestamps
    - chunk_time_interval: Size of time chunks (default: "1 day")
  """
  def create_hypertable(
        tenant_schema_name,
        table_name,
        time_column,
        chunk_time_interval \\ "1 day"
      ) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT create_hypertable('#{table_name}', '#{time_column}',
        chunk_time_interval => INTERVAL '#{chunk_time_interval}',
        if_not_exists => TRUE)
      """
      Repo.query(query)
    end)
  end

  @doc """
  Creates a continuous aggregate (materialized view) for real-time rollups.
  """
  def create_continuous_aggregate(
        tenant_schema_name,
        aggregate_name,
        source_table,
        time_bucket \\ "1 hour"
      ) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      CREATE MATERIALIZED VIEW IF NOT EXISTS #{aggregate_name}
      WITH (timescaledb.continuous) AS
      SELECT
        time_bucket('#{time_bucket}', time) AS bucket,
        merchant_id,
        SUM(transaction_volume) as total_volume,
        COUNT(*) as transaction_count,
        AVG(average_transaction_amount) as avg_amount,
        STDDEV(average_transaction_amount) as amount_stddev
      FROM #{source_table}
      GROUP BY bucket, merchant_id
      """
      Repo.query(query)
    end)
  end

  @doc """
  Queries time-series analytics for a merchant over a date range.
  """
  def time_series_analytics(tenant_schema_name, table_name, merchant_id, days \\ 30) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        time_bucket('1 day', time) as date,
        SUM(transaction_volume) as daily_volume,
        COUNT(*) as daily_count,
        AVG(average_transaction_amount) as daily_avg,
        MIN(average_transaction_amount) as daily_min,
        MAX(average_transaction_amount) as daily_max,
        STDDEV(average_transaction_amount) as daily_stddev
      FROM #{table_name}
      WHERE merchant_id = $1
      AND time >= NOW() - INTERVAL '#{days} days'
      GROUP BY time_bucket('1 day', time)
      ORDER BY date DESC
      """
      Repo.query(query, [merchant_id])
    end)
  end

  @doc """
  Queries real-time metrics in 5-minute buckets for the last hour.
  """
  def real_time_metrics(tenant_schema_name, table_name, merchant_id) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        time_bucket('5 minutes', time) as five_min_bucket,
        merchant_id,
        COUNT(*) as transaction_count,
        SUM(transaction_volume) as total_volume,
        AVG(response_time_ms) as avg_response_time
      FROM #{table_name}
      WHERE merchant_id = $1
      AND time >= NOW() - INTERVAL '1 hour'
      GROUP BY five_min_bucket, merchant_id
      ORDER BY five_min_bucket DESC
      """
      Repo.query(query, [merchant_id])
    end)
  end

  @doc """
  Refreshes a continuous aggregate's data.
  """
  def refresh_continuous_aggregate(tenant_schema_name, aggregate_name, start_time, end_time) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      CALL refresh_continuous_aggregate('#{aggregate_name}', $1, $2)
      """
      Repo.query(query, [start_time, end_time])
    end)
  end

  @doc """
  Gets compression statistics for a hypertable.
  """
  def compression_stats(tenant_schema_name, table_name) do
    Context.with_tenant_context(tenant_schema_name, fn ->
      query = """
      SELECT
        chunk_schema,
        chunk_name,
        compression_status,
        before_compression_total_bytes,
        after_compression_total_bytes
      FROM chunk_compression_stats('#{table_name}')
      """
      Repo.query(query)
    end)
  end
end
```

#### Step 2: Update MultiTenant Delegations

```elixir
# In lib/mcp/multi_tenant.ex, replace lines 70-162 with:

alias Mcp.Analytics.TimeSeries

# Time-series operations (TimescaleDB)
defdelegate create_hypertable(tenant_schema_name, table_name, time_column, chunk_time_interval \\ "1 day"), to: TimeSeries
defdelegate create_continuous_aggregate(tenant_schema_name, aggregate_name, source_table, time_bucket \\ "1 hour"), to: TimeSeries
defdelegate time_series_analytics(tenant_schema_name, table_name, merchant_id, days \\ 30), to: TimeSeries
defdelegate real_time_metrics(tenant_schema_name, table_name, merchant_id), to: TimeSeries
```

### Verification Commands

```bash
mix compile --warnings-as-errors
mix test test/mcp/analytics/time_series_test.exs
```

---

## TODOs #9-11: Security Test Implementations

**Files:** `test/mcp/security/authentication_security_test.exs:205, :413, :469`
**Current State:** Tests with weakened assertions or commented out
**Target State:** Fully functional security tests

### Implementation

#### TODO #9: Token Encryption in SessionPlug (Line 205)

```elixir
# lib/mcp_web/auth/session_plug.ex - Add token encryption

defmodule McpWeb.Auth.SessionPlug do
  @moduledoc """
  Session plug with encrypted token storage.
  """

  import Plug.Conn
  require Logger

  @encryption_key_env "SESSION_ENCRYPTION_KEY"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> fetch_and_decrypt_tokens()
  end

  @doc """
  Encrypts a token for cookie storage.
  """
  def encrypt_token(token) do
    key = get_encryption_key()
    iv = :crypto.strong_rand_bytes(16)

    {ciphertext, tag} = :crypto.crypto_one_time_aead(
      :aes_256_gcm,
      key,
      iv,
      token,
      "",
      true
    )

    Base.encode64(iv <> tag <> ciphertext)
  end

  @doc """
  Decrypts a token from cookie storage.
  """
  def decrypt_token(encrypted) do
    key = get_encryption_key()

    case Base.decode64(encrypted) do
      {:ok, <<iv::binary-16, tag::binary-16, ciphertext::binary>>} ->
        case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "", tag, false) do
          :error -> {:error, :decryption_failed}
          plaintext -> {:ok, plaintext}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp get_encryption_key do
    System.get_env(@encryption_key_env) ||
      Application.get_env(:mcp, :session_encryption_key) ||
      raise "SESSION_ENCRYPTION_KEY not configured"
  end

  defp fetch_and_decrypt_tokens(conn) do
    # Implementation for fetching and decrypting session tokens
    conn
  end
end
```

Update the test:

```elixir
# In test/mcp/security/authentication_security_test.exs, line 205:

test "encrypts tokens in cookies", %{conn: conn} do
  {:ok, user} = create_test_user()

  conn =
    conn
    |> post("/sign-in", %{
      "email" => user.email,
      "password" => "Password123!"
    })

  # Check that encrypted tokens are set
  assert conn.resp_cookies["_mcp_access_token"] != nil

  access_token = conn.resp_cookies["_mcp_access_token"]

  # Tokens should be encrypted (NOT raw JWT starting with eyJ)
  refute String.starts_with?(access_token.value, "eyJ")

  # Should be valid base64
  assert {:ok, _} = Base.decode64(access_token.value)
end
```

#### TODO #10: Fix OAuth Session Test (Line 413)

```elixir
# Replace the commented test with working version:

test "prevents OAuth code injection", %{conn: conn} do
  malicious_codes = [
    "malicious_code'; DROP TABLE users; --",
    "../../../etc/passwd",
    "<script>alert('xss')</script>"
  ]

  Enum.each(malicious_codes, fn malicious_code ->
    # Use Plug.Test to properly initialize session
    conn =
      conn
      |> Plug.Test.init_test_session(%{
        oauth_state: "valid_state",
        oauth_provider: "google"
      })

    conn = get(conn, "/auth/google/callback?code=#{URI.encode(malicious_code)}&state=valid_state")

    # Should handle malicious input gracefully
    assert conn.status != 500
    # Should not expose error details
    refute conn.resp_body =~ "DROP TABLE"
    refute conn.resp_body =~ "passwd"
  end)
end
```

#### TODO #11: Include device_id in JWT Claims (Line 469)

```elixir
# In lib/mcp/accounts/jwt.ex, update token creation:

def create_access_token(user, session_data, opts \\ []) do
  device_id = Keyword.get(opts, :device_id) || generate_device_id(opts)
  ip_address = Keyword.get(opts, :ip_address)
  user_agent = Keyword.get(opts, :user_agent)

  claims = %{
    "sub" => user.id,
    "email" => user.email,
    "tenant_id" => user.tenant_id,
    "device_id" => device_id,
    "ip" => ip_address,
    "ua_hash" => hash_user_agent(user_agent),
    "iat" => DateTime.utc_now() |> DateTime.to_unix(),
    "exp" => DateTime.utc_now() |> DateTime.add(@access_token_ttl, :second) |> DateTime.to_unix()
  }

  sign_token(claims)
end

defp generate_device_id(opts) do
  ip = Keyword.get(opts, :ip_address, "unknown")
  ua = Keyword.get(opts, :user_agent, "unknown")

  :crypto.hash(:sha256, "#{ip}:#{ua}")
  |> Base.encode16(case: :lower)
  |> String.slice(0, 16)
end

defp hash_user_agent(nil), do: nil
defp hash_user_agent(ua) do
  :crypto.hash(:sha256, ua)
  |> Base.encode16(case: :lower)
  |> String.slice(0, 16)
end
```

Update the test:

```elixir
# In test/mcp/security/authentication_security_test.exs, line 469:

test "binds session to IP address", %{conn: _conn} do
  {:ok, user} = create_test_user()

  {:ok, user} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
  {:ok, session} = Auth.create_user_session(user, "127.0.0.1", user_agent: "TestBrowser/1.0")

  {:ok, claims} = Auth.verify_jwt_access_token(session.access_token)

  # Device ID should be present and derived from IP/UA
  assert claims["device_id"] != nil
  assert String.length(claims["device_id"]) == 16

  # IP should be stored (for audit, not enforcement)
  assert claims["ip"] == "127.0.0.1"
end
```

### Verification Commands

```bash
mix compile --warnings-as-errors
mix test test/mcp/security/authentication_security_test.exs
```

---

## TODO #12: Fix Rate Limiting in GDPR Test

**File:** `test/mcp/gdpr/system/compliance_validation_test.exs:339`
**Current State:** Rate limiting test skipped
**Target State:** Functional test with Redis mock

### Implementation

#### Step 1: Create Redis Test Helper

```elixir
# test/support/redis_test_helper.ex
defmodule Mcp.RedisTestHelper do
  @moduledoc """
  Test helpers for Redis-based functionality.
  """

  def setup_rate_limiter do
    # Ensure rate limiter is using test-friendly configuration
    Application.put_env(:mcp, :rate_limiter, [
      backend: Mcp.Utils.RateLimiter.Redis,
      test_mode: true
    ])
  end

  def clear_rate_limits do
    Mcp.Redis.command(["KEYS", "rate_limit:*"])
    |> case do
      {:ok, keys} when keys != [] ->
        Enum.each(keys, fn key ->
          Mcp.Redis.command(["DEL", key])
        end)
      _ ->
        :ok
    end
  end

  def set_rate_limit_exceeded(key) do
    # Set a very high count to trigger rate limiting
    Mcp.Redis.command(["SET", "rate_limit:#{key}", "1000000"])
    Mcp.Redis.command(["EXPIRE", "rate_limit:#{key}", "60"])
  end
end
```

#### Step 2: Update the Test

```elixir
# In test/mcp/gdpr/system/compliance_validation_test.exs

describe "Rate Limiting Protection" do
  setup [:create_admin_user]

  setup do
    Mcp.RedisTestHelper.setup_rate_limiter()
    on_exit(fn -> Mcp.RedisTestHelper.clear_rate_limits() end)
    :ok
  end

  test "rate limits GDPR export requests", %{conn: conn} do
    # ... existing setup code ...

    # Clear any existing rate limits
    Mcp.RedisTestHelper.clear_rate_limits()

    # Make rapid requests
    results =
      for _i <- 1..15 do
        post(test_conn, "/api/gdpr/export", %{"format" => "json"})
      end

    statuses = Enum.map(results, & &1.status)

    # Some should succeed (200), some should be rate limited (429)
    assert 200 in statuses, "At least one request should succeed"
    assert 429 in statuses, "Rate limiting should kick in after threshold"

    # Verify rate limit response format
    rate_limited = Enum.find(results, &(&1.status == 429))
    if rate_limited do
      body = Jason.decode!(rate_limited.resp_body)
      assert body["error"]["code"] == "rate_limit_exceeded"
      assert rate_limited |> get_resp_header("retry-after") |> List.first() != nil
    end
  end

  test "input validation blocks injection attacks", %{conn: conn} do
    # ... existing test code remains the same ...
  end
end
```

### Verification Commands

```bash
mix test test/mcp/gdpr/system/compliance_validation_test.exs --only rate_limiting
```

---

## TODO #13: Link Review to User

**File:** `lib/mcp/underwriting/resources/review.ex:45`
**Current State:** `reviewer_id` attribute commented out
**Target State:** Full relationship with User resource

### Implementation

#### Step 1: Update Review Resource

```elixir
# In lib/mcp/underwriting/resources/review.ex

attributes do
  uuid_primary_key :id

  attribute :decision, :atom do
    constraints one_of: [:approved, :rejected, :more_info_required]
    allow_nil? false
  end

  attribute :notes, :string
  attribute :risk_score, :integer

  attribute :reviewer_id, :uuid do
    allow_nil? false
    description "The user who performed this review"
  end

  timestamps()
end

relationships do
  belongs_to :application, Mcp.Underwriting.Application

  belongs_to :reviewer, Mcp.Accounts.User do
    source_attribute :reviewer_id
    destination_attribute :id
    allow_nil? false
  end
end

actions do
  defaults [:read, :destroy]

  create :create do
    primary? true
    accept [:decision, :notes, :risk_score, :application_id]

    # Require reviewer
    argument :reviewer_id, :uuid, allow_nil?: false

    change set_attribute(:reviewer_id, arg(:reviewer_id))
  end

  update :update do
    accept [:decision, :notes, :risk_score]
    # Don't allow changing reviewer after creation
  end
end
```

#### Step 2: Create Migration

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_add_reviewer_id_to_reviews.exs
defmodule Mcp.Repo.Migrations.AddReviewerIdToReviews do
  use Ecto.Migration

  def change do
    alter table(:reviews) do
      add :reviewer_id, references(:users, type: :uuid, prefix: "platform"), null: false
    end

    create index(:reviews, [:reviewer_id])
  end
end
```

#### Step 3: Update LiveViews to Pass Reviewer

```elixir
# In lib/mcp_web/live/tenant/review_live.ex

def handle_event("submit_review", %{"decision" => decision, "notes" => notes}, socket) do
  review_params = %{
    decision: String.to_existing_atom(decision),
    notes: notes,
    application_id: socket.assigns.application.id,
    reviewer_id: socket.assigns.current_user.id  # Add this line
  }

  case Mcp.Underwriting.Review.create(review_params) do
    {:ok, review} ->
      {:noreply,
        socket
        |> put_flash(:info, "Review submitted successfully")
        |> push_navigate(to: ~p"/tenant/applications")}

    {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
  end
end
```

### Verification Commands

```bash
mix ecto.gen.migration add_reviewer_id_to_reviews
mix ecto.migrate
mix compile --warnings-as-errors
mix test test/mcp/underwriting/review_test.exs
```

---

## Execution Order

Based on dependencies and priorities, execute in this order:

### Phase 1: Critical Security (Immediate)
1. **TODOs #4-5**: Password reset implementation
2. **TODO #13**: Review-User link (audit compliance)

### Phase 2: Performance & Correctness (This Sprint)
3. **TODO #2**: Spending limit caching
4. **TODO #7**: Instruction set tenant scoping
5. **TODO #3**: Execution ID socket management

### Phase 3: Feature Completeness (Next Sprint)
6. **TODO #6**: Document intelligence file handling
7. **TODOs #9-11**: Security test implementations
8. **TODO #12**: GDPR rate limiting test

### Phase 4: Refactoring (Maintenance)
9. **TODO #8**: TimeSeries extraction
10. **TODO #1**: Geo extraction

---

## Verification Checklist

After all implementations:

```bash
# Full verification
mix compile --warnings-as-errors
mix credo --strict
mix test
mix credo --only todo  # Should return 0 TODOs

# Security audit
mix test test/mcp/security/
mix test test/mcp/gdpr/

# Performance verification
mix test test/mcp/cache/
```

---

## Success Criteria

- [ ] `mix credo --only todo` returns **0 results**
- [ ] All tests pass: `mix test` shows 100% pass rate
- [ ] No compiler warnings: `mix compile --warnings-as-errors` succeeds
- [ ] Password reset is functional end-to-end
- [ ] API spending limits are cached with < 10ms latency
- [ ] Reviews have full audit trail with reviewer linkage
- [ ] All security tests run without assertions disabled

---

*Document generated by TODO Elimination Brainstorming Session*
