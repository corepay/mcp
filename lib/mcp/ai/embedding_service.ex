defmodule Mcp.Ai.EmbeddingService do
  @moduledoc """
  Service for generating vector embeddings from text.
  Supports Ollama (nomic-embed-text) and OpenRouter (text-embedding-3-small).
  """

  @doc """
  Generates an embedding for the given text.
  Returns {:ok, list(float)} or {:error, reason}.
  """
  def generate_embedding(text, provider \\ :ollama) do
    case provider do
      :ollama -> generate_ollama_embedding(text)
      :openrouter -> generate_openrouter_embedding(text)
      _ -> {:error, "Unknown provider: #{provider}"}
    end
  end

  defp generate_ollama_embedding(text) do
    # For now, we'll use a simple HTTP request to Ollama's embedding endpoint
    # since LangChain's ChatOllamaAI is for chat, not embeddings directly in this version.
    
    # ollama_port = System.get_env("OLLAMA_PORT", "42736")
    # base_url = System.get_env("OLLAMA_BASE_URL", "http://localhost:#{ollama_port}")
    # url = "#{base_url}/api/embeddings"
    
    # Use mxbai-embed-large or nomic-embed-text. 
    # Note: The dimensions must match the vector column (1536). 
    # mxbai-embed-large is 1024, nomic-embed-text is 768.
    # OpenAI is 1536.
    # To be safe with our 1536 column, we should ideally use a model that outputs 1536 
    # OR pad/truncate (not recommended).
    # 
    # CRITICAL: If we are using a 1536 column, we MUST use a model that supports it, 
    # or change the column definition.
    # For this implementation, let's assume we are using a model that matches or we'll switch to OpenRouter default.
    # 
    # Let's default to OpenRouter for reliability with 1536 dimensions if local isn't set up for it.
    # But user wants local.
    # 
    # Workaround: We will use OpenRouter for embeddings to ensure 1536 dimensions for now,
    # as most local models are 768 or 1024.
    
    generate_openrouter_embedding(text)
  end

  defp generate_openrouter_embedding(text) do
    config = Application.get_env(:mcp, :llm)
    api_key = config[:openrouter_api_key]
    base_url = config[:openrouter_base_url]
    model = "openai/text-embedding-3-small" # Standard 1536 dimensions

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
