defmodule Mcp.Ai.SemanticCache do
  @moduledoc """
  Provides semantic caching for LLM responses using Redis.
  """
  alias Mcp.Redis

  @doc """
  Retrieves a cached response for the given prompt, model, and provider.
  Returns `{:ok, response}` if found, or `nil` if not found.
  """
  def get(prompt, model, provider) do
    key = cache_key(prompt, model, provider)
    
    case Redis.get(key) do
      {:ok, nil} -> nil
      {:ok, json_string} -> 
        case Jason.decode(json_string) do
          {:ok, decoded} -> {:ok, decoded}
          _ -> nil
        end
      _ -> nil
    end
  end

  @doc """
  Caches a response for the given prompt, model, and provider.
  TTL is set to 24 hours (86400 seconds).
  """
  def put(prompt, model, provider, response) do
    key = cache_key(prompt, model, provider)
    
    case Jason.encode(response) do
      {:ok, json_string} ->
        Redis.set(key, json_string, 86400)
      _ ->
        :error
    end
  end

  defp cache_key(prompt, model, provider) do
    # Create a deterministic hash of the prompt
    hash = :crypto.hash(:sha256, prompt) |> Base.encode16()
    "semantic_cache:#{provider}:#{model}:#{hash}"
  end
end
