defmodule Mcp.Underwriting.DocumentStorage do
  @moduledoc """
  Handles document storage for the Underwriting domain.
  Stores files in MinIO with the structure: /{tenant_id}/{applicant_id}/docs/{filename}
  """

  alias Mcp.Storage

  @doc """
  Uploads a signature image from a Data URL.
  """
  def upload_signature(tenant_id, applicant_id, data_url) do
    with {:ok, binary, content_type} <- decode_data_url(data_url) do
      filename = "signature_#{DateTime.utc_now() |> DateTime.to_unix()}.#{extension_from_type(content_type)}"
      key = build_key(tenant_id, applicant_id, filename)
      
      case Storage.upload_binary(key, binary, content_type: content_type) do
        {:ok, _} -> {:ok, key}
        error -> error
      end
    end
  end

  @doc """
  Uploads a document file (e.g. from a file input).
  """
  def upload_document(tenant_id, applicant_id, %{path: path, filename: filename, content_type: content_type}) do
    key = build_key(tenant_id, applicant_id, filename)
    
    case Storage.upload_file(key, path, content_type: content_type) do
      {:ok, _} -> {:ok, key}
      error -> error
    end
  end

  defp build_key(tenant_id, applicant_id, filename) do
    "#{tenant_id}/#{applicant_id}/docs/#{filename}"
  end

  defp decode_data_url("data:" <> rest) do
    [meta, base64_data] = String.split(rest, ";base64,")
    content_type = meta
    
    case Base.decode64(base64_data) do
      {:ok, binary} -> {:ok, binary, content_type}
      :error -> {:error, :invalid_base64}
    end
  end
  defp decode_data_url(_), do: {:error, :invalid_data_url}

  defp extension_from_type("image/png"), do: "png"
  defp extension_from_type("image/jpeg"), do: "jpg"
  defp extension_from_type("image/svg+xml"), do: "svg"
  defp extension_from_type(_), do: "bin"
end
