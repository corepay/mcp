defmodule Mcp.Storage do
  @moduledoc """
  Storage service for file uploads and object storage using MinIO (S3-compatible).
  """

  alias ExAws.S3

  @bucket_name "mcp-storage"

  # Client API

  def upload_file(key, file_path, opts \\ []) do
    case File.read(file_path) do
      {:ok, file_binary} ->
        upload_binary(key, file_binary, Keyword.put(opts, :content_type, MIME.from_path(file_path)))
      {:error, reason} ->
        {:error, :file_read_error, reason}
    end
  end

  def upload_binary(key, binary, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    acl = Keyword.get(opts, :acl, :private)

    S3.put_object(@bucket_name, key, binary, [
      {:content_type, content_type},
      {:acl, acl}
    ])
    |> ExAws.request()
  end

  def download_file(key) do
    S3.get_object(@bucket_name, key)
    |> ExAws.request()
  end

  def delete_file(key) do
    S3.delete_object(@bucket_name, key)
    |> ExAws.request()
  end

  def list_files(prefix \\ "") do
    S3.list_objects(@bucket_name, prefix: prefix)
    |> ExAws.request()
  end

  def file_url(key, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600)

    S3.presigned_url(:get, @bucket_name, key, expires_in: expires_in)
    |> ExAws.request()
  end

  def create_bucket do
    S3.put_bucket(@bucket_name, "us-east-1")
    |> ExAws.request()
  end

  def bucket_exists? do
    case S3.head_bucket(@bucket_name) |> ExAws.request() do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def ensure_bucket_exists do
    if bucket_exists?() do
      :ok
    else
      case create_bucket() do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, :bucket_creation_failed, reason}
      end
    end
  end

  # Helper functions for common use cases

  def upload_tenant_logo(tenant_id, file_path) do
    key = "tenants/#{tenant_id}/logo#{Path.extname(file_path)}"
    upload_file(key, file_path, acl: :public_read)
  end

  def upload_merchant_document(merchant_id, document_type, file_path) do
    key = "merchants/#{merchant_id}/documents/#{document_type}#{Path.extname(file_path)}"
    upload_file(key, file_path)
  end

  def upload_user_profile_picture(user_id, file_path) do
    key = "users/#{user_id}/profile#{Path.extname(file_path)}"
    upload_file(key, file_path, acl: :public_read)
  end

  def upload_ai_model_file(model_id, file_path) do
    key = "ai/models/#{model_id}#{Path.extname(file_path)}"
    upload_file(key, file_path)
  end
end