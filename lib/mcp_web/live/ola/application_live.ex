defmodule McpWeb.Ola.ApplicationLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting
  alias Mcp.Underwriting.Application

  alias Mcp.Underwriting.DocumentStorage

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"]
    
    {:ok,
     socket
     |> assign(:page_title, "Merchant Application")
     |> assign(:tenant_id, tenant_id)
     |> assign(:mode, :selection) # :selection, :chat, :form
     |> assign(:step, 1)
     |> assign(:form, to_form(%{}))
     |> assign(:atlas_messages, [
       %{sender: :ai, content: "Hello! I'm Atlas. How would you like to complete your application today?"}
     ])}
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
    # Validation logic will go here
    {:noreply, assign(socket, :form, to_form(params))}
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
    # If we have a signature and we are on the last step (or submitting)
    # We should upload it.
    
    # For now, let's assume we create the application record first to get an ID
    # But we might not have an ID yet if we haven't saved.
    # We can use a temporary ID or just the tenant_id and a timestamp/random string for now
    # until we actually create the record.
    
    # In a real app, we'd probably create the Application record early (draft status).
    
    # Let's simulate saving the signature if present
    if params["signature"] && params["signature"] != "" do
      # We need an applicant_id. For now, use a placeholder or generate one.
      applicant_id = "temp_#{Ecto.UUID.generate()}" 
      
      case DocumentStorage.upload_signature(socket.assigns.tenant_id, applicant_id, params["signature"]) do
        {:ok, key} -> 
          IO.puts("Signature uploaded to: #{key}")
          # Update params with the key or store it separately
        {:error, reason} ->
          IO.inspect(reason, label: "Signature Upload Failed")
      end
    end

    # Proceed with saving application...
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_chat", %{"message" => message}, socket) do
    # 1. Add user message to chat history
    messages = socket.assigns.atlas_messages ++ [%{sender: :user, content: message}]
    
    # 2. Process message based on current context/question
    # For this mock, we'll just map the answer to the current field and move to next
    
    # Simple state machine for demo purposes
    {response, next_field, updated_form} = process_chat_input(socket.assigns.form, message)
    
    # 3. Add AI response
    messages = messages ++ [%{sender: :ai, content: response}]

    {:noreply, 
     socket 
     |> assign(:atlas_messages, messages)
     |> assign(:form, updated_form)}
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

  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, socket.assigns.step - 1)}
  end
end
