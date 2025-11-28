defmodule McpWeb.Ola.ApplicationLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.Application, as: UnderwritingApplication


  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"]
    
    {:ok,
     socket
     |> assign(:page_title, "Merchant Application")
     |> assign(:tenant_id, tenant_id)
     |> assign(:mode, :selection) # :selection, :chat, :form
     |> assign(:step, 1)
     |> assign(:form, to_form(%{}, as: :application))
      |> assign(:atlas_messages, [
        %{sender: :ai, content: "Hello! I'm Atlas. How would you like to complete your application today?"}
      ])
      |> allow_upload(:documents, accept: ~w(.jpg .jpeg .png .pdf), max_entries: 5)}
  end

  @impl true
  def handle_event("select_mode", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)
    
    messages = 
      case mode do
        :chat -> 
          [%{sender: :ai, content: "Great choice! I'll ask you a few questions to get your business approved. First, what is the legal name of your business?"}]
        :form -> 
          [%{sender: :ai, content: "No problem. I'll stay here in the sidebar if you need any help while you fill out the form."}]
      end

    {:noreply, 
     socket 
     |> assign(:mode, mode)
     |> assign(:atlas_messages, messages)}
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
     |> put_flash(:info, "Document received from mobile device!")
     |> assign(:atlas_messages, socket.assigns.atlas_messages ++ [%{sender: :ai, content: "I've received your Business License from your mobile device. Looks good!"}])}
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
    
    # Placeholder: Fetch or create a merchant for this user
    # For this demo, we'll just query the first merchant or create a dummy one if needed
    # But strictly, we should have a merchant_id from the context.
    
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
  def handle_event("send_chat", %{"message" => message}, socket) do
    # 1. Add user message to chat history
    messages = socket.assigns.atlas_messages ++ [%{sender: :user, content: message}]
    
    # 2. Process message based on current context/question
    # For this mock, we'll just map the answer to the current field and move to next
    
    # Simple state machine for demo purposes
    {response, _next_field, updated_form} = process_chat_input(socket.assigns.form, message)
    
    # 3. Add AI response
    messages = messages ++ [%{sender: :ai, content: response}]

    {:noreply, 
     socket 
     |> assign(:atlas_messages, messages)
     |> assign(:form, updated_form)}
  end



  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, socket.assigns.step - 1)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply, assign(socket, :step, socket.assigns.step + 1)}
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
end
