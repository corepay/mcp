# Core Platform Infrastructure - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP core platform infrastructure. Includes setup instructions, architecture patterns, service integration, and operational procedures.

## Architecture Overview

The core platform follows a microservices architecture built on Elixir/OTP principles:

- **Application Layer**: Phoenix web server with LiveView for real-time interfaces
- **Business Logic Layer**: Ash Framework for declarative resource management
- **Data Layer**: PostgreSQL with TimescaleDB, PostGIS, pgvector, and Apache AGE extensions
- **Cache Layer**: Redis for session storage, caching, and pub/sub messaging
- **Storage Layer**: MinIO S3-compatible object storage with encryption
- **Security Layer**: Vault for secrets management and encryption services
- **Monitoring Layer**: Telemetry, logging, and health check systems

## Data Management

### Soft Deletes (AshArchival)

We use `AshArchival` to handle soft deletes. This ensures that records are marked as archived instead of being physically removed from the database.

**Usage**:
1.  Add `AshArchival` to the resource extensions.
2.  Run migrations to add the `archived_at` column.
3.  Use `destroy` action as normal; Ash will intercept it.

```elixir
# In your resource
use Ash.Resource, extensions: [AshArchival]
```

### Realistic Seeding

The `priv/repo/seeds.exs` file orchestrates a complete environment setup.

**Running Seeds**:
```bash
mix run priv/repo/seeds.exs
```

### SQL Linting

We use **Splinter** to ensure database schema health.

**Running the Linter**:
```bash
mix db.lint
```
This checks for missing indexes, mutable function search paths, and other best practices.

## Infrastructure Services

### Database Service (PostgreSQL + Extensions)

```elixir
# Repository configuration with advanced features
defmodule Mcp.Core.Repo do
  use Ecto.Repo,
    otp_app: :mcp,
    adapter: Ecto.Adapters.Postgres

  def init(_type, config) do
    # Load database configuration from environment
    config = Keyword.merge(config, get_db_config())

    # Configure connection pool for high concurrency
    config = Keyword.put(config, :pool_size, get_pool_size())

    # Enable prepared statement caching
    config = Keyword.put(config, :prepare, :named)

    {:ok, config}
  end

  def get_db_config do
    [
      hostname: System.get_env("POSTGRES_HOST") || "localhost",
      username: System.get_env("POSTGRES_USER") || "postgres",
      password: System.get_env("POSTGRES_PASSWORD") || "postgres",
      database: System.get_env("POSTGRES_DB") || "mcp_dev",
      port: System.get_env("POSTGRES_PORT") |> String.to_integer() || 5432,
      ssl: System.get_env("POSTGRES_SSL") == "true",
      # Advanced PostgreSQL configuration
      extensions: [Geo.PostGIS.Extension, Pgvector.Extension],
      types: Mcp.Core.PostgresTypes
    ]
  end

  def get_pool_size do
    case System.get_env("ENV") do
      "prod" -> 20
      "test" -> 1
      _ -> 10
    end
  end

  # Multi-tenancy schema switching
  def put_tenant_schema(tenant_id) do
    repo_config = get_dynamic_repo().config()
    schema_name = "tenant_#{tenant_id}"

    # Execute schema switch
    repo_config
    |> Keyword.put(:schema_search_path, "#{schema_name}, public")
    |> put_dynamic_repo()
  end

  # TimescaleDB hypertable creation
  def create_hypertable(table_name, time_column, opts \\ []) do
    chunk_time_interval = Keyword.get(opts, :chunk_time_interval, "1 day")

    sql = """
    SELECT create_hypertable(
      '#{table_name}',
      '#{time_column}',
      chunk_time_interval => INTERVAL '#{chunk_time_interval}'
    );
    """

    query!(sql)
  end
end

# Custom PostgreSQL types for extensions
defmodule Mcp.Core.PostgresTypes do
  use Ecto.PostgresTypes

  # Vector type for pgvector extension
  def vector(type) do
    %Postgrex.TypeInfo{name: "vector", base_type: type}
  end

  # Geography type for PostGIS
  def geography(type) do
    %Postgrex.TypeInfo{name: "geography", base_type: type}
  end
end
```

