defmodule Mcp.Ai.OpenRouter do
  @moduledoc """
  Client for interacting with OpenRouter API for Tier 2 reasoning.
  """
  require Logger

  @base_url "https://openrouter.ai/api/v1"

  def chat_completion(messages, model \\ "openai/gpt-4o") do
    api_key = System.get_env("OPENROUTER_API_KEY")

    if is_nil(api_key) do
      {:error, :missing_api_key}
    else
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"},
        {"HTTP-Referer", "https://mcp.com"}, # Required by OpenRouter
        {"X-Title", "MCP Underwriting Agent"}
      ]

      body = %{
        model: model,
        messages: messages
      }

      case Req.post("#{@base_url}/chat/completions", headers: headers, json: body) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          content = get_in(body, ["choices", Access.at(0), "message", "content"])
          {:ok, content}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("OpenRouter request failed: #{status} - #{inspect(body)}")
          {:error, :request_failed}

        {:error, reason} ->
          Logger.error("OpenRouter connection failed: #{inspect(reason)}")
          {:error, :connection_failed}
      end
    end
  end
end
