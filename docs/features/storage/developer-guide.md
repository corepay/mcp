# Object Storage & File Management System - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP storage system. Includes actual API functions, MinIO/S3 integration, tenant isolation, and file management patterns based on the real codebase.

## System Architecture

The storage system uses a multi-layered architecture:

- **Mcp.Storage**: High-level S3 wrapper with helper functions
- **FileManager**: GenServer-based file management with metadata
- **S3Client**: S3/MinIO client implementing StorageBehaviour
- **Tenant Isolation**: Per-tenant bucket separation (`tenant-{tenant_id}`)
- **Temporary File Handling**: Automatic temp file creation and cleanup

## Core Storage API

### Main Storage Module Functions

The `Mcp.Storage` module provides the primary interface:

```elixir
# Upload file from path
Storage.upload_file(key, file_path, opts \\ [])

# Upload binary data directly
Storage.upload_binary(key, binary, opts \\ [])

# Download file content
Storage.download_file(key)

# Delete file from storage
Storage.delete_file(key)

# List files with prefix filtering
Storage.list_files(prefix \\ "")

# Generate presigned URL for temporary access
Storage.file_url(key, opts \\ [])

# Bucket management
Storage.create_bucket()
Storage.bucket_exists?()
Storage.ensure_bucket_exists()
```

### Helper Functions for Common Use Cases

The storage module includes helper functions for specific scenarios:

```elixir
# Upload tenant logo with public read access
Storage.upload_tenant_logo(tenant_id, file_path)

# Upload merchant documents (private access)
Storage.upload_merchant_document(merchant_id, document_type, file_path)

# Upload user profile picture (public read access)
Storage.upload_user_profile_picture(user_id, file_path)

# Upload AI model files (private access)
Storage.upload_ai_model_file(model_id, file_path)
```

## FileManager GenServer API

### FileManager Functions

The `Mcp.Storage.FileManager` GenServer provides high-level file management:

```elixir
# Upload file with tenant isolation
FileManager.upload_file(tenant_id, file_data, filename, opts \\ [])

# Download file data by tenant and file ID
FileManager.download_file(tenant_id, file_id, opts \\ [])

# Delete file with cleanup
FileManager.delete_file(tenant_id, file_id, opts \\ [])

# List files for tenant
FileManager.list_files(tenant_id, opts \\ [])
```

### File Upload Process

The FileManager handles uploads with temporary file management:

```elixir
# Example: Upload file through FileManager
tenant_id = "acme_corp"
file_data = file_binary_content
filename = "document.pdf"

opts = [
  folder: "documents",
  content_type: "application/pdf",
  acl: :private
]

case FileManager.upload_file(tenant_id, file_data, filename, opts) do
  {:ok, %{file_id: file_id, url: url, etag: etag}} ->
    # File uploaded successfully
    IO.puts("File uploaded: #{file_id}")

  {:error, reason} ->
    # Handle upload error
    IO.puts("Upload failed: #{inspect(reason)}")
end
```

## S3Client Implementation

### StorageBehaviour Interface

The S3Client implements the StorageBehaviour protocol:

```elixir
@callback upload_file(bucket :: String.t(), key :: String.t(), file_path :: String.t(), opts :: keyword()) ::
  {:ok, map()} | {:error, term()}

@callback download_file(bucket :: String.t(), key :: String.t(), destination_path :: String.t(), opts :: keyword()) ::
  {:ok, String.t()} | {:error, term()}

@callback delete_file(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
  :ok | {:error, term()}

@callback list_files(bucket :: String.t(), prefix :: String.t(), opts :: keyword()) ::
  {:ok, list()} | {:error, term()}

@callback get_file_metadata(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
  {:ok, map()} | {:error, term()}

@callback generate_presigned_url(bucket :: String.t(), key :: String.t(), expires_in :: integer(), opts :: keyword()) ::
  {:ok, String.t()} | {:error, term()}
```

### S3Client Usage

