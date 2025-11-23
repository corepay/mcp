defmodule Mcp.Storage.ClientFactory do
  @moduledoc """
  Storage client factory for dependency injection.
  Provides storage clients based on configuration and environment.
  Supports multiple backends with seamless switching.
  """

  use GenServer
  require Logger

  @s3_client Mcp.Storage.S3Client
  @local_client Mcp.Storage.LocalClient
  @cdn_client Mcp.Storage.CDNClient

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    storage_backend = System.get_env("STORAGE_BACKEND", "s3")
    cdn_enabled = System.get_env("CDN_ENABLED", "false") == "true"

    state = %{
      storage_backend: storage_backend,
      cdn_enabled: cdn_enabled
    }

    Logger.info(
      "Starting Storage ClientFactory with backend: #{storage_backend}, CDN: #{cdn_enabled}"
    )

    {:ok, state}
  end

  def get_client do
    GenServer.call(__MODULE__, :get_client)
  end

  def get_primary_client do
    GenServer.call(__MODULE__, :get_primary_client)
  end

  def get_cdn_client do
    GenServer.call(__MODULE__, :get_cdn_client)
  end

  def storage_backends do
    ["s3", "local"]
  end

  def current_backend do
    GenServer.call(__MODULE__, :current_backend)
  end

  def with_cdn?(fun) when is_function(fun, 1) do
    if cdn_client = get_cdn_client() do
      fun.(cdn_client)
    else
      get_client() |> fun.()
    end
  end

  def list_available_clients do
    GenServer.call(__MODULE__, :list_available_clients)
  end

  def validate_configuration do
    GenServer.call(__MODULE__, :validate_configuration)
  end

  # GenServer callbacks

  @impl true
  def handle_call(:get_client, _from, state) do
    backend = state.storage_backend

    client =
      case backend do
        "s3" -> @s3_client
        "local" -> @local_client
        _ -> raise "Unsupported storage backend: #{backend}"
      end

    {:reply, client, state}
  end

  @impl true
  def handle_call(:get_primary_client, from, state) do
    handle_call(:get_client, from, state)
  end

  @impl true
  def handle_call(:get_cdn_client, _from, state) do
    client =
      if state.cdn_enabled do
        @cdn_client
      else
        nil
      end

    {:reply, client, state}
  end

  @impl true
  def handle_call(:current_backend, _from, state) do
    {:reply, state.storage_backend, state}
  end

  @impl true
  def handle_call(:list_available_clients, _from, state) do
    clients = [
      %{
        name: "s3",
        description: "Amazon S3 / MinIO compatible object storage",
        features: ["object_storage", "versioning", "lifecycle_rules", "cdn_integration"],
        default: state.storage_backend == "s3"
      },
      %{
        name: "local",
        description: "Local filesystem storage",
        features: ["local_files", "simple_setup"],
        default: state.storage_backend == "local"
      }
    ]

    {:reply, clients, state}
  end

  @impl true
  def handle_call(:validate_configuration, _from, state) do
    result =
      case state.storage_backend do
        "s3" -> validate_s3_config()
        "local" -> validate_local_config()
        _ -> {:error, "Invalid storage backend"}
      end

    {:reply, result, state}
  end

  defp validate_s3_config do
    required_envs = ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_REGION"]
    missing = Enum.filter(required_envs, &is_nil(System.get_env(&1)))

    case missing do
      [] -> :ok
      _ -> {:error, "Missing S3 configuration: #{Enum.join(missing, ", ")}"}
    end
  end

  defp validate_local_config do
    storage_path = System.get_env("LOCAL_STORAGE_PATH", "priv/storage")

    case File.mkdir_p(storage_path) do
      :ok -> :ok
      {:error, _} -> {:error, "Cannot create storage directory: #{storage_path}"}
    end
  end
end
