defmodule McpStorage.ClientFactory do
  @moduledoc """
  Storage client factory for dependency injection.
  Provides storage clients based on configuration and environment.
  Supports multiple backends with seamless switching.
  """

  @s3_client McpStorage.S3Client
  @local_client McpStorage.LocalClient
  @cdn_client McpStorage.CDNClient

  @storage_backend System.get_env("STORAGE_BACKEND", "s3")
  @cdn_enabled System.get_env("CDN_ENABLED", "false") == "true"

  def get_client do
    backend = @storage_backend
    case backend do
      "s3" -> @s3_client
      "local" -> @local_client
      _ -> raise "Unsupported storage backend: #{backend}"
    end
  end

  def get_primary_client do
    get_client()
  end

  def get_cdn_client do
    if @cdn_enabled do
      @cdn_client
    else
      nil
    end
  end

  def storage_backends do
    ["s3", "local"]
  end

  def current_backend do
    @storage_backend
  end

  def with_cdn?(fun) when is_function(fun, 1) do
    if cdn_client = get_cdn_client() do
      fun.(cdn_client)
    else
      get_client() |> fun.()
    end
  end

  def list_available_clients do
    [
      %{
        name: "s3",
        description: "Amazon S3 / MinIO compatible object storage",
        features: ["object_storage", "versioning", "lifecycle_rules", "cdn_integration"],
        default: @storage_backend == "s3"
      },
      %{
        name: "local",
        description: "Local filesystem storage",
        features: ["local_files", "simple_setup"],
        default: @storage_backend == "local"
      }
    ]
  end

  def validate_configuration do
    backend = @storage_backend
    case backend do
      "s3" -> validate_s3_config()
      "local" -> validate_local_config()
      _ -> {:error, "Invalid storage backend"}
    end
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