### Cache Service (Redis)

```elixir
# Redis cache manager with connection pooling
defmodule Mcp.Cache.RedisManager do
  use GenServer
  require Logger

  @pool_name :redis_pool
  @default_ttl 3600  # 1 hour

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start Redix connection pool
    children = [
      {Redix, host: redis_host(), port: redis_port(), name: @pool_name},
      {Redix, host: redis_host(), port: redis_port(), name: :"#{@pool_name}_backup"}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  # Cache operations with automatic serialization
  def get(key) do
    case Redix.command(@pool_name, ["GET", key]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> {:ok, deserialize_value(value)}
      {:error, reason} -> {:error, reason}
    end
  end

  def set(key, value, ttl \\ @default_ttl) do
    serialized_value = serialize_value(value)

    Redix.command(@pool_name, ["SETEX", key, ttl, serialized_value])
  end

  def delete(key) do
    Redix.command(@pool_name, ["DEL", key])
  end

  def exists?(key) do
    case Redix.command(@pool_name, ["EXISTS", key]) do
      {:ok, 1} -> true
      {:ok, 0} -> false
      {:error, _} -> false
    end
  end

  # Batch operations
  def mget(keys) when is_list(keys) do
    case Redix.command(@pool_name, ["MGET" | keys]) do
      {:ok, values} ->
        result =
          values
          |> Enum.map(&deserialize_value/1)
          |> Enum.zip(keys)
          |> Map.new(fn {value, key} -> {key, value} end)

        {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def mset(key_value_pairs) when is_list(key_value_pairs) do
    flattened_pairs =
      key_value_pairs
      |> Enum.map(fn {key, value} -> [key, serialize_value(value)] end)
      |> List.flatten()

    Redix.command(@pool_name, ["MSET" | flattened_pairs])
  end

  # Cache patterns
  def cache(key, value_ttl_calculator, operation) when is_function(value_ttl_calculator, 0) do
    case get(key) do
      {:ok, nil} ->
        # Cache miss - compute and store
        case operation.() do
          {:ok, value} ->
            {value, ttl} = value_ttl_calculator.()
            set(key, value, ttl)
            {:ok, value}
          error -> error
        end
      {:ok, value} ->
        # Cache hit
        {:ok, value}
      error -> error
    end
  end

  # Pub/Sub for real-time events
  def publish(channel, message) do
    payload = Jason.encode!(%{
      data: message,
      timestamp: DateTime.utc_now(),
      id: UUID.uuid4()
    })

    Redix.command(@pool_name, ["PUBLISH", channel, payload])
  end

  def subscribe(channel) do
    Redix.pubsub(:start_link, [host: redis_host(), port: redis_port()], name: :redis_pubsub)
    Redix.pubsub(:subscribe, :redis_pubsub, channel)
  end

  # Helper functions
  defp redis_host, do: System.get_env("REDIS_HOST") || "localhost"
  defp redis_port, do: System.get_env("REDIS_PORT") |> String.to_integer() || 6379

  defp serialize_value(value) do
    case value do
      nil -> nil
      _ -> Jason.encode!(value)
    end
  end

  defp deserialize_value(nil), do: nil
  defp deserialize_value(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, parsed} -> parsed
      {:error, _} -> value
    end
  end
  defp deserialize_value(value), do: value
end
```

### Storage Service (MinIO/S3)

