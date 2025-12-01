defmodule McpWeb.AuthLive.LoginComponent do
  @moduledoc """
  Reusable login component handling authentication logic.
  """
  use McpWeb, :live_component
  import Phoenix.Component

  @oauth_providers ["google", "github"]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:email, "")
     |> assign(:password, "")
     |> assign(:remember_me, false)
     |> assign(:show_password, false)
     |> assign(:loading, false)
     |> assign(:oauth_providers, @oauth_providers)
     |> assign(:oauth_loading, %{})
     |> assign(:errors, %{})
     |> assign(:flash_messages, %{})
     |> assign(:login_attempts, 0)
     |> assign(:locked_until, nil)
     |> assign(:show_recovery_modal, false)
     |> assign(:recovery_email, "")
     |> assign(:password_strength, nil)
     |> assign(:show_verification_modal, false)
     |> assign(:verification_email, "")
     |> assign(:announcements, [])}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(%{}, as: :login))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="w-full">
      <div class="mb-8 text-center md:text-left">
        <h3 class="text-2xl font-bold text-base-content">Welcome back</h3>
        <p class="text-base-content/60">Please enter your details to sign in.</p>
      </div>

      <.form
        for={@form}
        id="main-login-form"
        action={~p"/sign-in"}
        method="post"
        phx-change="validate"
        phx-target={@myself}
        class="space-y-6"
      >
        <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
        <McpWeb.Portals.AuthComponents.auth_input
          field={@form[:email]}
          type="email"
          label="Email Address"
          placeholder="you@example.com"
          icon="hero-envelope"
        />

        <div class="form-control w-full">
          <label class="label font-medium">
            <span class="label-text">Password</span>
          </label>
          <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-base-content/50">
              <McpWeb.Core.CoreComponents.icon name="hero-lock-closed" class="size-5" />
            </div>
            <input
              type={if @show_password, do: "text", else: "password"}
              name={@form[:password].name}
              id={@form[:password].id}
              value={@form[:password].value}
              placeholder="••••••••"
              class={[
                "input input-bordered w-full pl-10 pr-10 focus:input-primary transition-all duration-200",
                @form[:password].errors != [] && "input-error"
              ]}
            />
            <button
              type="button"
              phx-click="toggle_password"
              phx-target={@myself}
              class="absolute inset-y-0 right-0 pr-3 flex items-center text-base-content/50 hover:text-base-content"
              aria-label={if @show_password, do: "Hide password", else: "Show password"}
            >
              <McpWeb.Core.CoreComponents.icon
                name={if @show_password, do: "hero-eye-slash", else: "hero-eye"}
                class="size-5"
              />
            </button>
          </div>
          <label
            :for={msg <- @form[:password].errors}
            class="label"
            id={@form[:password].id <> "-error"}
          >
            <span class="label-text-alt text-error">{msg}</span>
          </label>
          <div class="label">
            <span class="label-text-alt"></span>
            <a
              href="#"
              phx-click="show_recovery"
              phx-target={@myself}
              class="label-text-alt link link-primary font-medium"
            >
              Forgot password?
            </a>
          </div>
        </div>

        <div class="form-control">
          <label class="label cursor-pointer justify-start gap-3">
            <input
              type="checkbox"
              name="login[remember_me]"
              class="checkbox checkbox-primary checkbox-sm"
              checked={@remember_me}
            />
            <span class="label-text font-medium">Remember me for 30 days</span>
          </label>
        </div>

        <button
          type="submit"
          class="btn btn-primary w-full shadow-lg shadow-primary/20"
          disabled={@loading}
        >
          <span :if={@loading} class="loading loading-spinner loading-sm"></span>
          {if @loading, do: "Signing in...", else: "Sign in"}
        </button>
      </.form>

      <div class="divider text-base-content/30 text-sm font-medium">OR CONTINUE WITH</div>

      <div class="grid grid-cols-2 gap-4">
        <button
          :for={provider <- @oauth_providers}
          phx-click="oauth_login"
          phx-value-provider={provider}
          phx-target={@myself}
          class="btn btn-outline w-full hover:bg-base-200 hover:text-base-content"
          disabled={@loading || @oauth_loading[provider]}
          aria-label={"Sign in with #{String.capitalize(provider)}"}
        >
          <span :if={@oauth_loading[provider]} class="loading loading-spinner loading-xs"></span>
          <McpWeb.Core.CoreComponents.icon name="hero-globe-alt" class="size-5 mr-2" />
          {String.capitalize(provider)}
        </button>
      </div>
      
    <!-- Modals -->
      <McpWeb.Core.CoreComponents.modal
        id="recovery_modal"
        show={@show_recovery_modal}
        on_cancel="hide_recovery"
      >
        <:title>Reset Password</:title>
        <p class="py-4 text-base-content/70">
          Enter your email address and we'll send you instructions to reset your password.
        </p>
        <.form
          for={%{}}
          as={:recovery}
          id="recovery-form"
          phx-submit="request_recovery"
          phx-target={@myself}
        >
          <div class="form-control w-full mb-4">
            <input
              type="email"
              name="email"
              value={@recovery_email}
              placeholder="you@example.com"
              class="input input-bordered w-full"
              required
            />
          </div>
          <div class="modal-action">
            <button type="button" class="btn" phx-click="hide_recovery" phx-target={@myself}>
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">Send Instructions</button>
          </div>
        </.form>
      </McpWeb.Core.CoreComponents.modal>

      <div role="status" aria-live="polite" aria-atomic="true" class="sr-only">
        <p :for={announcement <- @announcements}>{announcement}</p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"login" => login_params}, socket) do
    socket =
      socket
      |> assign(:email, login_params["email"] || "")
      |> assign(:password, login_params["password"] || "")
      |> assign(:remember_me, login_params["remember_me"] == "true")
      |> validate_form(login_params)
      |> maybe_clear_errors()

    form = to_form(login_params, as: :login, errors: Enum.to_list(socket.assigns.errors))
    socket = assign(socket, :form, form)

    {:noreply, socket}
  end

  # handle_event("login") is removed as we use standard form submission now

  @impl true
  def handle_event("oauth_login", %{"provider" => provider}, socket)
      when provider in @oauth_providers do
    if rate_limited?(socket) do
      {:noreply, handle_rate_limit(socket)}
    else
      socket =
        socket
        |> assign(:oauth_loading, Map.put(socket.assigns.oauth_loading, provider, true))
        |> add_announcement("Initiating #{String.capitalize(provider)} sign in...")

      # Generate OAuth state and redirect
      state = generate_oauth_state()
      oauth_url = oauth_module().authorize_url(String.to_atom(provider), state)

      # We need to push the event to the parent LiveView to handle the redirect
      # or use push_event directly if it works from component (it should)
      socket =
        socket
        |> push_event("oauth-redirect", %{url: oauth_url, provider: provider})
        |> add_announcement("Redirecting to #{String.capitalize(provider)}...")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_password", _params, socket) do
    show_password = not socket.assigns.show_password
    action = if show_password, do: "shown", else: "hidden"

    socket =
      socket
      |> assign(:show_password, show_password)
      |> add_announcement("Password #{action}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_recovery", _params, socket) do
    socket =
      socket
      |> assign(:show_recovery_modal, true)
      |> assign(:recovery_email, socket.assigns.email)
      |> add_announcement("Password recovery dialog opened")

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_recovery", _params, socket) do
    socket =
      socket
      |> assign(:show_recovery_modal, false)
      |> assign(:recovery_email, "")
      |> add_announcement("Password recovery dialog closed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_recovery", %{"email" => email}, socket) do
    socket = assign(socket, :loading, true)

    case request_password_recovery(email) do
      :ok ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:show_recovery_modal, false)
          |> put_flash(:info, "Password recovery instructions sent to #{email}")
          |> add_announcement("Password recovery email sent")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Failed to send recovery instructions: #{reason}")
          |> add_announcement("Password recovery request failed")

        {:noreply, socket}
    end
  end

  # Private helpers (copied from Login.ex)

  defp validate_form(socket, login_params) do
    errors = %{}
    password = login_params["password"] || ""

    errors =
      if login_params["email"] &&
           not String.match?(login_params["email"] || "", ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
        Map.put(errors, :email, "Please enter a valid email address")
      else
        Map.delete(errors, :email)
      end

    errors =
      if login_params["password"] && String.length(password) < 1 do
        Map.put(errors, :password, "Password is required")
      else
        Map.delete(errors, :password)
      end

    password_strength =
      if String.length(password) > 0 do
        calculate_password_strength(password)
      else
        nil
      end

    socket
    |> assign(:errors, errors)
    |> assign(:password_strength, password_strength)
  end

  defp maybe_clear_errors(socket) do
    if socket.assigns.errors == %{} do
      assign(socket, :flash_messages, %{})
    else
      socket
    end
  end

  defp handle_rate_limit(socket) do
    socket
    |> put_flash(:error, "Please wait before trying again.")
    |> add_announcement("Rate limit exceeded. Please wait.")
  end

  defp rate_limited?(socket) do
    if socket.assigns.locked_until do
      DateTime.compare(DateTime.utc_now(), socket.assigns.locked_until) != :lt
    else
      false
    end
  end

  defp generate_oauth_state do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
    |> then(fn state -> "oauth_#{state}" end)
  end

  defp request_password_recovery(email) do
    if String.match?(email || "", ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
      :ok
    else
      {:error, "Invalid email address"}
    end
  end

  defp calculate_password_strength(password) do
    length_score = calculate_length_score(password)
    complexity_score = calculate_complexity_score(password)
    pattern_score = calculate_pattern_score(password)

    total_score = length_score + complexity_score + pattern_score

    cond do
      total_score >= 8 ->
        %{score: total_score, strength: :strong, color: "success", text: "Strong"}

      total_score >= 5 ->
        %{score: total_score, strength: :medium, color: "warning", text: "Medium"}

      total_score >= 3 ->
        %{score: total_score, strength: :weak, color: "error", text: "Weak"}

      true ->
        %{score: total_score, strength: :very_weak, color: "error", text: "Very Weak"}
    end
  end

  defp calculate_length_score(password) do
    cond do
      String.length(password) >= 12 -> 4
      String.length(password) >= 8 -> 3
      String.length(password) >= 6 -> 2
      String.length(password) >= 4 -> 1
      true -> 0
    end
  end

  defp calculate_complexity_score(password) do
    score = 0
    score = if String.match?(password, ~r/[a-z]/), do: score + 1, else: score
    score = if String.match?(password, ~r/[A-Z]/), do: score + 1, else: score
    score = if String.match?(password, ~r/[0-9]/), do: score + 1, else: score

    score =
      if String.match?(password, ~r/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/),
        do: score + 1,
        else: score

    score
  end

  defp calculate_pattern_score(password) do
    cond do
      String.match?(password, ~r/^(.)\1+$/) -> -2
      String.match?(password, ~r/^[0-9]+$/) -> -1
      String.match?(password, ~r/^[a-zA-Z]+$/) -> -1
      String.downcase(password) in ["password", "123456", "qwerty", "admin", "letmein"] -> -3
      true -> 0
    end
  end

  defp add_announcement(socket, message) do
    announcements = [message | socket.assigns.announcements] |> Enum.take(3)
    assign(socket, :announcements, announcements)
  end

  defp oauth_module do
    Application.get_env(:mcp, :oauth_module, Mcp.Accounts.OAuth)
  end
end
