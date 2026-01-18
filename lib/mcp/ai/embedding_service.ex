defmodule Mcp.Ai.EmbeddingService do
  @moduledoc """
  Service for generating vector embeddings from text via OpenRouter.
  """

  @doc """
  Generates an embedding for the given text.
  Returns {:ok, list(float)} or {:error, reason}.
  """
  def generate_embedding(text, _provider) do
    generate_openrouter_embedding(text)
  end

  def generate_embedding(text) do
    generate_openrouter_embedding(text)
  end

  defp generate_openrouter_embedding(text) do
    config = Application.get_env(:mcp, :llm)
    api_key = config[:openrouter_api_key]
    base_url = config[:openrouter_base_url]
    # Standard 1536 dimensions
    model = "openai/text-embedding-3-small"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      model: model,
      input: text
    }

    case Req.post("#{base_url}/embeddings", headers: headers, json: body) do
      {:ok, %{status: 200, body: body}} ->
        embedding = List.first(body["data"])["embedding"]
        {:ok, embedding}

      {:ok, %{status: status, body: body}} ->
        {:error, "OpenRouter embedding failed: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
end
