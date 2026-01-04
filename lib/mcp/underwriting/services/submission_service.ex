defmodule Mcp.Underwriting.Services.SubmissionService do
  @moduledoc """
  Service for handling underwriting application submissions.
  Refactored from ApplicationLive to improve testability and separate concerns.
  """

  alias Mcp.Underwriting.{Application, Gateway}

  require Ash.Query

  @doc """
  Creates a new Underwriting Application for the given user and tenant.
  """
  def create_application(params, user, tenant) do
    merchant_id = user.merchant_id

    if merchant_id do
      # Ensure tenant is a struct or use schema if just passing options
      # Ash requires tenant option to be the schema string for multitenancy strategy: :context
      # Tenant struct passed here is Mcp.Platform.Tenant

      # Prepare params
      # Note: params key mapping depends on caller. ApplicationLive passes raw form params.
      # If params keys are strings "monthly_volume", Application resource uses them in `application_data` map?
      # Or map to attributes?
      # `Application` resource accepts `application_data`.
      # We put the whole params map into `application_data`.

      Application.create(
        %{
          subject_id: merchant_id,
          subject_type: :merchant,
          status: :submitted,
          application_data: params
        },
        tenant: tenant.company_schema
      )
    else
      {:error, :no_merchant}
    end
  end

  @doc """
  Finalizes the submission by triggering async screening.
  Should be called after file uploads are complete.
  """
  def finalize_submission(application, tenant_schema) do
    # Trigger async screening (Fire and Forget)
    # Ideally use Oban, but sticking to existing Task pattern for now as per refactor plan
    Task.start(fn ->
      Gateway.screen_application(application.id, tenant: tenant_schema)
    end)

    {:ok, application}
  end
end
