defmodule Mcp.Chat.Message.Changes.Respond do
  @moduledoc """
  Orchestrates the LLM response generation for a chat message.
  """
  use Ash.Resource.Change
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Message
  alias LangChain.MessageDelta
  alias Mcp.Accounts.User
  alias Mcp.Ai.LlmUsage
  alias Mcp.Chat
  alias Mcp.Finance.Ledger
  alias Mcp.Platform.{ApiKey, Merchant, MID, Reseller, Tenant}
  alias Mcp.Underwriting.Application, as: UWApplication
  alias Mcp.Underwriting.Playbook
  alias Mcp.Underwriting.Tools.{AnalyzeDocument, ConsultExpert}

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      actor = augment_actor(context.actor)

      message = changeset.data

      messages =
        Chat.Message
        |> Ash.Query.filter(conversation_id == ^message.conversation_id)
        |> Ash.Query.filter(id != ^message.id)
        |> Ash.Query.select([:text, :source, :tool_calls, :tool_results])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()
        |> Enum.concat([%{source: :user, text: message.text}])

      conversation = Chat.Conversation.get_by_id!(message.conversation_id, authorize?: false)
      subject_context = load_subject_context(conversation)

      playbook =
        case Playbook.active(authorize?: false) do
          {:ok, [first | _]} -> first
          {:ok, []} -> nil
          _ -> nil
        end

      system_prompt =
        Message.new_system!(
          Chat.Persona.system_prompt(actor, %{
            subject: subject_context,
            playbook: playbook
          })
        )

      message_chain = message_chain(messages)

      new_message_id = Ash.UUIDv7.generate()

      llm_config = Application.get_env(:mcp, :llm)
      models = llm_config[:openrouter_fallback_models] || ["google/gemini-2.0-flash-exp:free"]
      model = if is_list(models), do: List.first(models), else: models

      chain =
        %{
          llm:
            ChatOpenAI.new!(%{
              model: model,
              api_key: llm_config[:openrouter_api_key],
              endpoint: "#{llm_config[:openrouter_base_url]}/chat/completions",
              receive_timeout: 120_000
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
          tools: [
            AnalyzeDocument,
            ConsultExpert,
            {Mcp.Graph.Query, :traversal},
            {Mcp.Graph.Query, :find_connected_risks}
          ],
          actor: actor
        )
        |> LLMChain.add_callback(%{
          on_llm_new_delta: &handle_llm_delta(&1, &2, new_message_id, message),
          on_message_processed: &handle_message_processed(&1, &2, new_message_id, message),
          on_llm_token_usage: &handle_token_usage(&1, &2, actor)
        })

      LLMChain.run(chain, mode: :while_needs_response, timeout: 120_000)

      changeset
    end)
  end

  defp handle_token_usage(chain, usage, actor) do
    model = chain.llm.model

    LlmUsage
    |> Ash.Changeset.for_create(:create, %{
      provider: :openrouter,
      model: model,
      prompt_tokens: usage.prompt_tokens || 0,
      completion_tokens: usage.completion_tokens || 0,
      total_tokens: usage.total_tokens || 0,
      cost:
        LlmUsage.calculate_cost(
          model,
          usage.prompt_tokens || 0,
          usage.completion_tokens || 0
        ),
      tenant_id: actor.tenant_id,
      merchant_id: actor.merchant_id
    })
    |> Ash.create!(authorize?: false)
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

  defp augment_actor(nil), do: nil

  defp augment_actor(%User{merchant_id: nil} = actor), do: actor

  defp augment_actor(%User{merchant_id: merchant_id} = actor) do
    # Try to load the merchant to determine if they are an applicant or operator
    case Merchant.get_by_id(merchant_id, authorize?: false) do
      {:ok, merchant} ->
        category = if merchant.status == :active, do: :operator, else: :applicant

        # Store in oauth_tokens as a temporary transport for the Persona module
        tokens = Map.put(actor.oauth_tokens || %{}, "merchant_category", category)
        %{actor | oauth_tokens: tokens}

      _ ->
        actor
    end
  end

  defp load_subject_context(%{subject_id: nil}), do: nil

  defp load_subject_context(%{subject_id: id, subject_type: :application}) do
    case UWApplication.get_by_id(id, authorize?: false) do
      {:ok, app} -> app
      _ -> nil
    end
  end

  defp load_subject_context(%{subject_id: id, subject_type: :merchant}) do
    case Merchant.get_by_id(id, authorize?: false) do
      {:ok, merchant} -> merchant
      _ -> nil
    end
  end

  defp load_subject_context(%{subject_id: id, subject_type: :reseller}) do
    case Reseller.get_by_id(id, authorize?: false) do
      {:ok, reseller} -> reseller
      _ -> nil
    end
  end

  defp load_subject_context(%{subject_id: id, subject_type: :mid}) do
    case MID.get_by_id(id, authorize?: false) do
      {:ok, mid} -> mid
      _ -> nil
    end
  end

  defp load_subject_context(%{subject_id: id, subject_type: :api_key}) do
    case ApiKey.get_by_id(id, authorize?: false) do
      {:ok, key} -> key
      _ -> nil
    end
  end

  defp load_subject_context(%{subject_id: id, subject_type: :ledger}) do
    case Ledger.get_by_id(id, authorize?: false) do
      {:ok, ledger} -> ledger
      _ -> nil
    end
  end

  defp load_subject_context(%{subject_id: id, subject_type: :tenant}) do
    case Tenant.get_by_id(id, authorize?: false) do
      {:ok, tenant} -> tenant
      _ -> nil
    end
  end

  defp load_subject_context(_), do: nil
end
