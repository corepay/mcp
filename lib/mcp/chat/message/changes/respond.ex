defmodule Mcp.Chat.Message.Changes.Respond do
  @moduledoc """
  Orchestrates the LLM response generation for a chat message.
  """
  use Ash.Resource.Change
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOllamaAI
  alias LangChain.{Message, MessageDelta}
  alias Mcp.Chat
  alias Mcp.Underwriting.Tools.{AnalyzeDocument, ConsultExpert}

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      message = changeset.data

      messages =
        Chat.Message
        |> Ash.Query.filter(conversation_id == ^message.conversation_id)
        |> Ash.Query.filter(id != ^message.id)
        |> Ash.Query.select([:text, :source, :tool_calls, :tool_results])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()
        |> Enum.concat([%{source: :user, text: message.text}])

      system_prompt =
        Message.new_system!("""
        You are Atlas, an intelligent underwriting assistant.
        Your job is to assist applicants and underwriters.
        You have access to tools to analyze uploaded documents.
        If a user uploads a document (or mentions one), use the 'analyze' tool to check it.
        """)

      message_chain = message_chain(messages)

      new_message_id = Ash.UUIDv7.generate()

      ollama_config = Application.get_env(:mcp, :ollama, [])

      %{
        llm:
          ChatOllamaAI.new!(%{
            model: ollama_config[:model] || "llama3",
            base_url: ollama_config[:base_url]
          }),
        custom_context: Map.new(Ash.Context.to_opts(context))
      }
      |> LLMChain.new!()
      |> LLMChain.add_message(system_prompt)
      |> LLMChain.add_messages(message_chain)
      # add the names of tools you want available in your conversation here.
      # i.e tools: [:lookup_weather]
      |> AshAi.setup_ash_ai(
        otp_app: :mcp,
        tools: [AnalyzeDocument, ConsultExpert],
        actor: context.actor
      )
      |> LLMChain.add_callback(%{
        on_llm_new_delta: &handle_llm_delta(&1, &2, new_message_id, message),
        on_message_processed: &handle_message_processed(&1, &2, new_message_id, message)
      })
      |> LLMChain.run(mode: :while_needs_response)

      changeset
    end)
  end

  defp message_chain(messages) do
    Enum.flat_map(messages, fn
      %{source: :agent} = message ->
        langchain_message =
          Message.new_assistant!(%{
            content: message.text,
            tool_calls:
              message.tool_calls &&
                Enum.map(
                  message.tool_calls,
                  &Message.ToolCall.new!(
                    Map.take(&1, ["status", "type", "call_id", "name", "arguments", "index"])
                  )
                )
          })

        if message.tool_results && !Enum.empty?(message.tool_results) do
          [
            langchain_message,
            Message.new_tool_result!(%{
              tool_results:
                Enum.map(
                  message.tool_results,
                  &Message.ToolResult.new!(
                    Map.take(&1, [
                      "type",
                      "tool_call_id",
                      "name",
                      "content",
                      "display_text",
                      "is_error",
                      "options"
                    ])
                  )
                )
            })
          ]
        else
          [langchain_message]
        end

      %{source: :user, text: text} ->
        [Message.new_user!(text)]
    end)
  end

  defp handle_llm_delta(_chain, deltas, new_message_id, message) do
    deltas
    |> List.wrap()
    |> Enum.each(fn delta ->
      content = MessageDelta.content_to_string(delta)

      if not is_nil(content) and content != "" do
        Chat.Message
        |> Ash.Changeset.for_create(
          :upsert_response,
          %{
            id: new_message_id,
            response_to_id: message.id,
            conversation_id: message.conversation_id,
            text: content
          },
          actor: %AshAi{}
        )
        |> Ash.create!()
      end
    end)
  end

  defp handle_message_processed(_chain, data, new_message_id, message) do
    content = Message.ContentPart.content_to_string(data.content)

    if (data.tool_calls && Enum.any?(data.tool_calls)) ||
         (data.tool_results && Enum.any?(data.tool_results)) ||
         content not in [nil, ""] do
      Chat.Message
      |> Ash.Changeset.for_create(
        :upsert_response,
        %{
          id: new_message_id,
          response_to_id: message.id,
          conversation_id: message.conversation_id,
          complete: true,
          tool_calls: process_tool_calls(data.tool_calls),
          tool_results: process_tool_results(data.tool_results),
          text: content || ""
        },
        actor: %AshAi{}
      )
      |> Ash.create!()
    end
  end

  defp process_tool_calls(nil), do: nil

  defp process_tool_calls(tool_calls) do
    Enum.map(
      tool_calls,
      &Map.take(&1, [:status, :type, :call_id, :name, :arguments, :index])
    )
  end

  defp process_tool_results(nil), do: nil

  defp process_tool_results(tool_results) do
    Enum.map(tool_results, fn result ->
      result
      |> Map.take([:type, :tool_call_id, :name, :content, :display_text, :is_error, :options])
      |> Map.update(:content, nil, &Message.ContentPart.content_to_string/1)
    end)
  end
end
