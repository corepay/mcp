defmodule McpWeb.Ola.RegistrationLive do
  use McpWeb, :live_view


  alias Mcp.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      {:ok, push_navigate(socket, to: ~p"/online-application")}
    else
      form =
        Mcp.Accounts.User
        |> AshPhoenix.Form.for_create(:register, as: "user", api: Mcp.Accounts)
        |> to_form()

      {:ok,
       socket
       |> assign(:page_title, "Start Application")
       |> assign(:form, form)
       |> assign(:trigger_submit, false)
       |> assign(:atlas_messages, [
         %{sender: :ai, content: "To get started, I just need to create a secure account for you. This lets you save your progress and come back later if you need to gather documents."}
       ])}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("validate", params, socket) do
    # Handle flat params (fallback)
    user_params = Map.take(params, ["email", "password", "password_confirmation"])
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    do_save(socket, params)
  end

  def handle_event("save", params, socket) do
    # Handle flat params (fallback)
    user_params = Map.take(params, ["email", "password", "password_confirmation"])
    do_save(socket, user_params)
  end

  defp do_save(socket, params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully! Please sign in.")
         |> push_navigate(to: ~p"/online-application/login?email=#{params["email"]}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end
end