```elixir
# S3-compatible storage client with encryption
defmodule Mcp.Storage.S3Client do
  use GenServer
  require Logger

  @default_bucket "mcp-storage"
  @encryption_algorithm "AES256"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    config = %{
      access_key_id: System.get_env("MINIO_ACCESS_KEY"),
      secret_access_key: System.get_env("MINIO_SECRET_KEY"),
      endpoint: System.get_env("MINIO_ENDPOINT"),
      region: System.get_env("MINIO_REGION") || "us-east-1",
      scheme: "https://"
    }

    {:ok, %{config: config}}
  end

  # File operations with automatic encryption
  def upload_file(bucket \\ @default_bucket, key, file_path, opts \\ []) do
    GenServer.call(__MODULE__, {:upload_file, bucket, key, file_path, opts})
  end

  def download_file(bucket \\ @default_bucket, key, destination_path) do
    GenServer.call(__MODULE__, {:download_file, bucket, key, destination_path})
  end

  def delete_file(bucket \\ @default_bucket, key) do
    GenServer.call(__MODULE__, {:delete_file, bucket, key})
  end

  def list_files(bucket \\ @default_bucket, prefix \\ "") do
    GenServer.call(__MODULE__, {:list_files, bucket, prefix})
  end

  def generate_presigned_url(bucket \\ @default_bucket, key, expires_in \\ 3600) do
    GenServer.call(__MODULE__, {:presigned_url, bucket, key, expires_in})
  end

  @impl true
  def handle_call({:upload_file, bucket, key, file_path, opts}, _from, state) do
    client = ExAws.S3.new(state.config)

    upload_opts = [
      {:acl, Keyword.get(opts, :acl, :private)},
      {:content_type, Keyword.get(opts, :content_type, "application/octet-stream")}
    ]

    # Add server-side encryption
    upload_opts = Keyword.put(upload_opts, :server_side_encryption, @encryption_algorithm)

    case File.read(file_path) do
      {:ok, file_content} ->
        operation = ExAws.S3.put_object(bucket, key, file_content, upload_opts)

        case ExAws.request(operation) do
          {:ok, _result} ->
            {:reply, {:ok, %{bucket: bucket, key: key, size: byte_size(file_content)}}, state}
          {:error, reason} ->
            Logger.error("Failed to upload file: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:download_file, bucket, key, destination_path}, _from, state) do
    client = ExAws.S3.new(state.config)
    operation = ExAws.S3.get_object(bucket, key)

    case ExAws.request(operation) do
      {:ok, %{body: file_content}} ->
        case File.write(destination_path, file_content) do
          :ok ->
            {:reply, {:ok, %{bucket: bucket, key: key, path: destination_path}}, state}
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      {:error, reason} ->
        Logger.error("Failed to download file: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete_file, bucket, key}, _from, state) do
    client = ExAws.S3.new(state.config)
    operation = ExAws.S3.delete_object(bucket, key)

    case ExAws.request(operation) do
      {:ok, _result} ->
        {:reply, :ok, state}
      {:error, reason} ->
        Logger.error("Failed to delete file: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_files, bucket, prefix}, _from, state) do
    client = ExAws.S3.new(state.config)
    operation = ExAws.S3.list_objects(bucket, prefix: prefix)

    case ExAws.request(operation) do
      {:ok, %{body: %{contents: objects}}} ->
        files = Enum.map(objects, &%{
          key: &1.key,
          size: &1.size,
          last_modified: &1.last_modified,
          etag: &1.etag
        })
        {:reply, {:ok, files}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:presigned_url, bucket, key, expires_in}, _from, state) do
    client = ExAws.S3.new(state.config)
    config = ExAws.Config.new(:s3, state.config)

    url = ExAws.S3.presigned_url(client, :get, bucket, key, expires_in)
    {:reply, {:ok, url}, state}
  end
end
```

### Secrets Management Service (Vault)

