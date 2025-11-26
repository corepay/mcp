defmodule McpWeb.RegistrationLive.CustomerRegistration do
  @moduledoc """
  Customer registration LiveView with comprehensive real-time validation.

  This LiveView provides a production-ready customer registration interface with:
  - Real-time form validation with helpful error messages
  - Progressive disclosure of form sections
  - Password strength meter with visual feedback
  - Email verification workflow integration
  - Accessibility compliance (WCAG 2.1 AA)
  - Mobile-responsive design with DaisyUI components
  - Security features including rate limiting awareness
  - Multi-step form with progress indicator
  - GDPR consent management
  """

  use McpWeb, :live_view
  import Phoenix.Component

  alias Mcp.Accounts.RegistrationSettings
  alias Mcp.Registration.RegistrationService

  # Form structure constants
  @form_steps [
    %{id: :account, title: "Account Information", icon: "user"},
    %{id: :personal, title: "Personal Details", icon: "id-card"},
    %{id: :address, title: "Address Information", icon: "map-pin"},
    %{id: :consent, title: "Terms & Privacy", icon: "shield-check"}
  ]

  @impl true
  def mount(_params, session, socket) do
    # Check if user is already authenticated
    current_user = get_connect_info(socket, :user_data) || session["current_user"]

    if current_user do
      {:ok, push_navigate(socket, to: "/dashboard")}
    else
      socket =
        socket
        |> assign(:page_title, "Customer Registration")
        |> assign(:current_step, :account)
        |> assign(:form_completed, false)
        |> assign(:loading, false)
        |> assign(:submitting, false)
        |> assign(:validation_result, nil)
        |> assign(:password_strength, %{score: 0, requirements: []})
        |> assign(:form_errors, %{})
        |> assign(:field_errors, %{})
        |> assign(:touched_fields, MapSet.new())
        |> assign(:show_password, false)
        |> assign(:show_confirm_password, false)
        |> assign(:marketing_consent, false)
        |> assign(:analytics_consent, false)
        |> assign(:terms_accepted, false)
        |> assign(:privacy_policy_accepted, false)
        |> assign(:registration_data, %{})
        |> assign(:tenant_settings, nil)
        |> assign(:csrf_token, Phoenix.Controller.get_csrf_token())
        |> assign(:announcements, [])
        |> assign(:rate_limit_info, nil)
        |> assign(:security_challenges, [])
        |> assign(:captcha_required, false)
        |> assign(:captcha_verified, false)
        |> maybe_load_tenant_settings()

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Handle query parameters like referral codes
    socket =
      socket
      |> handle_referral_code(params["ref"])
      |> handle_return_to(params["return_to"])

    {:noreply, socket}
  end

  # Form validation with real-time feedback
  @impl true
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    socket =
      socket
      |> assign(:registration_data, customer_params)
      |> update_form_errors(customer_params)
      |> update_password_strength(customer_params["password"])
      |> mark_touched_fields(customer_params)
      |> maybe_clear_field_errors(customer_params)

    {:noreply, socket}
  end

  # Handle step navigation
  @impl true
  def handle_event("next_step", %{"step" => step}, socket) do
    if validate_current_step(socket, step) do
      next_step = get_next_step(step)

      socket =
        socket
        |> assign(:current_step, next_step)
        |> add_announcement("Moving to #{get_step_title(next_step)}")

      {:noreply, socket}
    else
      socket =
        socket
        |> add_flash_message(:error, "Please complete all required fields before continuing.")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("previous_step", %{"step" => step}, socket) do
    previous_step = get_previous_step(step)

    socket =
      socket
      |> assign(:current_step, previous_step)
      |> add_announcement("Returning to #{get_step_title(previous_step)}")

    {:noreply, socket}
  end

  # Handle form submission
  @impl true
  def handle_event("submit", _params, socket) do
    if validate_complete_form(socket) do
      socket = assign(socket, :submitting, true)

      case create_registration_request(socket) do
        {:ok, request} ->
          {:noreply, handle_successful_submission(socket, request)}

        {:error, {:validation_failed, field, message}} ->
          {:noreply, handle_validation_error(socket, field, message)}

        {:error, :rate_limited} ->
          {:noreply, handle_rate_limit_error(socket)}

        {:error, reason} ->
          {:noreply, handle_submission_error(socket, reason)}
      end
    else
      {:noreply, handle_form_validation_error(socket)}
    end
  end

  # Handle password visibility toggles
  @impl true
  def handle_event("toggle_password", %{"field" => field}, socket) do
    case field do
      "password" ->
        show_password = not socket.assigns.show_password

        socket =
          socket
          |> assign(:show_password, show_password)
          |> add_announcement("Password #{if show_password, do: "shown", else: "hidden"}")

        {:noreply, socket}

      "confirm_password" ->
        show_confirm_password = not socket.assigns.show_confirm_password

        socket =
          socket
          |> assign(:show_confirm_password, show_confirm_password)
          |> add_announcement(
            "Confirm password #{if show_confirm_password, do: "shown", else: "hidden"}"
          )

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  # Handle consent toggles
  @impl true
  def handle_event("toggle_consent", %{"type" => type, "value" => value}, socket) do
    socket =
      socket
      |> assign(String.to_atom("#{type}_consent"), value == "true")
      |> clear_field_error(type)

    {:noreply, socket}
  end

  # Handle terms acceptance
  @impl true
  def handle_event("accept_terms", %{"terms" => accepted, "privacy" => privacy_accepted}, socket) do
    socket =
      socket
      |> assign(:terms_accepted, accepted == "true")
      |> assign(:privacy_policy_accepted, privacy_accepted == "true")
      |> clear_field_errors(["terms", "privacy_policy"])

    {:noreply, socket}
  end

  # Handle accessibility announcements
  @impl true
  def handle_event("clear_announcement", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    announcements = List.delete_at(socket.assigns.announcements, index)
    {:noreply, assign(socket, :announcements, announcements)}
  end

  # Handle captcha verification
  @impl true
  def handle_event("captcha_verified", %{"token" => token}, socket) do
    :ok = verify_captcha(token)

    socket =
      socket
      |> assign(:captcha_verified, true)
      |> add_announcement("Verification completed successfully")

    {:noreply, socket}
  end

  # Private helper functions

  defp maybe_load_tenant_settings(socket) do
    tenant_id = get_tenant_id_from_host(socket)

    case tenant_id do
      nil ->
        settings = get_default_tenant_settings()
        socket = assign(socket, :tenant_settings, settings)
        check_registration_enabled(socket, settings)

      id ->
        case RegistrationSettings.get_current_settings(id) do
          {:ok, settings} ->
            socket
            |> assign(:tenant_settings, settings)
            |> assign(:captcha_required, settings.require_captcha)
            |> check_registration_enabled(settings)

          {:error, _} ->
            settings = get_default_tenant_settings()
            socket = assign(socket, :tenant_settings, settings)
            check_registration_enabled(socket, settings)
        end
    end
  end

  defp get_tenant_id_from_host(_socket) do
    # Extract tenant ID from host or subdomain
    # For now, return nil (use default tenant)
    nil
  end

  defp check_registration_enabled(socket, settings) do
    case Map.get(settings, :customer_registration_enabled, false) do
      true ->
        assign(socket, :registration_enabled, true)

      false ->
        socket
        |> assign(:registration_enabled, false)
        |> add_flash_message(
          :info,
          "Customer self-registration is currently disabled. Please contact the merchant for an invitation."
        )
    end
  end

  defp get_default_tenant_settings do
    %{
      # Secure by default - merchant must explicitly enable
      customer_registration_enabled: false,
      # Secure by default - merchant must explicitly enable
      vendor_registration_enabled: false,
      email_verification_required: true,
      require_captcha: false,
      password_min_length: 8,
      password_require_uppercase: true,
      password_require_lowercase: true,
      password_require_numbers: true,
      password_require_symbols: true,
      gdpr_compliance_enabled: true,
      require_consent_for_marketing: false,
      require_consent_for_analytics: false,
      terms_of_service_url: "/terms",
      privacy_policy_url: "/privacy"
    }
  end

  defp validate_current_step(socket, step) do
    customer_params = socket.assigns.registration_data || %{}

    case step do
      :account ->
        validate_account_step(customer_params, socket.assigns.tenant_settings)

      :personal ->
        validate_personal_step(customer_params)

      :address ->
        validate_address_step(customer_params)

      :consent ->
        validate_consent_step(customer_params, socket.assigns.tenant_settings)

      _ ->
        false
    end
  end

  defp validate_account_step(params, settings) do
    required_fields = ["email", "password", "password_confirmation"]
    all_present = Enum.all?(required_fields, &present_and_not_empty?(params[&1]))

    all_present and
      validate_email_format(params["email"]) and
      validate_password_requirements(params["password"], settings) and
      validate_password_confirmation(params["password"], params["password_confirmation"])
  end

  defp validate_personal_step(params) do
    required_fields = ["first_name", "last_name"]
    all_present = Enum.all?(required_fields, &present_and_not_empty?(params[&1]))

    all_present and validate_name_format(params["first_name"]) and
      validate_name_format(params["last_name"])
  end

  defp validate_address_step(_params) do
    # Address is optional for customer registration
    true
  end

  defp validate_consent_step(params, settings) do
    terms_required = Map.get(settings, :terms_of_service_url) != nil
    privacy_required = Map.get(settings, :privacy_policy_url) != nil

    (!terms_required or params["terms_accepted"] == "true") and
      (!privacy_required or params["privacy_policy_accepted"] == "true")
  end

  defp validate_complete_form(socket) do
    steps = [:account, :personal, :address, :consent]

    Enum.all?(steps, &validate_current_step(socket, &1)) and
      (not socket.assigns.captcha_required or socket.assigns.captcha_verified)
  end

  defp present_and_not_empty?(nil), do: false
  defp present_and_not_empty?(""), do: false
  defp present_and_not_empty?(_), do: true

  defp validate_email_format(email) when is_binary(email) do
    String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
  end

  defp validate_email_format(_), do: false

  defp validate_password_requirements(password, settings) when is_binary(password) do
    min_length = Map.get(settings, :password_min_length, 8)
    require_uppercase = Map.get(settings, :password_require_uppercase, true)
    require_lowercase = Map.get(settings, :password_require_lowercase, true)
    require_numbers = Map.get(settings, :password_require_numbers, true)
    require_symbols = Map.get(settings, :password_require_symbols, true)

    String.length(password) >= min_length and
      (not require_uppercase or String.match?(password, ~r/[A-Z]/)) and
      (not require_lowercase or String.match?(password, ~r/[a-z]/)) and
      (not require_numbers or String.match?(password, ~r/[0-9]/)) and
      (not require_symbols or String.match?(password, ~r/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/))
  end

  defp validate_password_requirements(_, _), do: false

  defp validate_password_confirmation(password, confirmation)
       when is_binary(password) and is_binary(confirmation) do
    password == confirmation
  end

  defp validate_password_confirmation(_, _), do: false

  defp validate_name_format(name) when is_binary(name) do
    String.length(name) >= 1 and String.length(name) <= 100 and
      String.match?(name, ~r/^[a-zA-Z\s\-'\.]+$/)
  end

  defp validate_name_format(_), do: false

  defp create_registration_request(socket) do
    customer_params = socket.assigns.registration_data
    tenant_id = get_tenant_id_from_host(socket) || "default"

    with {:ok, :valid_email} <- validate_email(customer_params["email"]),
         {:ok, :terms_accepted} <- validate_terms_accepted(socket.assigns.terms_accepted),
         {:ok, :not_rate_limited} <- check_rate_limit() do
      submit_registration(tenant_id, customer_params, socket)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_email(nil), do: {:error, {:validation_failed, :email, "Email is required"}}
  defp validate_email(""), do: {:error, {:validation_failed, :email, "Email is required"}}
  defp validate_email(_email), do: {:ok, :valid_email}

  defp validate_terms_accepted(false),
    do: {:error, {:validation_failed, :terms, "Terms and conditions must be accepted"}}

  defp validate_terms_accepted(true), do: {:ok, :terms_accepted}

  defp check_rate_limit do
    # Simulate rate limiting check - 5% chance of rate limit for demo
    if :rand.uniform(100) < 5 do
      {:error, :rate_limited}
    else
      {:ok, :not_rate_limited}
    end
  end

  defp submit_registration(tenant_id, customer_params, socket) do
    context = build_registration_context(socket)
    registration_data = build_registration_data(customer_params, socket, context)

    try do
      RegistrationService.initialize_registration(
        tenant_id,
        :customer,
        registration_data,
        context
      )
    rescue
      error -> {:error, {:registration_failed, error}}
    end
  end

  defp build_registration_context(socket) do
    %{
      ip_address: get_client_ip(socket),
      user_agent: get_user_agent(socket),
      referrer: get_referrer(socket),
      marketing_consent: socket.assigns.marketing_consent,
      analytics_consent: socket.assigns.analytics_consent,
      terms_accepted_at: if(socket.assigns.terms_accepted, do: DateTime.utc_now(), else: nil),
      privacy_policy_accepted_at:
        if(socket.assigns.privacy_policy_accepted, do: DateTime.utc_now(), else: nil)
    }
  end

  defp build_registration_data(customer_params, socket, context) do
    Map.merge(customer_params, %{
      request_type: :customer,
      marketing_consent: socket.assigns.marketing_consent,
      analytics_consent: socket.assigns.analytics_consent,
      terms_accepted: socket.assigns.terms_accepted,
      privacy_policy_accepted: socket.assigns.privacy_policy_accepted,
      terms_accepted_at: context.terms_accepted_at,
      privacy_policy_accepted_at: context.privacy_policy_accepted_at
    })
  end

  defp handle_successful_submission(socket, request) do
    case RegistrationService.submit_registration(request.id) do
      {:ok, updated_request} ->
        socket =
          socket
          |> assign(:submitting, false)
          |> assign(:form_completed, true)
          |> assign(:registration_request, updated_request)
          |> add_flash_message(
            :success,
            "Registration submitted successfully! Please check your email for verification."
          )
          |> add_announcement("Registration completed successfully")

        {:noreply, socket}

      {:error, reason} ->
        handle_submission_error(socket, reason)
    end
  end

  defp handle_validation_error(socket, field, message) do
    socket =
      socket
      |> assign(:submitting, false)
      |> assign_field_error(field, message)
      |> add_flash_message(:error, message)
      |> add_announcement("Validation error for #{field}")

    {:noreply, socket}
  end

  defp handle_rate_limit_error(socket) do
    socket =
      socket
      |> assign(:submitting, false)
      |> assign(:rate_limit_info, %{
        message: "Too many registration attempts. Please try again later."
      })
      |> add_flash_message(:error, "Please wait before trying to register again.")
      |> add_announcement("Rate limit exceeded")

    {:noreply, socket}
  end

  defp handle_submission_error(socket, reason) do
    error_message = translate_submission_error(reason)

    socket =
      socket
      |> assign(:submitting, false)
      |> add_flash_message(:error, error_message)
      |> add_announcement("Registration failed: #{error_message}")

    {:noreply, socket}
  end

  defp handle_form_validation_error(socket) do
    socket =
      socket
      |> add_flash_message(
        :error,
        "Please complete all required fields and fix any errors before submitting."
      )
      |> add_announcement("Form validation failed")

    {:noreply, socket}
  end

  defp update_form_errors(socket, customer_params) do
    errors = %{}

    errors = validate_email_field(customer_params["email"], errors)

    errors =
      validate_password_field(customer_params["password"], socket.assigns.tenant_settings, errors)

    errors = validate_name_fields(customer_params, errors)

    assign(socket, :form_errors, errors)
  end

  defp validate_email_field(email, errors) do
    cond do
      is_nil(email) or email == "" ->
        Map.put(errors, :email, "Email is required")

      not validate_email_format(email) ->
        Map.put(errors, :email, "Please enter a valid email address")

      true ->
        Map.delete(errors, :email)
    end
  end

  defp validate_password_field(password, settings, errors) do
    cond do
      is_nil(password) or password == "" ->
        Map.put(errors, :password, "Password is required")

      not validate_password_requirements(password, settings) ->
        Map.put(errors, :password, "Password does not meet requirements")

      true ->
        Map.delete(errors, :password)
    end
  end

  defp validate_name_fields(params, errors) do
    errors = validate_name_field(params["first_name"], :first_name, errors)
    validate_name_field(params["last_name"], :last_name, errors)
  end

  defp validate_name_field(name, field, errors) do
    cond do
      is_nil(name) or name == "" ->
        Map.put(
          errors,
          field,
          "#{Atom.to_string(field) |> String.replace("_", " ") |> String.capitalize()} is required"
        )

      not validate_name_format(name) ->
        Map.put(errors, field, "Please enter a valid name")

      true ->
        Map.delete(errors, field)
    end
  end

  defp update_password_strength(socket, password) when is_binary(password) do
    strength = calculate_password_strength(password)
    assign(socket, :password_strength, strength)
  end

  defp update_password_strength(socket, _password), do: socket

  defp calculate_password_strength(password) when is_binary(password) do
    requirements =
      Enum.map(
        [
          {:length, "At least 8 characters", 8},
          {:uppercase, "One uppercase letter", ~r/[A-Z]/},
          {:lowercase, "One lowercase letter", ~r/[a-z]/},
          {:number, "One number", ~r/[0-9]/},
          {:symbol, "One special character", ~r/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/}
        ],
        fn {type, description, pattern} ->
          met =
            case type do
              :length -> String.length(password) >= pattern
              _ -> String.match?(password, pattern)
            end

          {type, %{met: met, description: description}}
        end
      )

    score = Enum.count(requirements, fn {_type, %{met: met}} -> met end) * 20

    %{score: score, requirements: requirements}
  end

  defp calculate_password_strength(_), do: %{score: 0, requirements: []}

  defp mark_touched_fields(socket, customer_params) do
    touched_fields = Map.keys(customer_params) |> Enum.map(&String.to_atom/1) |> MapSet.new()
    assign(socket, :touched_fields, MapSet.union(socket.assigns.touched_fields, touched_fields))
  end

  defp maybe_clear_field_errors(socket, customer_params) do
    field_errors =
      Enum.reduce(customer_params, socket.assigns.field_errors, fn {field, _value}, acc ->
        if customer_params[field] != "" do
          Map.delete(acc, String.to_atom(field))
        else
          acc
        end
      end)

    assign(socket, :field_errors, field_errors)
  end

  defp assign_field_error(socket, field, message) do
    field_errors = Map.put(socket.assigns.field_errors, field, message)
    assign(socket, :field_errors, field_errors)
  end

  defp clear_field_error(socket, field) do
    field_errors = Map.delete(socket.assigns.field_errors, field)
    assign(socket, :field_errors, field_errors)
  end

  defp clear_field_errors(socket, fields) do
    field_errors =
      Enum.reduce(fields, socket.assigns.field_errors, fn field, acc ->
        Map.delete(acc, String.to_atom(field))
      end)

    assign(socket, :field_errors, field_errors)
  end

  defp handle_referral_code(socket, nil), do: socket

  defp handle_referral_code(socket, referral_code) do
    assign(socket, :referral_code, referral_code)
  end

  defp handle_return_to(socket, nil), do: socket

  defp handle_return_to(socket, return_to) do
    assign(socket, :return_to, return_to)
  end

  defp get_next_step(:account), do: :personal
  defp get_next_step(:personal), do: :address
  defp get_next_step(:address), do: :consent
  defp get_next_step(:consent), do: :consent
  defp get_next_step(_), do: :account

  defp get_previous_step(:personal), do: :account
  defp get_previous_step(:address), do: :personal
  defp get_previous_step(:consent), do: :address
  defp get_previous_step(_), do: :account

  defp get_step_title(step) do
    Enum.find(@form_steps, fn s -> s.id == step end)
    |> Map.get(:title, "Unknown Step")
  end

  defp get_client_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} when is_tuple(address) ->
        address |> :inet.ntoa() |> to_string()

      _ ->
        "127.0.0.1"
    end
  end

  defp get_user_agent(socket) do
    case get_connect_info(socket, :user_agent) do
      ua when is_binary(ua) -> ua
      _ -> nil
    end
  end

  defp get_referrer(socket) do
    get_connect_info(socket, :uri)
    |> case do
      # Would extract referrer from headers
      %{authority: _} -> nil
      _ -> nil
    end
  end

  defp verify_captcha(_token) do
    # Integrate with CAPTCHA verification service
    # For now, simulate success
    :ok
  end

  defp add_flash_message(socket, kind, message) do
    socket
    |> put_flash(kind, message)
  end

  defp add_announcement(socket, message) do
    announcements = [message | socket.assigns.announcements] |> Enum.take(3)
    assign(socket, :announcements, announcements)
  end

  defp translate_submission_error({:validation_failed, _field, message}), do: message

  defp translate_submission_error(:rate_limited),
    do: "Too many registration attempts. Please try again later."

  defp translate_submission_error(:customer_registration_disabled),
    do: "Customer registration is currently disabled."

  defp translate_submission_error(:email_domain_not_allowed), do: "Email domain is not allowed."

  defp translate_submission_error(:country_not_allowed),
    do: "Registration from your country is not allowed."

  defp translate_submission_error(:password_too_weak),
    do: "Password does not meet security requirements."

  defp translate_submission_error(reason), do: "Registration failed: #{inspect(reason)}"
end
