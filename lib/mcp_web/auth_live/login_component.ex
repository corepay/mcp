defmodule McpWeb.AuthLive.LoginComponent do
  @moduledoc """
  Reusable login component handling authentication logic.
  """
  use McpWeb, :live_component
  import Phoenix.Component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:email, "")
     |> assign(:password, "")
     |> assign(:remember_me, false)
     |> assign(:show_password, false)
     |> assign(:loading, false)
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
        <a
          href={oauth_authorize_path("google")}
          class="btn btn-outline w-full hover:bg-base-200 hover:text-base-content group"
          aria-label="Sign in with Google"
        >
          <svg class="size-5" viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              fill="#4285F4"
            />
            <path
              d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              fill="#34A853"
            />
            <path
              d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
              fill="#FBBC05"
            />
            <path
              d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
              fill="#EA4335"
            />
          </svg>
          <span class="font-medium">Google</span>
        </a>

        <a
          href={oauth_authorize_path("github")}
          class="btn btn-outline w-full hover:bg-base-200 hover:text-base-content group"
          aria-label="Sign in with GitHub"
        >
          <svg class="size-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
          </svg>
          <span class="font-medium">GitHub</span>
        </a>
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

  defp oauth_authorize_path(provider) do
    "/auth/#{provider}"
  end
end
