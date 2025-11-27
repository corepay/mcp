defmodule Mcp.Storage.S3Client do
  @moduledoc """
  S3/MinIO storage client for object storage operations.
  Handles uploads, downloads, and metadata management using ExAws.
  """

  @behaviour Mcp.Storage.StorageBehaviour

  require Logger
  alias ExAws.S3

  @impl true
  def upload_file(bucket, key, file_path, opts \\ []) do
    Logger.info("Uploading file to S3: #{bucket}/#{key}")

    if File.exists?(file_path) do
      file_path
      |> S3.Upload.stream_file()
      |> S3.upload(bucket, key, opts)
      |> ExAws.request()
      |> case do
        {:ok, _result} ->
          {:ok,
           %{
             url: public_url(bucket, key),
             key: key,
             bucket: bucket
           }}

        {:error, reason} ->
          Logger.error("Failed to upload file to S3: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :enoent}
    end
  end

  @impl true
  def download_file(bucket, key, destination_path, opts \\ []) do
    Logger.info("Downloading file from S3: #{bucket}/#{key}")

    S3.download_file(bucket, key, destination_path, opts)
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:ok, destination_path}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_file(bucket, key, opts \\ []) do
    Logger.info("Deleting file from S3: #{bucket}/#{key}")

    S3.delete_object(bucket, key, opts)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list_files(bucket, prefix \\ "", opts \\ []) do
    Logger.info("Listing files in S3: #{bucket}/#{prefix}")

    S3.list_objects(bucket, Keyword.merge(opts, prefix: prefix))
    |> ExAws.request()
    |> case do
      {:ok, %{body: %{contents: contents}}} ->
        files = Enum.map(contents, & &1.key)
        {:ok, files}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def get_file_metadata(bucket, key, opts \\ []) do
    Logger.info("Getting file metadata from S3: #{bucket}/#{key}")

    S3.head_object(bucket, key, opts)
    |> ExAws.request()
    |> case do
      {:ok, %{headers: headers}} ->
        headers_map = Map.new(headers)
        
        {:ok,
         %{
           content_type: Map.get(headers_map, "Content-Type"),
           size: Map.get(headers_map, "Content-Length"),
           last_modified: Map.get(headers_map, "Last-Modified"),
           etag: Map.get(headers_map, "ETag")
         }}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def generate_presigned_url(bucket, key, expires_in \\ 3600, opts \\ []) do
    Logger.info("Generating presigned URL for S3: #{bucket}/#{key}")
    
    config = ExAws.Config.new(:s3)
    
    case S3.presigned_url(config, :get, bucket, key, [expires_in: expires_in] ++ opts) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  defp public_url(bucket, key) do
    # Construct public URL based on configuration
    # This assumes a standard S3-style URL or MinIO URL
    host = Application.get_env(:ex_aws, :s3)[:host] || "s3.amazonaws.com"
    scheme = Application.get_env(:ex_aws, :s3)[:scheme] || "https"
    
    "#{scheme}://#{host}/#{bucket}/#{key}"
  end
end
