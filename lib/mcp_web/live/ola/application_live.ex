defmodule McpWeb.Ola.ApplicationLive do
  use McpWeb, :live_view

  alias Mcp.Chat.{Conversation, Message}
  alias Mcp.Platform.{Merchant, Tenant}
  alias Mcp.Underwriting.Application, as: UnderwritingApplication

  alias Mcp.Underwriting.{
    AgentBlueprint,
    Document,
    Engine.AgentRunner,
    Execution,
    Gateway,
    InstructionSet
  }

  require Ash.Query

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"]
    current_user = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:page_title, "Merchant Application")
      |> assign(:tenant_id, tenant_id)
      # :selection, :chat, :form
      |> assign(:mode, :selection)
      |> assign(:step, 1)
      |> assign(:form, to_form(%{}, as: :application))
      |> assign(:execution_id, nil)
      |> assign(:atlas_session_state, %{idle_seconds: 0, field_focus: nil})
      |> allow_upload(:documents, accept: ~w(.jpg .jpeg .png .pdf), max_entries: 5)
      |> allow_upload(:chat_files, accept: ~w(.jpg .jpeg .png .pdf .txt .csv), max_entries: 1)

    if current_user do
      # Find or create conversation
      conversation =
        Conversation
        |> Ash.Query.filter(user_id == ^current_user.id)
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.limit(1)
        |> Ash.read_one!()

      conversation =
        if conversation do
          conversation
        else
          Conversation
          |> Ash.Changeset.for_create(:create_for_user, %{
            title: "Application Support",
            user_id: current_user.id
          })
          |> Ash.create!()
        end

      # Load messages
      messages =
        Message
        |> Ash.Query.for_read(:for_conversation, %{conversation_id: conversation.id})
        |> Ash.read!(page: [limit: 50])

      # Subscribe to conversation updates
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mcp.PubSub, "chat:messages:#{conversation.id}")
      end

      # Try to find existing application
      tenant_schema = Tenant.get_by_id!(tenant_id).company_schema

      # We need to use a fragment or map access for jsonb
      # Ash doesn't support map access in filter easily without calculation or fragment
      # But basic map access might work if supported by data layer.
      # Actually, AshPostgres supports map access.
      # But let's try to be safe.
      # Wait, application_data is a map attribute.
      # Ash query: filter(application_data["contact_email"] == ^current_user.email)

      existing_application =
        UnderwritingApplication
        |> Ash.Query.filter(application_data["contact_email"] == ^current_user.email)
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(1)
        |> Ash.read_one(tenant: tenant_schema)
        |> case do
          {:ok, app} -> app
          _ -> nil
        end

      socket
      |> assign(:conversation_id, conversation.id)
      |> assign(:messages, Enum.reverse(messages.results))
      |> assign(:existing_application, existing_application)
    else
      # No logged-in user - use execution-based chat without conversation
      # execution_id is initialized as nil on mount, will be created lazily on first chat
      socket
      |> assign(:conversation_id, nil)
      |> assign(:messages, [])
      |> assign(:existing_application, nil)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_mode", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)

    # If switching to chat and we have a conversation, ensure we have the welcome message if empty
    messages = socket.assigns.messages

    updated_messages =
      if mode == :chat && Enum.empty?(messages) && socket.assigns[:conversation_id] do
        # We could auto-send a welcome message here if we wanted to persist it
        # For now, just relying on the view to show empty state or initial prompt
        messages
      else
        messages
      end

    {:noreply,
     socket
     |> assign(:mode, mode)
     |> assign(:messages, updated_messages)}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, socket.assigns.step - 1)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :step, socket.assigns.step + 1)}
  end

  @impl true
  def handle_event("validate", %{"application" => params}, socket) do
    existing_params = socket.assigns.form.params || %{}
    new_params = Map.merge(existing_params, params)
    {:noreply, assign(socket, :form, to_form(new_params, as: :application))}
  end

  @impl true
  def handle_event("simulate_mobile_upload", _params, socket) do
    # Mock: Simulate a file arriving from the mobile handoff
    # In reality, this would be a PubSub subscription receiving a message

    {:noreply,
     socket
     |> put_flash(:info, "Document received from mobile device!")}
  end

  @impl true
  def handle_event("save", %{"application" => params}, socket) do
    # Create the application record
    # For now, we assume we have a merchant_id in the session or create a placeholder one
    # In a real flow, the merchant would be created during registration

    # Use accumulated params from the form assign, merged with current submission
    # This ensures data from previous steps (not in DOM) is preserved
    accumulated_params = socket.assigns.form.params || %{}
    final_params = Map.merge(accumulated_params, params)

    tenant = Tenant.get_by_id!(socket.assigns.tenant_id)

    # HACK: For demo purposes, finding ANY merchant to attach to.
    # In production, `socket.assigns.current_user.merchant_id` would be used.
    merchant = Merchant.read!(tenant: tenant.company_schema) |> List.first()

    if merchant do
      case UnderwritingApplication.create(
             %{
               subject_id: merchant.id,
               subject_type: :merchant,
               status: :submitted,
               application_data: final_params
             },
             tenant: tenant.company_schema
           ) do
        {:ok, application} ->
          # Consume uploaded files
          bucket = Application.get_env(:mcp, :uploads)[:bucket]

          consume_uploaded_entries(
            socket,
            :documents,
            &handle_upload_entry(&1, &2, application, tenant, bucket)
          )

          # Trigger Async Screening
          Task.start(fn ->
            Gateway.screen_application(application.id,
              tenant: tenant.company_schema
            )
          end)

          {:noreply,
           socket
           |> put_flash(:info, "Application submitted successfully!")
           |> push_navigate(to: ~p"/online-application/login")}

        {:error, changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "No merchant account found. Please contact support.")}
    end
  end

  @impl true
  def handle_event("validate_chat", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("field_focus", %{"field" => field}, socket) do
    session_state = Map.put(socket.assigns.atlas_session_state, :field_focus, field)
    {:noreply, assign(socket, :atlas_session_state, session_state)}
  end

  @impl true
  def handle_event("field_blur", %{"field" => _field}, socket) do
    session_state = Map.put(socket.assigns.atlas_session_state, :field_focus, nil)
    {:noreply, assign(socket, :atlas_session_state, session_state)}
  end

  @impl true
  def handle_event("user_idle", %{"seconds" => seconds}, socket) do
    session_state = Map.put(socket.assigns.atlas_session_state, :idle_seconds, seconds)
    {:noreply, assign(socket, :atlas_session_state, session_state)}
  end

  @impl true
  def handle_event("send_chat", %{"message" => text}, socket) do
    if socket.assigns[:conversation_id] do
      handle_conversation_chat(socket, text)
    else
      handle_fallback_chat(socket)
    end
  end

  defp handle_conversation_chat(socket, text) do
    uploaded_files = process_chat_uploads(socket)

    if text != "" do
      create_chat_message(socket.assigns.conversation_id, text)
    end

    send_upload_notifications(socket.assigns.conversation_id, uploaded_files)

    {:noreply, socket}
  end

  defp handle_fallback_chat(socket) do
    # Ensure we have an execution for this session
    socket = ensure_execution(socket)
    execution_id = socket.assigns.execution_id

    # Run the agent
    blueprint = %AgentBlueprint{
      name: "OlaAssistant",
      description: "Application Helper",
      base_prompt: "You are Ola, a helpful underwriting assistant.",
      routing_config: %{primary_provider: :ollama, mode: :single}
    }

    instructions = %InstructionSet{
      instructions: "Assist the user with their application."
    }

    context = %{
      execution_id: execution_id,
      tenant_id: socket.assigns.current_tenant.id
    }

    # Run the agent
    case AgentRunner.run(blueprint, instructions, context) do
      {:ok, response_result} ->
        response_text =
          Map.get(response_result, "decision") || Map.get(response_result, "result") ||
            "I processed your request."

        messages =
          socket.assigns.messages ++
            [
              %{
                id: "ai-#{System.unique_integer()}",
                sender: :ai,
                source: :agent,
                text: response_text
              }
            ]

        {:noreply, assign(socket, :messages, messages)}

      result ->
        put_flash(socket, :error, "AI Error: #{inspect(result)}")
        {:noreply, socket}
    end
  end

  defp ensure_execution(socket) do
    if socket.assigns.execution_id do
      socket
    else
      execution_id = create_execution(socket)
      assign(socket, :execution_id, execution_id)
    end
  end

  defp process_chat_uploads(socket) do
    consume_uploaded_entries(socket, :chat_files, fn %{path: path}, entry ->
      upload_chat_file(socket, path, entry)
    end)
  end

  defp upload_chat_file(socket, path, entry) do
    file_name = entry.client_name
    mime_type = entry.client_type
    bucket = Application.get_env(:mcp, :uploads)[:bucket] || "underwriting-documents"

    # Try to find application for this user/tenant
    tenant = Tenant.get_by_id!(socket.assigns.tenant_id)
    application = socket.assigns[:existing_application]

    if application do
      s3_path = "applications/#{application.id}/chat/#{file_name}"

      unless Application.get_env(:mcp, :env) == :test do
        ExAws.S3.put_object(bucket, s3_path, File.read!(path)) |> ExAws.request!()
      end

      Document.create!(
        %{
          application_id: application.id,
          file_path: s3_path,
          file_name: file_name,
          mime_type: mime_type,
          document_type: :other
        },
        tenant: tenant.company_schema
      )

      {:ok, file_name}
    else
      {:ok, file_name}
    end
  end

  defp create_chat_message(conversation_id, text) do
    Message
    |> Ash.Changeset.for_create(:create, %{
      text: text,
      conversation_id: conversation_id
    })
    |> Ash.create!()
  end

  defp send_upload_notifications(conversation_id, files) do
    Enum.each(files, fn
      {:ok, file_name} ->
        create_chat_message(conversation_id, "Uploaded document: #{file_name}")

      file_name when is_binary(file_name) ->
        create_chat_message(conversation_id, "Uploaded document: #{file_name}")

      _ ->
        :ok
    end)
  end

  defp create_execution(socket) do
    # Helper to create a new execution for the session
    # In a real app, this would be tied to the Application resource
    # For now, we stub it by creating a dummy execution or just returning a UUID if AgentRunner supports it
    # But AgentRunner expects a real Execution struct or at least an ID that exists if it tries to update it.
    # Let's assume we create a transient execution.

    # For this refactor, we'll just return a UUID and ensure AgentRunner handles it or we create a real one.
    # Since we don't have the full context here, let's create a real Execution if possible.

    {:ok, execution} =
      Execution.create(%{
        tenant_id: socket.assigns.current_tenant.id,
        status: :running,
        trigger: "ola_chat"
      })

    execution.id
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{payload: message}, socket) do
    # Handle both create and update (upsert)
    messages = update_message_list(socket.assigns.messages, message)

    {:noreply, assign(socket, messages: messages, loading: false)}
  end

  defp update_message_list(messages, new_message) do
    if Enum.any?(messages, &(&1.id == new_message.id)) do
      replace_message(messages, new_message)
    else
      messages ++ [new_message]
    end
  end

  defp replace_message(messages, new_message) do
    Enum.map(messages, fn
      %{id: id} when id == new_message.id -> new_message
      msg -> msg
    end)
  end

  defp handle_upload_entry(%{path: path}, entry, application, tenant, bucket) do
    file_name = entry.client_name
    mime_type = entry.client_type
    s3_path = "applications/#{application.id}/#{file_name}"

    ExAws.S3.put_object(bucket, s3_path, File.read!(path))
    |> ExAws.request!()

    Document.create!(
      %{
        application_id: application.id,
        file_path: s3_path,
        file_name: file_name,
        mime_type: mime_type,
        document_type: :other
      },
      tenant: tenant.company_schema
    )

    {:ok, s3_path}
  end

  # Convert step number to atom for Atlas context
  defp step_atom(1), do: :business_info
  defp step_atom(2), do: :contact_info
  defp step_atom(3), do: :documents
  defp step_atom(4), do: :review
  defp step_atom(_), do: :unknown
end
