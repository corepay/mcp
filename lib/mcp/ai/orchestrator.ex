defmodule Mcp.Ai.Orchestrator do
  @moduledoc """
  Handles sequential fallback for LLM requests.
  """
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Message

  def ask(system_prompt, user_message, models \\ nil) do
    config = Application.get_env(:mcp, :llm)
    api_key = config[:openrouter_api_key]
    base_url = config[:openrouter_base_url]
    models = models || config[:openrouter_fallback_models] || ["google/gemini-2.0-flash-exp:free"]

    do_ask(models, system_prompt, user_message, api_key, base_url)
  end

  defp do_ask([model | rest], system_prompt, user_message, api_key, base_url) do
    IO.puts("🤖 AI Orchestrator: Trying #{model}...")

    try do
      llm =
        ChatOpenAI.new!(%{
          model: model,
          api_key: api_key,
          endpoint: "#{base_url}/chat/completions",
          receive_timeout: 120_000
        })

      case LLMChain.new!(%{llm: llm})
           |> LLMChain.add_messages([
             Message.new_system!(system_prompt),
             Message.new_user!(user_message)
           ])
           |> LLMChain.run(timeout: 120_000) do
        {:ok, chain} ->
          content = chain.last_message.content
          text = Message.ContentPart.content_to_string(content)
          {:ok, text}

        {:error, _, reason} ->
          handle_error(model, rest, system_prompt, user_message, api_key, base_url, reason)
      end
    rescue
      e ->
        handle_error(model, rest, system_prompt, user_message, api_key, base_url, e)
    end
  end

  defp do_ask([], _, _, _, _), do: {:error, "No models available"}

  defp handle_error(model, rest, system_prompt, user_message, api_key, base_url, error) do
    if rest == [] do
      {:error, error}
    else
      IO.warn("⚠️ AI Orchestrator: #{model} failed: #{inspect(error)}. Falling back...")
      do_ask(rest, system_prompt, user_message, api_key, base_url)
    end
  end
end