```elixir
# Vault integration for secure secrets management
defmodule Mcp.Secrets.VaultClient do
  use GenServer
  require Logger

  @mount_point "secret"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    vault_url = System.get_env("VAULT_ADDR") || "http://localhost:8200"
    vault_token = System.get_env("VAULT_TOKEN")

    if vault_token do
      {:ok, %{vault_url: vault_url, token: vault_token}}
    else
      {:error, "Vault token not configured"}
    end
  end

  # Secrets operations
  def write_secret(path, data, mount_point \\ @mount_point) do
    GenServer.call(__MODULE__, {:write_secret, path, data, mount_point})
  end

  def read_secret(path, mount_point \\ @mount_point) do
    GenServer.call(__MODULE__, {:read_secret, path, mount_point})
  end

  def delete_secret(path, mount_point \\ @mount_point) do
    GenServer.call(__MODULE__, {:delete_secret, path, mount_point})
  end

  def list_secrets(path, mount_point \\ @mount_point) do
    GenServer.call(__MODULE__, {:list_secrets, path, mount_point})
  end

  # Encryption operations
  def encrypt_data(data, key_name) do
    GenServer.call(__MODULE__, {:encrypt_data, data, key_name})
  end

  def decrypt_data(encrypted_data, key_name) do
    GenServer.call(__MODULE__, {:decrypt_data, encrypted_data, key_name})
  end

  @impl true
  def handle_call({:write_secret, path, data, mount_point}, _from, state) do
    full_path = "#{mount_point}/#{path}"
    url = "#{state.vault_url}/v1/#{full_path}"

    headers = [
      {"X-Vault-Token", state.token},
      {"Content-Type", "application/json"}
    ]

    body = Jason.encode!(%{data: data})

    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: 200}} ->
        {:reply, :ok, state}
      {:ok, response} ->
        Logger.error("Failed to write secret: #{response.body}")
        {:reply, {:error, response.body}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:read_secret, path, mount_point}, _from, state) do
    full_path = "#{mount_point}/#{path}"
    url = "#{state.vault_url}/v1/#{full_path}"

    headers = [{"X-Vault-Token", state.token}]

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => %{"data" => data}}} ->
            {:reply, {:ok, data}, state}
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      {:ok, response} ->
        Logger.error("Failed to read secret: #{response.body}")
        {:reply, {:error, response.body}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete_secret, path, mount_point}, _from, state) do
    full_path = "#{mount_point}/#{path}"
    url = "#{state.vault_url}/v1/#{full_path}"

    headers = [{"X-Vault-Token", state.token}]

    case HTTPoison.delete(url, headers) do
      {:ok, %{status_code: 204}} ->
        {:reply, :ok, state}
      {:ok, response} ->
        Logger.error("Failed to delete secret: #{response.body}")
        {:reply, {:error, response.body}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_secrets, path, mount_point}, _from, state) do
    full_path = "#{mount_point}/#{path}"
    url = "#{state.vault_url}/v1/#{full_path}?list=true"

    headers = [{"X-Vault-Token", state.token}]

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => %{"keys" => keys}}} ->
            {:reply, {:ok, keys}, state}
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      {:ok, response} ->
        {:reply, {:error, response.body}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end
```

### Health Monitoring Service

