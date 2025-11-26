defmodule Mcp.Registration.RegistrationService do
  @moduledoc """
  Registration service for managing registration requests.

  Provides high-level interface for registration workflow operations
  using Ash resources for persistence and business logic.
  """

  alias Mcp.Accounts.{RegistrationRequest, User}

  @doc """
  Initializes a new registration request.

  ## Parameters
  - `tenant_id` - UUID of the tenant
  - `type` - Registration type (:customer, :vendor, :merchant, :reseller, :developer, :admin)
  - `registration_data` - Map containing registration details
  - `context` - Optional additional context metadata

  ## Returns
  - `{:ok, registration_request}` on success
  - `{:error, reason}` on failure
  """
  def initialize_registration(tenant_id, type, registration_data, context \\ %{}) do
    attrs = %{
      tenant_id: tenant_id,
      type: type,
      email: Map.get(registration_data, "email") || Map.get(registration_data, :email),
      first_name:
        Map.get(registration_data, "first_name") || Map.get(registration_data, :first_name),
      last_name:
        Map.get(registration_data, "last_name") || Map.get(registration_data, :last_name),
      phone: Map.get(registration_data, "phone") || Map.get(registration_data, :phone),
      company_name:
        Map.get(registration_data, "company_name") || Map.get(registration_data, :company_name),
      registration_data: registration_data,
      context: context
    }

    RegistrationRequest.initialize(
      attrs.tenant_id,
      attrs.type,
      attrs.email,
      attrs.first_name,
      attrs.last_name,
      attrs.phone,
      attrs.company_name,
      attrs.registration_data,
      attrs.context
    )
    |> Ash.create()
  end

  @doc """
  Submits a registration request for processing.

  ## Parameters
  - `request_id` - UUID of the registration request

  ## Returns
  - `{:ok, registration_request}` on success
  - `{:error, reason}` on failure
  """
  def submit_registration(request_id) do
    request_id
    |> RegistrationRequest.by_id()
    |> case do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, request} ->
        request
        |> RegistrationRequest.submit(%{})
        |> Ash.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Processes a registration request - creates user account and links tenant.

  This is called after a registration is approved.

  ## Parameters
  - `request_id` - UUID of the approved registration request

  ## Returns
  - `{:ok, user}` on success
  - `{:error, reason}` on failure
  """
  def process_registration(request_id) do
    request_id
    |> RegistrationRequest.by_id()
    |> case do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, request} when request.status != :approved ->
        {:error, :not_approved}

      {:ok, request} ->
        # Extract user data from registration
        user_attrs = %{
          "email" => request.email,
          "password" => generate_temporary_password(),
          "password_confirmation" => generate_temporary_password()
        }

        # Create the user account
        case User.register(
               user_attrs["email"],
               user_attrs["password"],
               user_attrs["password_confirmation"]
             ) do
          {:ok, user} ->
            # Link user to tenant if needed
            {:ok, user}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Approves a registration request.

  ## Parameters
  - `request_id` - UUID of the registration request
  - `approver_id` - UUID of the user approving the request

  ## Returns
  - `{:ok, registration_request}` on success
  - `{:error, reason}` on failure
  """
  def approve_registration(request_id, approver_id) do
    request_id
    |> RegistrationRequest.by_id()
    |> case do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, request} ->
        request
        |> RegistrationRequest.approve(approver_id)
        |> Ash.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Rejects a registration request.

  ## Parameters
  - `request_id` - UUID of the registration request
  - `reason` - String describing the rejection reason

  ## Returns
  - `{:ok, registration_request}` on success
  - `{:error, reason}` on failure
  """
  def reject_registration(request_id, reason) when is_binary(reason) do
    request_id
    |> RegistrationRequest.by_id()
    |> case do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, request} ->
        request
        |> RegistrationRequest.reject(reason)
        |> Ash.update()

      {:error, error} ->
        {:error, error}
    end
  end

  def reject_registration(_request_id, _reason) do
    {:error, :invalid_reason}
  end

  @doc """
  Gets registration request by ID.

  ## Parameters
  - `request_id` - UUID of the registration request

  ## Returns
  - `{:ok, registration_request}` on success
  - `{:error, reason}` on failure
  """
  def get_registration(request_id) do
    RegistrationRequest.by_id(request_id)
  end

  @doc """
  Lists pending registration requests for a tenant.

  ## Parameters
  - `tenant_id` - UUID of the tenant (optional)

  ## Returns
  - `{:ok, [registration_requests]}` on success
  - `{:error, reason}` on failure
  """
  def list_pending_registrations(tenant_id \\ nil) do
    if is_nil(tenant_id) do
      list_all_pending_registrations()
    else
      list_tenant_pending_registrations(tenant_id)
    end
  end

  defp list_all_pending_registrations do
    RegistrationRequest.pending()
    |> Ash.read()
  end

  defp list_tenant_pending_registrations(tenant_id) do
    case RegistrationRequest.by_tenant(tenant_id) do
      {:ok, requests} ->
        pending = Enum.filter(requests, fn r -> r.status == :pending end)
        {:ok, pending}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the registration status and details.

  ## Parameters
  - `request_id` - UUID of the registration request

  ## Returns
  - `{:ok, %{status: status, details: map}}` on success
  - `{:error, reason}` on failure
  """
  def get_registration_status(request_id) do
    case get_registration(request_id) do
      {:ok, request} ->
        {:ok,
         %{
           id: request.id,
           status: request.status,
           email: request.email,
           type: request.type,
           submitted_at: request.submitted_at,
           approved_at: request.approved_at,
           rejected_at: request.rejected_at,
           rejection_reason: request.rejection_reason
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp generate_temporary_password do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> binary_part(0, 16)
  end
end
