defmodule Mcp.Ai.OpenAiEmbeddingModel do
  @moduledoc """
  Embedding model implementation using OpenRouter (OpenAI-compatible).
  """
  use AshAi.EmbeddingModel

  @impl true
  def dimensions(_opts), do: 1536

  @impl true
  def generate(texts, _opts) do
    config = Application.get_env(:mcp, :llm)
    api_key = config[:openrouter_api_key]
    base_url = config[:openrouter_base_url]
    model = "openai/text-embedding-3-small"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "input" => texts,
      "model" => model
    }

    case Req.post("#{base_url}/embeddings", json: body, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        embeddings =
          body["data"]
          |> Enum.map(fn %{"embedding" => embedding} -> embedding end)

        {:ok, embeddings}

      {:ok, %{status: status, body: body}} ->
        {:error, "OpenRouter embedding failed: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