```elixir
# Comprehensive health check system
defmodule Mcp.Core.HealthMonitor do
  use GenServer
  require Logger

  @check_interval 30_000  # 30 seconds
  @timeout 5_000  # 5 seconds per check

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def run_health_check do
    GenServer.call(__MODULE__, :run_health_check)
  end

  @impl true
  def init(_opts) do
    # Schedule periodic health checks
    Process.send_after(self(), :check_health, @check_interval)

    {:ok, %{status: :healthy, checks: %{}, last_check: nil}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:run_health_check, _from, _state) do
    checks = run_all_checks()
    overall_status = determine_overall_status(checks)

    new_state = %{
      status: overall_status,
      checks: checks,
      last_check: DateTime.utc_now()
    }

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_info(:check_health, state) do
    checks = run_all_checks()
    overall_status = determine_overall_status(checks)

    new_state = %{
      status: overall_status,
      checks: checks,
      last_check: DateTime.utc_now()
    }

    # Log status changes
    if state.status != overall_status do
      Logger.warn("Health status changed: #{state.status} -> #{overall_status}")
    end

    # Schedule next check
    Process.send_after(self(), :check_health, @check_interval)

    {:noreply, new_state}
  end

  defp run_all_checks do
    %{
      database: check_database(),
      cache: check_cache(),
      storage: check_storage(),
      vault: check_vault(),
      system: check_system()
    }
  end

  defp check_database do
    timeout = @timeout
    start_time = System.monotonic_time(:millisecond)

    try do
      case Mcp.Core.Repo.query("SELECT 1", [], timeout: timeout) do
        {:ok, _result} ->
          duration = System.monotonic_time(:millisecond) - start_time
          {:ok, %{response_time: duration, status: :healthy}}
        {:error, reason} ->
          {:error, %{reason: inspect(reason), status: :unhealthy}}
      end
    catch
      :exit, reason ->
        {:error, %{reason: inspect(reason), status: :unhealthy}}
    end
  end

  defp check_cache do
    timeout = @timeout
    start_time = System.monotonic_time(:millisecond)

    try do
      case Mcp.Cache.RedisManager.get("health_check") do
        {:ok, _value} ->
          duration = System.monotonic_time(:millisecond) - start_time
          {:ok, %{response_time: duration, status: :healthy}}
        {:error, reason} ->
          {:error, %{reason: inspect(reason), status: :unhealthy}}
      end
    catch
      :exit, reason ->
        {:error, %{reason: inspect(reason), status: :unhealthy}}
    end
  end

  defp check_storage do
    timeout = @timeout
    start_time = System.monotonic_time(:millisecond)

    try do
      case Mcp.Storage.S3Client.list_files() do
        {:ok, _files} ->
          duration = System.monotonic_time(:millisecond) - start_time
          {:ok, %{response_time: duration, status: :healthy}}
        {:error, reason} ->
          {:error, %{reason: inspect(reason), status: :unhealthy}}
      end
    catch
      :exit, reason ->
        {:error, %{reason: inspect(reason), status: :unhealthy}}
    end
  end

  defp check_vault do
    timeout = @timeout
    start_time = System.monotonic_time(:millisecond)

    try do
      case Mcp.Secrets.VaultClient.list_secrets("health") do
        {:ok, _secrets} ->
          duration = System.monotonic_time(:millisecond) - start_time
          {:ok, %{response_time: duration, status: :healthy}}
        {:error, reason} ->
          {:error, %{reason: inspect(reason), status: :unhealthy}}
      end
    catch
      :exit, reason ->
        {:error, %{reason: inspect(reason), status: :unhealthy}}
    end
  end

  defp check_system do
    # Check system resources
    memory_usage = :erlang.memory(:total)
    process_count = :erlang.system_info(:process_count)
    scheduler_utilization = :scheduler.sample_all()

    warnings = []

    # Memory warnings
    memory_warning_threshold = 1_000_000_000  # 1GB
    warnings = if memory_usage > memory_warning_threshold do
      ["High memory usage: #{memory_usage} bytes" | warnings]
    else
      warnings
    end

    # Process count warnings
    process_warning_threshold = 100_000
    warnings = if process_count > process_warning_threshold do
      ["High process count: #{process_count}" | warnings]
    else
      warnings
    end

    status = if warnings == [], do: :healthy, else: :warning

    {:ok, %{
      status: status,
      memory_usage: memory_usage,
      process_count: process_count,
      scheduler_utilization: scheduler_utilization,
      warnings: warnings
    }}
  end

  defp determine_overall_status(checks) do
    statuses = Enum.map(checks, fn {_service, result} ->
      case result do
        {:ok, _} -> :healthy
        {:error, _} -> :unhealthy
      end
    end)

    cond do
      Enum.all?(statuses, &(&1 == :healthy)) -> :healthy
      Enum.any?(statuses, &(&1 == :unhealthy)) -> :unhealthy
      true -> :degraded
    end
  end
end
```

### Telemetry and Observability