```elixir
# Direct S3Client usage
bucket = "mcp-storage"
key = "documents/example.pdf"

# Upload file
{:ok, result} = Mcp.Storage.S3Client.upload_file(bucket, key, "/path/to/file.pdf")

# Download file
{:ok, download_path} = Mcp.Storage.S3Client.download_file(bucket, key, "/tmp/download.pdf")

# Get file metadata
{:ok, metadata} = Mcp.Storage.S3Client.get_file_metadata(bucket, key)

# Generate presigned URL
{:ok, url} = Mcp.Storage.S3Client.generate_presigned_url(bucket, key, 3600)
```

## Tenant Isolation Implementation

### Tenant Bucket Strategy

The system creates isolated buckets per tenant:

```elixir
defp get_tenant_bucket(tenant_id) do
  "tenant-#{tenant_id}"
end

# Example buckets:
# tenant-acme_corp -> tenant-acme_corp
# tenant-beta_company -> tenant-beta_company
```

### File Key Generation

Files are organized with timestamped keys:

```elixir
defp generate_file_key(_tenant_id, filename, opts) do
  timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
  folder = Keyword.get(opts, :folder, "uploads")
  random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
  "#{folder}/#{timestamp}_#{random_id}_#{filename}"
end

# Example generated keys:
# uploads/2025-11-24T10:30:45Z_A1B2C3D4_document.pdf
# documents/2025-11-24T10:31:12Z_E5F6G7H8_image.png
```

### File ID Generation

Files are identified by SHA256 hash of the key:

```elixir
defp generate_file_id(key) do
  :crypto.hash(:sha256, key) |> Base.encode16()
end
```

## Integration Examples

### Phoenix Controller File Upload

```elixir
defmodule McpWeb.UploadController do
  use McpWeb, :controller

  def upload(conn, %{"file" => upload, "folder" => folder}) do
    tenant_id = conn.assigns.current_tenant.id

    case File.read(upload.path) do
      {:ok, file_data} ->
        opts = [
          folder: folder,
          content_type: upload.content_type,
          acl: :private
        ]

        case Mcp.Storage.FileManager.upload_file(
               tenant_id,
               file_data,
               upload.filename,
               opts
             ) do
          {:ok, result} ->
            json(conn, %{success: true, file: result})

          {:error, reason} ->
            json(conn, %{success: false, error: inspect(reason)})
        end

      {:error, _reason} ->
        json(conn, %{success: false, error: "Failed to read file"})
    end
  end

  def download(conn, %{"file_id" => file_id}) do
    tenant_id = conn.assigns.current_tenant.id

    case Mcp.Storage.FileManager.download_file(tenant_id, file_id) do
      {:ok, file_data} ->
        conn
        |> put_resp_content_type("application/octet-stream")
        |> put_resp_header("content-disposition", "attachment")
        |> send_resp(200, file_data)

      {:error, reason} ->
        json(conn, %{success: false, error: inspect(reason)})
    end
  end
end
```

### LiveView File Upload

```elixir
defmodule McpWeb.FileUploadLive do
  use McpWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :uploads, [])}
  end

  @impl true
  def handle_event("save-file", %{"file" => file_data}, socket) do
    tenant_id = socket.assigns.current_tenant.id

    case Mcp.Storage.FileManager.upload_file(
           tenant_id,
           Base.decode64!(file_data["data"]),
           file_data["name"],
           [
             folder: "uploads",
             content_type: file_data["content_type"]
           ]
         ) do
      {:ok, result} ->
        uploads = [result | socket.assigns.uploads]
        {:noreply, assign(socket, :uploads, uploads)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Upload failed: #{inspect(reason)}")}
    end
  end
end
```

### Background Job File Processing

```elixir
defmodule Mcp.Jobs.ProcessFileUpload do
  use Oban.Worker
  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "file_id" => file_id}}) do
    case Mcp.Storage.FileManager.download_file(tenant_id, file_id) do
      {:ok, file_data} ->
        # Process file (e.g., virus scan, generate thumbnail, extract text)
        process_file_content(file_data)
        Logger.info("Successfully processed file: #{file_id}")

      {:error, reason} ->
        Logger.error("Failed to process file #{file_id}: #{inspect(reason)}")
    end
  end

  defp process_file_content(file_data) do
    # Add your file processing logic here
    # - Virus scanning
    # - Content validation
    # - Thumbnail generation
    # - Text extraction
    # - Metadata extraction
    :ok
  end
end
```

## Configuration and Setup

### ExAws Configuration

