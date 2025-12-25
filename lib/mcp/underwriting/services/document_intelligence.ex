defmodule Mcp.Underwriting.Services.DocumentIntelligence do
  @moduledoc """
  Service for interacting with "The Eye" (Python Document Intelligence Service).
  """

  require Logger

  alias Mcp.Storage.S3Client

  @base_url "http://localhost:#{System.get_env("THE_EYE_PORT", "48291")}"

  @doc """
  Analyzes a document by sending it to the Python service.
  Supports multiple source types:
  - Local file paths
  - MinIO URLs: "minio://bucket/key"
  - S3 URLs: "s3://bucket/key"
  - HTTP/HTTPS URLs
  """
  def analyze(source, merchant_id) do
    case resolve_file_content(source) do
      {:ok, content, filename} ->
        send_to_analyzer(content, filename, merchant_id)

      {:error, reason} ->
        Logger.error("Failed to resolve file content from #{source}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Resolves file content from various source types.
  Returns {:ok, content, filename} on success, {:error, reason} on failure.
  """
  def resolve_file_content(source) when is_binary(source) do
    cond do
      String.starts_with?(source, "minio://") ->
        resolve_minio_url(source)

      String.starts_with?(source, "s3://") ->
        resolve_s3_url(source)

      String.starts_with?(source, "http://") or String.starts_with?(source, "https://") ->
        resolve_http_url(source)

      true ->
        resolve_local_file(source)
    end
  end

  defp resolve_minio_url("minio://" <> rest) do
    # Parse bucket/key from URL
    case String.split(rest, "/", parts: 2) do
      [bucket, key] ->
        case S3Client.get_object(bucket, key) do
          {:ok, content} -> {:ok, content, Path.basename(key)}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :invalid_minio_url}
    end
  end

  defp resolve_s3_url("s3://" <> rest) do
    # S3 URLs use the same format as MinIO (S3-compatible)
    case String.split(rest, "/", parts: 2) do
      [bucket, key] ->
        case S3Client.get_object(bucket, key) do
          {:ok, content} -> {:ok, content, Path.basename(key)}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :invalid_s3_url}
    end
  end

  defp resolve_http_url(url) do
    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        # Extract filename from URL or use a default
        filename = url |> URI.parse() |> Map.get(:path, "/file") |> Path.basename()
        filename = if filename == "", do: "document", else: filename
        {:ok, body, filename}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_local_file(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> {:ok, content, Path.basename(path)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :file_not_found}
    end
  end

  defp send_to_analyzer(content, filename, merchant_id) do
    case Req.post("#{@base_url}/analyze/document",
           multipart: [
             file: {content, filename}
           ]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        create_record(body, merchant_id)

      {:ok, %Req.Response{status: status}} ->
        Logger.error("Document analysis failed with status: #{status}")
        {:error, :analysis_failed}

      {:error, reason} ->
        Logger.error("Failed to connect to The Eye: #{inspect(reason)}")
        {:error, :connection_failed}
    end
  end

  defp create_record(body, merchant_id) do
    # Create the Ash record
    Mcp.Underwriting.DocumentAnalysis
    |> Ash.Changeset.for_create(:create, %{
      # Assuming success for now
      status: :completed,
      markdown_content: body["markdown_content"],
      structured_data: body["structured_data"],
      provider: String.to_atom(body["provider"]),
      merchant_id: merchant_id
    })
    |> Ash.create()
  end
end
