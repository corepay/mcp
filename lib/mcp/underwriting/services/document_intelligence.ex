defmodule Mcp.Underwriting.Services.DocumentIntelligence do
  @moduledoc """
  Service for interacting with "The Eye" (Python Document Intelligence Service).
  """

  require Logger

  @base_url "http://localhost:#{System.get_env("THE_EYE_PORT", "48291")}"

  @doc """
  Analyzes a document by sending it to the Python service.
  """
  def analyze(file_path, merchant_id) do
    # In a real scenario, we might stream the file or send a URL if it's in Minio.
    # For now, we'll assume file_path is a local path or a URL we can read.
    # Since we are running in Docker, we might need to handle file access carefully.
    # For this implementation, we'll assume we are passing the file content or a readable stream.

    # TODO: Handle file reading properly if it's a path.
    # For now, let's assume we are passing a struct that Req can handle or we read it.
    
    # If file_path is a string and exists, read it.
    file_content = 
      if File.exists?(file_path) do
        File.read!(file_path)
      else
        # If it's not a local file, maybe it's a URL or raw content?
        # For simplicity in this step, we'll assume it's a local path that exists
        # or we return an error.
        Logger.error("File not found: #{file_path}")
        nil
      end

    if file_content do
      case Req.post("#{@base_url}/analyze/document", 
            multipart: [
              file: {
                file_content, 
                Path.basename(file_path)
              }
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
    else
      {:error, :file_not_found}
    end
  end

  defp create_record(body, merchant_id) do
    # Create the Ash record
    Mcp.Underwriting.DocumentAnalysis
    |> Ash.Changeset.for_create(:create, %{
      status: :completed, # Assuming success for now
      markdown_content: body["markdown_content"],
      structured_data: body["structured_data"],
      provider: String.to_atom(body["provider"]),
      merchant_id: merchant_id
    })
    |> Ash.create()
  end
end
