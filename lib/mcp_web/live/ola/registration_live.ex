defmodule McpWeb.Ola.RegistrationLive do
  use McpWeb, :live_view


  alias Mcp.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      {:ok, push_navigate(socket, to: ~p"/online-application")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Start Application")
       |> assign(:form, to_form(%{"email" => "", "password" => "", "password_confirmation" => ""}))
       |> assign(:trigger_submit, false)
       |> assign(:atlas_messages, [
         %{sender: :ai, content: "To get started, I just need to create a secure account for you. This lets you save your progress and come back later if you need to gather documents."}
       ])}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    # Simple validation or changeset based validation could go here
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    case User.register(params["email"], params["password"], params["password_confirmation"]) do
      {:ok, _user} ->
        # We need to log the user in. 
        # Since we can't easily set session in LiveView, we'll redirect to a controller action
        # or use a token-based approach if available. 
        # For now, let's assume we redirect to a login action that handles the session.
        
        # Actually, standard pattern is to redirect to a controller that logs them in.
        # But we don't have that controller handy. 
        # Let's try to simulate login or redirect to login page with pre-filled email.
        
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully! Please sign in.")
         |> push_navigate(to: ~p"/online-application/login?email=#{params["email"]}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