```elixir
# config/config.exs
config :ex_aws,
  json_codec: Jason,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION", "us-east-1")

config :ex_aws, :s3,
  scheme: "https://",
  host: System.get_env("S3_HOST", "s3.amazonaws.com"),
  port: System.get_env("S3_PORT", "443")
```

### MinIO Configuration (for development)

```elixir
# config/dev.exs
config :ex_aws,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin",
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000
```

### Storage Configuration

```elixir
# config/config.exs
config :mcp, Mcp.Storage,
  bucket_name: "mcp-storage",
  default_acl: :private,
  max_file_size: 100_000_000,  # 100MB
  allowed_extensions: [".jpg", ".jpeg", ".png", ".gif", ".pdf", ".doc", ".docx", ".txt"]
```

## Testing Storage Operations

### Unit Tests

```elixir
defmodule Mcp.Storage.FileManagerTest do
  use ExUnit.Case
  alias Mcp.Storage.FileManager

  describe "upload_file/4" do
    test "uploads file successfully" do
      tenant_id = "test_tenant"
      file_data = "test file content"
      filename = "test.txt"

      assert {:ok, %{file_id: file_id}} =
        FileManager.upload_file(tenant_id, file_data, filename)

      # Verify file ID is generated correctly
      assert is_binary(file_id)
      assert byte_size(file_id) == 64  # SHA256 hex length
    end

    test "creates correct file key with timestamp" do
      # This would test the internal key generation logic
      # In practice, you'd verify the key structure matches expectations
    end
  end

  describe "download_file/3" do
    test "downloads uploaded file" do
      tenant_id = "test_tenant"
      file_data = "test content"
      filename = "test.txt"

      # Upload first
      {:ok, %{file_id: file_id}} =
        FileManager.upload_file(tenant_id, file_data, filename)

      # Then download
      assert {:ok, ^file_data} = FileManager.download_file(tenant_id, file_id)
    end

    test "returns error for non-existent file" do
      tenant_id = "test_tenant"
      file_id = "nonexistent_file_id"

      assert {:error, _reason} = FileManager.download_file(tenant_id, file_id)
    end
  end
end
```

### Integration Tests

```elixir
defmodule Mcp.StorageIntegrationTest do
  use ExUnit.Case, async: false

  describe "storage operations" do
    test "end-to-end file upload and download" do
      # Create test file
      test_file_path = System.tmp_dir!() |> Path.join("test_file.txt")
      File.write!(test_file_path, "test content")

      # Upload using Storage module
      key = "test/Integration/file.txt"
      assert {:ok, _result} = Mcp.Storage.upload_file(key, test_file_path)

      # Download and verify content
      assert {:ok, %{body: content}} = Mcp.Storage.download_file(key)
      assert content == "test content"

      # Clean up
      Mcp.Storage.delete_file(key)
      File.rm(test_file_path)
    end

    test "presigned URL generation" do
      key = "test/presigned/file.txt"

      # Create file first
      Mcp.Storage.upload_binary(key, "test content")

      # Generate presigned URL
      assert {:ok, url} = Mcp.Storage.file_url(key, expires_in: 3600)
      assert String.contains?(url, "signature=")

      # Clean up
      Mcp.Storage.delete_file(key)
    end
  end
end
```

## Performance Considerations

### File Upload Optimization

- **Temporary File Management**: Automatic cleanup of temporary files
- **Concurrent Uploads**: GenServer handles multiple simultaneous uploads
- **Memory Efficiency**: Streams large files to avoid memory issues
- **Error Handling**: Robust error handling with cleanup

### Storage Optimization

- **Compression**: Consider compression for text files
- **Content-Type Detection**: Automatic MIME type detection
- **File Size Limits**: Configurable maximum file size limits
- **Extension Validation**: Allowed file extension checking

### Monitoring and Observability

```elixir
# Add telemetry events
:telemetry.execute([:mcp, :storage, :upload], %{
  size: file_size,
  tenant_id: tenant_id
}, %{
  file_type: file_type,
  bucket: bucket
})
```

This developer guide provides comprehensive technical implementation details for the MCP storage system, including actual API usage patterns, tenant isolation, GenServer architecture, and integration examples based on the real MinIO/S3-compatible storage implementation.