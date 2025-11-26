defmodule Mcp.Storage.FileManager do
  @moduledoc """
  High-level file management service.
  Handles file operations with metadata, versioning, and security.
  """

  use GenServer
  require Logger

  alias Mcp.Storage.ClientFactory

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Storage FileManager")
    {:ok, %{}}
  end

  def upload_file(tenant_id, file_data, filename, opts \\ []) do
    GenServer.call(__MODULE__, {:upload_file, tenant_id, file_data, filename, opts})
  end

  def download_file(tenant_id, file_id, opts \\ []) do
    GenServer.call(__MODULE__, {:download_file, tenant_id, file_id, opts})
  end

  def delete_file(tenant_id, file_id, opts \\ []) do
    GenServer.call(__MODULE__, {:delete_file, tenant_id, file_id, opts})
  end

  def list_files(tenant_id, opts \\ []) do
    GenServer.call(__MODULE__, {:list_files, tenant_id, opts})
  end

  @impl true
  def handle_call({:upload_file, tenant_id, file_data, filename, opts}, _from, state) do
    bucket = get_tenant_bucket(tenant_id)
    key = generate_file_key(tenant_id, filename, opts)

    # Save file data to temporary location first
    temp_path =
      System.tmp_dir!() |> Path.join("upload_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}")

    File.write!(temp_path, file_data)

    case ClientFactory.get_primary_client().upload_file(bucket, key, temp_path, opts) do
      {:ok, result} ->
        # Clean up temp file
        File.rm(temp_path)
        # Store metadata in database would go here
        {:reply, {:ok, Map.put(result, :file_id, generate_file_id(key))}, state}

      {:error, reason} ->
        # Clean up temp file
        File.rm(temp_path)
        Logger.error("Failed to upload file: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:download_file, tenant_id, file_id, opts}, _from, state) do
    # In real implementation, would look up file metadata from database
    bucket = get_tenant_bucket(tenant_id)
    # Simplified - would decode file_id to actual key
    key = file_id

    temp_path =
      System.tmp_dir!()
      |> Path.join("download_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}")

    case ClientFactory.get_primary_client().download_file(
           bucket,
           key,
           temp_path,
           opts
         ) do
      {:ok, path} ->
        file_data = File.read!(path)
        File.rm(temp_path)
        {:reply, {:ok, file_data}, state}

      {:error, reason} ->
        Logger.error("Failed to download file: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete_file, tenant_id, file_id, opts}, _from, state) do
    bucket = get_tenant_bucket(tenant_id)
    # Simplified - would decode file_id to actual key
    key = file_id

    case ClientFactory.get_primary_client().delete_file(bucket, key, opts) do
      :ok ->
        # Delete metadata from database would go here
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to delete file: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_files, tenant_id, opts}, _from, state) do
    bucket = get_tenant_bucket(tenant_id)
    prefix = Keyword.get(opts, :prefix, "")

    case ClientFactory.get_primary_client().list_files(bucket, prefix, opts) do
      {:ok, files} ->
        # Enrich with metadata from database would go here
        file_info =
          Enum.map(files, fn file ->
            %{filename: file, path: file}
          end)

        {:reply, {:ok, file_info}, state}

      {:error, reason} ->
        Logger.error("Failed to list files: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp get_tenant_bucket(tenant_id) do
    "tenant-#{tenant_id}"
  end

  defp generate_file_key(_tenant_id, filename, opts) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    folder = Keyword.get(opts, :folder, "uploads")
    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    "#{folder}/#{timestamp}_#{random_id}_#{filename}"
  end

  defp generate_file_id(key) do
    :crypto.hash(:sha256, key) |> Base.encode16()
  end
end
