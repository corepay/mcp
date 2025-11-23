defmodule Mcp.Storage.LocalClient do
  @moduledoc """
  Local filesystem storage client.
  Handles file operations on local disk for development/testing.
  """

  @behaviour Mcp.Storage.StorageBehaviour

  require Logger

  @storage_path System.get_env("LOCAL_STORAGE_PATH", "priv/storage")

  @impl true
  def upload_file(_bucket, key, file_path, _opts \\ []) do
    Logger.info("Uploading file locally: #{key}")

    destination = Path.join(@storage_path, key)
    destination_dir = Path.dirname(destination)

    with :ok <- File.mkdir_p(destination_dir),
         {:ok, _bytes} <- File.copy(file_path, destination) do
      {:ok,
       %{
         url: "file://#{destination}",
         path: destination,
         size: :filelib.file_size(file_path)
       }}
    else
      error ->
        Logger.error("Failed to upload local file: #{inspect(error)}")
        error
    end
  end

  @impl true
  def download_file(_bucket, key, destination_path, _opts \\ []) do
    Logger.info("Downloading local file: #{key}")

    source = Path.join(@storage_path, key)

    case File.cp(source, destination_path) do
      :ok -> {:ok, destination_path}
      error -> error
    end
  end

  @impl true
  def delete_file(_bucket, key, _opts \\ []) do
    Logger.info("Deleting local file: #{key}")

    file_path = Path.join(@storage_path, key)

    case File.rm(file_path) do
      :ok -> :ok
      # File already deleted
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  @impl true
  def list_files(_bucket, prefix \\ "", _opts \\ []) do
    Logger.info("Listing local files: #{prefix}")

    search_path = Path.join(@storage_path, prefix)

    case Path.wildcard("#{search_path}/**/*") do
      paths when is_list(paths) ->
        files = Enum.filter(paths, &File.regular?/1)
        relative_paths = Enum.map(files, &Path.relative_to(&1, @storage_path))
        {:ok, relative_paths}

      error ->
        error
    end
  end

  @impl true
  def get_file_metadata(_bucket, key, _opts \\ []) do
    Logger.info("Getting local file metadata: #{key}")

    file_path = Path.join(@storage_path, key)

    case File.stat(file_path) do
      {:ok, stat} ->
        {:ok,
         %{
           content_type: MIME.from_path(file_path),
           size: stat.size,
           last_modified: DateTime.from_unix!(stat.mtime, :second),
           etag: "#{stat.size}-#{stat.mtime}"
         }}

      error ->
        error
    end
  end
end
