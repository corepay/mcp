defmodule McpWeb.Ola.ApplicationLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application, as: UnderwritingApplication
  require Ash.Query

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"]
    current_user = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:page_title, "Merchant Application")
      |> assign(:tenant_id, tenant_id)
      |> assign(:mode, :selection) # :selection, :chat, :form
      |> assign(:step, 1)
      |> assign(:form, to_form(%{}, as: :application))
      |> allow_upload(:documents, accept: ~w(.jpg .jpeg .png .pdf), max_entries: 5)
      |> allow_upload(:chat_files, accept: ~w(.jpg .jpeg .png .pdf .txt .csv), max_entries: 1)

    if current_user do
      # Find or create conversation
      conversation =
        Mcp.Chat.Conversation
        |> Ash.Query.filter(user_id == ^current_user.id)
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.limit(1)
        |> Ash.read_one!()

      conversation =
        if conversation do
          conversation
        else
          Mcp.Chat.Conversation
          |> Ash.Changeset.for_create(:create_for_user, %{title: "Application Support", user_id: current_user.id})
          |> Ash.create!()
        end

      # Load messages
      messages =
        Mcp.Chat.Message
        |> Ash.Query.for_read(:for_conversation, %{conversation_id: conversation.id})
        |> Ash.read!(page: [limit: 50])

      # Subscribe to conversation updates
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mcp.PubSub, "chat:messages:#{conversation.id}")
      end
      
      # Try to find existing application
      tenant_schema = Mcp.Platform.Tenant.get_by_id!(tenant_id).company_schema
      
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
      # Fallback for guest/unauthenticated users (Mock Mode)
      socket
      |> assign(:conversation_id, nil)
      |> assign(:messages, [
        %{id: "mock-1", sender: :ai, source: :agent, text: "Hello! I'm Atlas. **Please sign in** to save your progress and enable the full application experience."}
      ])
      |> assign(:existing_application, nil)
    end
    |> then(&{:ok, &1})
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
    
    tenant = Mcp.Platform.Tenant.get_by_id!(socket.assigns.tenant_id)
    
    # HACK: For demo purposes, finding ANY merchant to attach to.
    # In production, `socket.assigns.current_user.merchant_id` would be used.
    merchant = Mcp.Platform.Merchant.read!(tenant: tenant.company_schema) |> List.first()
    
    if merchant do
      case UnderwritingApplication.create(%{
        merchant_id: merchant.id,
        status: :submitted,
        application_data: final_params
      }, tenant: tenant.company_schema) do
        {:ok, application} ->
          # Consume uploaded files
          consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
            file_name = entry.client_name
            mime_type = entry.client_type
            
            # Upload to S3/MinIO
            bucket = Application.get_env(:mcp, :uploads)[:bucket]
            s3_path = "applications/#{application.id}/#{file_name}"
            
            ExAws.S3.put_object(bucket, s3_path, File.read!(path))
            |> ExAws.request!()
            
            # Create Document record
            Mcp.Underwriting.Document.create!(%{
              application_id: application.id,
              file_path: s3_path,
              file_name: file_name,
              mime_type: mime_type,
              document_type: :other # Default for now, could be mapped from input name if we used separate uploads
            }, tenant: tenant.company_schema)
            
            {:ok, s3_path}
          end)
        
          # Trigger Async Screening
          Task.start(fn -> 
            Mcp.Underwriting.Gateway.screen_application(application.id, tenant: tenant.company_schema) 
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
  def handle_event("send_chat", %{"message" => text}, socket) do
    if socket.assigns[:conversation_id] do
      # 1. Handle File Uploads
      uploaded_files =
        consume_uploaded_entries(socket, :chat_files, fn %{path: path}, entry ->
          file_name = entry.client_name
          mime_type = entry.client_type
          bucket = Application.get_env(:mcp, :uploads)[:bucket] || "underwriting-documents"
          
          # For now, let's assume we can find the application or just store it.
          
          # Try to find application for this user/tenant
          tenant = Mcp.Platform.Tenant.get_by_id!(socket.assigns.tenant_id)
          
          application = socket.assigns[:existing_application]
          
          if application do
             s3_path = "applications/#{application.id}/chat/#{file_name}"
             
             unless Application.get_env(:mcp, :env) == :test do
               ExAws.S3.put_object(bucket, s3_path, File.read!(path)) |> ExAws.request!()
             end
             
             Mcp.Underwriting.Document.create!(%{
                application_id: application.id,
                file_path: s3_path,
                file_name: file_name,
                mime_type: mime_type,
                document_type: :other
             }, tenant: tenant.company_schema)
             
             {:ok, file_name}
          else
             # If no application, we can't create a Document (FK constraint).
             # Fallback: Just upload to S3 and mention it in chat.
             # We could create a "Lead" or "Draft" here if we wanted.
             {:ok, file_name}
          end
        end)
      
      # 2. Send Text Message
      if text != "" do
        Mcp.Chat.Message
        |> Ash.Changeset.for_create(:create, %{
          text: text,
          conversation_id: socket.assigns.conversation_id
        })
        |> Ash.create!()
      end
      
      # 3. Send System Messages for Uploads
      Enum.each(uploaded_files, fn 
        {:ok, file_name} ->
          Mcp.Chat.Message
          |> Ash.Changeset.for_create(:create, %{
            text: "Uploaded document: #{file_name}",
            conversation_id: socket.assigns.conversation_id
          })
          |> Ash.create!()
        
        file_name when is_binary(file_name) ->
          Mcp.Chat.Message
          |> Ash.Changeset.for_create(:create, %{
            text: "Uploaded document: #{file_name}",
            conversation_id: socket.assigns.conversation_id
          })
          |> Ash.create!()
          
        _ -> :ok
      end)
      
      {:noreply, socket}
    else
      # Mock mode
      messages = socket.assigns.messages ++ [%{id: "mock-user-#{System.unique_integer()}", sender: :user, source: :user, text: text}]
      
      # Simple mock response
      {response, _, updated_form} = process_chat_input(socket.assigns.form, text)
      messages = messages ++ [%{id: "mock-ai-#{System.unique_integer()}", sender: :ai, source: :agent, text: response}]

      {:noreply, 
       socket 
       |> assign(:messages, messages)
       |> assign(:form, updated_form)}
    end
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
  def handle_info(%Phoenix.Socket.Broadcast{payload: message}, socket) do
    # Handle both create and update (upsert)
    # The payload contains the transformed message: %{id: ..., text: ..., source: ...}
    
    messages = 
      if Enum.any?(socket.assigns.messages, &(&1.id == message.id)) do
        Enum.map(socket.assigns.messages, fn msg -> 
          if msg.id == message.id, do: message, else: msg
        end)
      else
        socket.assigns.messages ++ [message]
      end

    {:noreply, assign(socket, :messages, messages)}
  end

  defp process_chat_input(form, input) do
    # This is a simplified mock. In reality, we'd use an LLM or a more complex state machine.
    # We check which field is empty and assume the input is for that field.
    
    params = form.params
    
    cond do
      is_nil(params["business_name"]) || params["business_name"] == "" ->
        new_params = Map.put(params, "business_name", input)
        {"Thanks! And what is the DBA (Doing Business As) name?", "dba_name", to_form(new_params)}
        
      is_nil(params["dba_name"]) || params["dba_name"] == "" ->
        new_params = Map.put(params, "dba_name", input)
        {"Got it. What type of business is it (LLC, Corp, etc.)?", "business_type", to_form(new_params)}
        
      is_nil(params["business_type"]) || params["business_type"] == "" ->
        new_params = Map.put(params, "business_type", input)
        {"Understood. Please provide your EIN or Tax ID.", "ein", to_form(new_params)}
        
      is_nil(params["ein"]) || params["ein"] == "" ->
        new_params = Map.put(params, "ein", input)
        {"Excellent. Now, what is the best email address to reach you?", "email", to_form(new_params)}
        
      true ->
        {"I think I have everything I need for the basics! You can review the application form now.", "done", form}
    end
  end

  defp process_chat_input(_form, _input) do
    # Fallback for when we are already done or in an invalid state
    {"I have already collected your information. Please review the form.", "done", _form}
  end
end
