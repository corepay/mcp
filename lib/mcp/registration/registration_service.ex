defmodule Mcp.Registration.RegistrationService do
  @moduledoc """
  Registration service helper for tests.
  """

  alias Mcp.Accounts.RegistrationRequest
  alias Mcp.Accounts.User
  require Ash.Query

  alias Mcp.Accounts.RegistrationSettings
  alias Mcp.Registration.PolicyValidator

  def initialize_registration(tenant_id, type, data, context \\ %{}) do
    with {:ok, settings} <- RegistrationSettings.get_current_settings(tenant_id),
         :ok <- PolicyValidator.validate_registration_enabled(settings, type) do
      RegistrationRequest.initialize(
        tenant_id,
        type,
        data[:email] || data["email"],
        data[:first_name] || data["first_name"],
        data[:last_name] || data["last_name"],
        data[:phone] || data["phone"],
        data[:company_name] || data["company_name"],
        data,
        context
      )
    end
  end

  def submit_registration(request_id) do
    with {:ok, request} <- RegistrationRequest.by_id(request_id) do
      RegistrationRequest.submit(request, %{})
    end
  end

  def approve_registration(request_id, approver_id) do
    with {:ok, request} <- RegistrationRequest.by_id(request_id),
         {:ok, _approved_request} <- RegistrationRequest.approve(request, approver_id) do
      process_registration(request_id)
    end
  end

  def reject_registration(request_id, reason, reviewer_id \\ nil) do
    with {:ok, request} <- RegistrationRequest.by_id(request_id) do
      RegistrationRequest.reject(request, reason, reviewer_id)
    end
  end

  def get_registration(request_id) do
    RegistrationRequest.by_id(request_id)
  end

  def get_registration_status(request_id) do
    case RegistrationRequest.by_id(request_id) do
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

      error ->
        error
    end
  end

  def list_pending_registrations(tenant_id \\ nil) do
    if tenant_id do
      RegistrationRequest
      |> Ash.Query.for_read(:by_tenant, %{tenant_id: tenant_id})
      |> Ash.Query.filter(status == :pending)
      |> Ash.read()
    else
      RegistrationRequest.pending()
    end
  end

  def process_registration(request_id) do
    with {:ok, request} <- RegistrationRequest.by_id(request_id) do
      if request.status == :approved do
        # Create user from request
        User.register(%{
          "email" => request.email,
          # Should probably generate this or handle differently
          "password" => "Temporary123!",
          "password_confirmation" => "Temporary123!",
          "first_name" => request.first_name,
          "last_name" => request.last_name,
          "tenant_id" => request.tenant_id
        })
      else
        {:error, :not_approved}
      end
    end
  end

  def register_user(data, opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id)
    requires_approval = Keyword.get(opts, :requires_approval, false)

    if requires_approval do
      with {:ok, request} <- initialize_registration(tenant_id, :customer, data) do
        submit_registration(request.id)
      end
    else
      # Direct registration
      User.register(%{
        "email" => data[:email] || data["email"],
        "password" => data[:password] || data["password"],
        "password_confirmation" => data[:password_confirmation] || data["password_confirmation"],
        "first_name" => data[:first_name] || data["first_name"],
        "last_name" => data[:last_name] || data["last_name"],
        "tenant_id" => tenant_id
      })
    end
  end
end
