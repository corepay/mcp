defmodule Mcp.Chat.Conversation.Changes.GenerateName do
  @moduledoc """
  Generates a name for a conversation using LLM.
  """
  use Ash.Resource.Change
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Message
  alias Mcp.Chat

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      conversation = changeset.data

      messages =
        Chat.Message
        |> Ash.Query.filter(conversation_id == ^conversation.id)
        |> Ash.Query.limit(10)
        |> Ash.Query.select([:text, :source])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()

      llm_messages = build_name_generation_messages(messages)

      llm_config = Application.get_env(:mcp, :llm)
      models = llm_config[:openrouter_fallback_models] || ["google/gemini-2.0-flash-exp:free"]
      model = if is_list(models), do: List.first(models), else: models

      %{
        llm:
          ChatOpenAI.new!(%{
            model: model,
            api_key: llm_config[:openrouter_api_key],
            endpoint: "#{llm_config[:openrouter_base_url]}/chat/completions"
          }),
        custom_context: Map.new(Ash.Context.to_opts(context)),
        verbose?: true
      }
      |> LLMChain.new!()
      |> LLMChain.add_messages(llm_messages)
      |> LLMChain.run(mode: :while_needs_response)
      |> handle_llm_response(changeset)
    end)
  end

  defp build_name_generation_messages(messages) do
    system_prompt =
      Message.new_system!("""
      Provide a short name for the current conversation.
      2-8 words, preferring more succinct names.
      RESPOND WITH ONLY THE NEW CONVERSATION NAME.
      """)

    message_chain =
      Enum.map(messages, fn message ->
        if message.source == :agent do
          Message.new_assistant!(message.text)
        else
          Message.new_user!(message.text)
        end
      end)

    [system_prompt | message_chain]
  end

  defp handle_llm_response({:ok, chain}, changeset) do
    content = chain.last_message.content

    Ash.Changeset.force_change_attribute(
      changeset,
      :title,
      Message.ContentPart.content_to_string(content)
    )
  end

  defp handle_llm_response({:error, _, error}, _changeset), do: {:error, error}
end
