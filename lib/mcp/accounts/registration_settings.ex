defmodule Mcp.Accounts.RegistrationSettings do
  @moduledoc """
  Registration settings management for tenant-level self-registration control.

  Settings are stored in the Tenant.settings map under the "registration" key.
  """

  alias Mcp.Platform.Tenant

  @default_settings %{
    "allow_self_registration" => true,
    "require_approval" => false,
    "require_email_verification" => true,
    "require_captcha" => false,
    "business_verification_required" => false,
    "default_role" => "user",
    "allowed_domains" => [],
    "blocked_domains" => [],
    "registration_fields" => ["email", "password", "name"],
    "custom_fields" => [],
    "welcome_email_enabled" => true,
    "terms_url" => nil,
    "privacy_url" => nil
  }

  @doc """
  Gets current registration settings for a tenant.

  Returns default settings if none are configured.
  """
  def get_current_settings(tenant_id) do
    case Tenant.get(tenant_id) do
      {:ok, tenant} ->
        settings = get_registration_settings_from_tenant(tenant)
        {:ok, Map.put(settings, "tenant_id", tenant_id)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Updates registration settings for a tenant.

  Merges new settings with existing settings.
  """
  def update_settings(tenant_id, new_settings) do
    case Tenant.get(tenant_id) do
      {:ok, tenant} ->
        current_tenant_settings = tenant.settings || %{}
        current_registration = Map.get(current_tenant_settings, "registration", @default_settings)

        # Merge new settings with current settings
        updated_registration = Map.merge(current_registration, new_settings)

        updated_tenant_settings =
          Map.put(current_tenant_settings, "registration", updated_registration)

        case Tenant.update(tenant, %{settings: updated_tenant_settings}) do
          {:ok, updated_tenant} ->
            settings = get_registration_settings_from_tenant(updated_tenant)
            {:ok, Map.put(settings, "tenant_id", tenant_id)}

          error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Gets registration settings by tenant ID (alias for get_current_settings).
  """
  def get_by_id(tenant_id) do
    get_current_settings(tenant_id)
  end

  @doc """
  Checks if self-registration is allowed for a tenant.
  """
  def self_registration_allowed?(tenant_id) do
    case get_current_settings(tenant_id) do
      {:ok, settings} ->
        Map.get(settings, "allow_self_registration", true)

      _ ->
        false
    end
  end

  @doc """
  Checks if email domain is allowed for registration.

  Returns true if:
  - No allowed_domains are configured (open registration)
  - Email domain is in allowed_domains list
  - Email domain is not in blocked_domains list
  """
  def email_domain_allowed?(tenant_id, email) do
    case get_current_settings(tenant_id) do
      {:ok, settings} ->
        domain = email |> String.split("@") |> List.last() |> String.downcase()

        allowed_domains = Map.get(settings, "allowed_domains", [])
        blocked_domains = Map.get(settings, "blocked_domains", [])

        cond do
          domain in blocked_domains ->
            false

          Enum.empty?(allowed_domains) ->
            true

          domain in allowed_domains ->
            true

          true ->
            false
        end

      _ ->
        false
    end
  end

  @doc """
  Checks if approval is required for new registrations.
  """
  def approval_required?(tenant_id) do
    case get_current_settings(tenant_id) do
      {:ok, settings} ->
        Map.get(settings, "require_approval", false)

      _ ->
        false
    end
  end

  @doc """
  Checks if email verification is required.
  """
  def email_verification_required?(tenant_id) do
    case get_current_settings(tenant_id) do
      {:ok, settings} ->
        Map.get(settings, "require_email_verification", true)

      _ ->
        true
    end
  end

  @doc """
  Checks if CAPTCHA is required for registration.
  """
  def captcha_required?(tenant_id) do
    case get_current_settings(tenant_id) do
      {:ok, settings} ->
        Map.get(settings, "require_captcha", false)

      _ ->
        false
    end
  end

  @doc """
  Gets the default role for new registrations.
  """
  def get_default_role(tenant_id) do
    case get_current_settings(tenant_id) do
      {:ok, settings} ->
        Map.get(settings, "default_role", "user")

      _ ->
        "user"
    end
  end

  @doc """
  Gets required registration fields.
  """
  def get_registration_fields(tenant_id) do
    case get_current_settings(tenant_id) do
      {:ok, settings} ->
        Map.get(settings, "registration_fields", ["email", "password", "name"])

      _ ->
        ["email", "password", "name"]
    end
  end

  @doc """
  Validates registration data against tenant settings.

  Returns :ok or {:error, reasons}
  """
  def validate_registration(tenant_id, registration_data) do
    with {:ok, settings} <- get_current_settings(tenant_id),
         :ok <- validate_self_registration_allowed(settings),
         :ok <- validate_email_domain(settings, registration_data["email"]),
         :ok <- validate_required_fields(settings, registration_data) do
      :ok
    else
      error -> error
    end
  end

  # Private functions

  defp get_registration_settings_from_tenant(tenant) do
    tenant_settings = tenant.settings || %{}
    Map.get(tenant_settings, "registration", @default_settings)
  end

  defp validate_self_registration_allowed(settings) do
    if Map.get(settings, "allow_self_registration", true) do
      :ok
    else
      {:error, :self_registration_disabled}
    end
  end

  defp validate_email_domain(settings, email) when is_binary(email) do
    domain = email |> String.split("@") |> List.last() |> String.downcase()

    allowed_domains = Map.get(settings, "allowed_domains", [])
    blocked_domains = Map.get(settings, "blocked_domains", [])

    cond do
      domain in blocked_domains ->
        {:error, :email_domain_blocked}

      Enum.empty?(allowed_domains) ->
        :ok

      domain in allowed_domains ->
        :ok

      true ->
        {:error, :email_domain_not_allowed}
    end
  end

  defp validate_email_domain(_settings, _email), do: {:error, :invalid_email}

  defp validate_required_fields(settings, registration_data) do
    required_fields = Map.get(settings, "registration_fields", ["email", "password"])

    missing_fields =
      Enum.filter(required_fields, fn field ->
        is_nil(registration_data[field]) or registration_data[field] == ""
      end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, {:missing_required_fields, missing_fields}}
    end
  end
end