```elixir
# Comprehensive telemetry system
defmodule Mcp.Core.Telemetry do
  use TelemetryRegistry

  telemetry_event(%{
    event: [:mcp, :database, :query],
    description: "Database query execution",
    measurements: ["duration", "result_size"],
    metadata: ["query", "repo", "source", "type"]
  })

  telemetry_event(%{
    event: [:mcp, :cache, :operation],
    description: "Cache operation performance",
    measurements: ["duration"],
    metadata: ["operation", "key", "hit"]
  })

  telemetry_event(%{
    event: [:mcp, :storage, :operation],
    description: "Storage operation performance",
    measurements: ["duration", "size"],
    metadata: ["operation", "bucket", "key"]
  })

  def setup do
    # Database query logging
    :telemetry.attach(
      "database-logger",
      [:mcp, :database, :query],
      &handle_database_query/4,
      nil
    )

    # Cache operation logging
    :telemetry.attach(
      "cache-logger",
      [:mcp, :cache, :operation],
      &handle_cache_operation/4,
      nil
    )

    # Storage operation logging
    :telemetry.attach(
      "storage-logger",
      [:mcp, :storage, :operation],
      &handle_storage_operation/4,
      nil
    )

    # Phoenix metrics
    :telemetry.attach(
      "phoenix-logger",
      [:phoenix, :request],
      &handle_phoenix_request/4,
      nil
    )
  end

  defp handle_database_query(_event, measurements, metadata, _config) do
    duration_ms = measurements.duration / 1000

    cond do
      duration_ms > 1000 ->
        Logger.warn("Slow database query: #{duration_ms}ms - #{metadata.query}")
      duration_ms > 500 ->
        Logger.info("Database query: #{duration_ms}ms - #{metadata.query}")
      true ->
        Logger.debug("Database query: #{duration_ms}ms")
    end
  end

  defp handle_cache_operation(_event, measurements, metadata, _config) do
    duration_ms = measurements.duration / 1000

    Logger.debug("Cache #{metadata.operation}: #{duration_ms}ms - #{metadata.key} (hit: #{metadata.hit})")
  end

  defp handle_storage_operation(_event, measurements, metadata, _config) do
    duration_ms = measurements.duration / 1000
    size_mb = measurements.size / (1024 * 1024)

    Logger.info("Storage #{metadata.operation}: #{duration_ms}ms - #{size_mb}MB - #{metadata.key}")
  end

  defp handle_phoenix_request(_event, measurements, metadata, _config) do
    duration_ms = measurements.duration / 1000

    cond do
      duration_ms > 5000 ->
        Logger.warn("Slow request: #{duration_ms}ms - #{metadata.request_path}")
      duration_ms > 2000 ->
        Logger.info("Request: #{duration_ms}ms - #{metadata.request_path}")
      true ->
        Logger.debug("Request: #{duration_ms}ms - #{metadata.request_path}")
    end
  end
end
```

## Application Configuration

### Environment Setup

```elixir
# config/config.exs
import Config

# Database configuration
config :mcp, Mcp.Core.Repo,
  database: System.get_env("POSTGRES_DB") || "mcp_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  port: String.to_integer(System.get_env("POSTGRES_PORT") || "5432"),
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10"),
  ssl: System.get_env("POSTGRES_SSL") == "true"

# Redis configuration
config :mcp, Mcp.Cache.RedisManager,
  host: System.get_env("REDIS_HOST") || "localhost",
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  database: String.to_integer(System.get_env("REDIS_DB") || "0"),
  password: System.get_env("REDIS_PASSWORD"),
  pool_size: String.to_integer(System.get_env("REDIS_POOL_SIZE") || "5")

# MinIO/S3 configuration
config :mcp, Mcp.Storage.S3Client,
  access_key_id: System.get_env("MINIO_ACCESS_KEY"),
  secret_access_key: System.get_env("MINIO_SECRET_KEY"),
  endpoint: System.get_env("MINIO_ENDPOINT"),
  region: System.get_env("MINIO_REGION") || "us-east-1",
  bucket: System.get_env("MINIO_BUCKET") || "mcp-storage"

# Vault configuration
config :mcp, Mcp.Secrets.VaultClient,
  vault_addr: System.get_env("VAULT_ADDR") || "http://localhost:8200",
  vault_token: System.get_env("VAULT_TOKEN"),
  mount_point: System.get_env("VAULT_MOUNT_POINT") || "secret"

# Telemetry configuration
config :mcp, Mcp.Core.Telemetry,
  enable_database_logging: true,
  enable_cache_logging: true,
  enable_storage_logging: true
```

### Docker Compose for Development

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  postgres:
    image: timescale/timescaledb:latest-pg14
    environment:
      POSTGRES_DB: mcp_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

  vault:
    image: vault:1.14
    command: server -dev -dev-root-token-id=dev-token
    ports:
      - "8200:8200"
    environment:
      VAULT_ADDR: http://localhost:8200
      VAULT_DEV_ROOT_TOKEN_ID: dev-token
    volumes:
      - vault_data:/vault/data

volumes:
  postgres_data:
  redis_data:
  minio_data:
  vault_data:
```

## Testing Infrastructure

### Integration Tests

```elixir
defmodule Mcp.Core.InfrastructureTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "Database Service" do
    test "database connection is healthy" do
      assert {:ok, _result} = Mcp.Core.Repo.query("SELECT 1")
    end

    test "multi-tenancy schema switching works" do
      tenant_id = UUID.uuid4()

      # Create tenant schema
      Mcp.Core.Repo.query!("CREATE SCHEMA IF NOT EXISTS tenant_#{tenant_id}")

      # Switch to tenant schema
      Mcp.Core.Repo.put_tenant_schema(tenant_id)

      # Create table in tenant schema
      Mcp.Core.Repo.query!("CREATE TABLE test_table (id serial PRIMARY KEY)")

      # Verify table exists in tenant schema
      {:ok, result} = Mcp.Core.Repo.query("SELECT * FROM test_table")
      assert result.rows == []
    end
  end

  describe "Cache Service" do
    test "cache operations work correctly" do
      key = "test_key"
      value = %{message: "test_data"}

      # Test set and get
      assert :ok = Mcp.Cache.RedisManager.set(key, value)
      assert {:ok, ^value} = Mcp.Cache.RedisManager.get(key)

      # Test delete
      assert :ok = Mcp.Cache.RedisManager.delete(key)
      assert {:ok, nil} = Mcp.Cache.RedisManager.get(key)
    end

    test "cache pattern function works" do
      key = "expensive_operation"
      call_count = 0

      expensive_operation = fn ->
        call_count = call_count + 1
        {:ok, %{result: "computed_value", call_count: call_count}}
      end

      value_ttl = fn ->
        {%{result: "computed_value", call_count: call_count + 1}, 300}
      end

      # First call - cache miss
      assert {:ok, %{call_count: 1}} = Mcp.Cache.RedisManager.cache(key, value_ttl, expensive_operation)

      # Second call - cache hit
      assert {:ok, %{call_count: 2}} = Mcp.Cache.RedisManager.cache(key, value_ttl, expensive_operation)
    end
  end

  describe "Storage Service" do
    test "file upload and download works" do
      bucket = "test-bucket"
      key = "test-file.txt"
      content = "Test file content"
      file_path = System.tmp_dir!() <> "/test-upload.txt"

      # Write test file
      File.write!(file_path, content)

      try do
        # Upload file
        assert {:ok, upload_result} = Mcp.Storage.S3Client.upload_file(bucket, key, file_path)
        assert upload_result.bucket == bucket
        assert upload_result.key == key

        # Download file
        download_path = System.tmp_dir!() <> "/test-download.txt"
        assert {:ok, _download_result} = Mcp.Storage.S3Client.download_file(bucket, key, download_path)

        # Verify content
        assert File.read!(download_path) == content
      after
        # Cleanup
        File.rm(file_path)
        File.rm(download_path)
        Mcp.Storage.S3Client.delete_file(bucket, key)
      end
    end
  end

  describe "Health Monitor" do
    test "health check returns status for all services" do
      status = Mcp.Core.HealthMonitor.get_status()

      assert Map.has_key?(status, :status)
      assert Map.has_key?(status, :checks)
      assert Map.has_key?(status, :last_check)

      checks = status.checks
      assert Map.has_key?(checks, :database)
      assert Map.has_key?(checks, :cache)
      assert Map.has_key?(checks, :storage)
      assert Map.has_key?(checks, :vault)
      assert Map.has_key?(checks, :system)
    end
  end
end
```

This developer guide provides comprehensive implementation details for the core platform infrastructure, including service setup, configuration, testing strategies, and operational procedures for building scalable, reliable systems on the MCP platform.