defmodule Mcp.Gdpr.Compliance do
  @moduledoc """
  Main GDPR compliance module providing the primary interface for all GDPR operations.

  This module serves as the central point for GDPR compliance functionality including:
  - User soft deletion and retention management
  - Data export and portability
  - Consent management
  - Audit trail tracking
  - Anonymization processes

  All GDPR operations should be initiated through this module to ensure proper
  audit logging and compliance tracking.
  """

  alias Mcp.Gdpr.{AuditTrail, DataRetention, Anonymizer, Export, Consent}
  alias Mcp.Accounts.UserSchema
  alias Mcp.Repo
  import Ecto.Query

  @deletion_retention_days 90

  @doc """
  Initiates user deletion request with soft delete and retention scheduling.

  ## Parameters
  - user_id: UUID of the user to delete
  - reason: String indicating deletion reason (default: "user_request")
  - actor_id: UUID of the user performing the action (for audit)
  - opts: Additional options

  ## Returns
  - {:ok, user} on successful deletion request
  - {:error, reason} on failure

  ## Examples
      iex> Gdpr.Compliance.request_user_deletion(user_uuid, "user_request")
      {:ok, %User{status: :deleted}}
  """
  def request_user_deletion(user_id, reason \\ "user_request", actor_id \\ nil, _opts \\ []) do
    Repo.transaction(fn ->
      with {:ok, user} <- soft_delete_user(user_id, reason),
           {:ok, _audit} <- AuditTrail.log_action(user_id, "delete_request", actor_id, %{
             reason: reason,
             retention_expires_at: user.gdpr_retention_expires_at
           }),
           {:ok, _schedule} <- schedule_retention_cleanup(user_id, @deletion_retention_days),
           {:ok, _export} <- generate_final_data_export(user_id) do
        user
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Requests data export for a user in specified format.

  ## Parameters
  - user_id: UUID of the user
  - format: Export format ("json", "csv", "xml")
  - actor_id: UUID of the user performing the action (for audit)

  ## Returns
  - {:ok, export} on successful export request
  - {:error, reason} on failure
  """
  def request_user_data_export(user_id, format \\ "json", actor_id \\ nil) do
    case Mcp.Gdpr.Jobs.enqueue_data_export(user_id, format, actor_id) do
      {:ok, export} ->
        # Log the export request for audit trail
        AuditTrail.log_action(user_id, "export_request", actor_id, %{
          format: format,
          export_id: export.id
        })

        {:ok, export}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Records or updates user consent for a specific purpose.

  ## Parameters
  - user_id: UUID of the user
  - purpose: Consent purpose (marketing, analytics, etc.)
  - status: Consent status ("granted", "denied", "withdrawn")
  - actor_id: UUID of the user performing the action (for audit)

  ## Returns
  - {:ok, consent} on successful consent update
  - {:error, reason} on failure
  """
  def update_user_consent(user_id, purpose, status, actor_id \\ nil) do
    with {:ok, consent} <- Consent.record_consent(user_id, purpose, status, actor_id),
         {:ok, _audit} <- AuditTrail.log_action(user_id, "consent_updated", actor_id, %{
           purpose: purpose,
           status: status,
           consent_id: consent.id
         }) do
      {:ok, consent}
    end
  end

  @doc """
  Retrieves all GDPR audit records for a user.

  ## Parameters
  - user_id: UUID of the user
  - limit: Maximum number of records to return (default: 100)

  ## Returns
  - {:ok, audits} on successful retrieval
  - {:error, reason} on failure
  """
  def get_user_audit_trail(user_id, limit \\ 100) do
    AuditTrail.get_user_actions(user_id, limit)
  end

  @doc """
  Retrieves all active consents for a user.

  ## Parameters
  - user_id: UUID of the user

  ## Returns
  - {:ok, consents} on successful retrieval
  - {:error, reason} on failure
  """
  def get_user_consents(user_id) do
    Consent.get_user_consents(user_id)
  end

  @doc """
  Anonymizes user data after retention period expires.

  ## Parameters
  - user_id: UUID of the user
  - opts: Additional options for anonymization

  ## Returns
  - {:ok, result} on successful anonymization
  - {:error, reason} on failure
  """
  def anonymize_user_data(user_id, opts \\ []) do
    Repo.transaction(fn ->
      # Find user that is marked for deletion
      user = Repo.get(UserSchema, user_id)

      case user do
        nil ->
          Repo.rollback(:user_not_found)
        %UserSchema{status: "deleted"} ->
          with {:ok, _audit} <- AuditTrail.log_action(user_id, "anonymization_started", nil, %{}),
               {:ok, _result} <- Anonymizer.anonymize_user(user_id, opts),
               {:ok, _audit} <- AuditTrail.log_action(user_id, "anonymization_complete", nil, %{}) do
            {:ok, :anonymized}
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        _ ->
          Repo.rollback(:user_not_deleted)
      end
    end)
  end

  @doc """
  Gets all users that are overdue for anonymization.

  ## Returns
  - List of user records that should be anonymized
  """
  def get_users_overdue_for_anonymization do
    UserSchema
    |> where([u], u.status == "deleted")
    |> where([u], u.gdpr_retention_expires_at < ^DateTime.utc_now())
    |> Repo.all()
  end

  @doc """
  Generates a comprehensive compliance report.

  ## Parameters
  - opts: Additional options for report generation

  ## Returns
  - {:ok, report} on successful report generation
  - {:error, reason} on failure
  """
  def generate_compliance_report(_opts \\ []) do
    try do
      # TODO: Implement comprehensive compliance report
      report = %{
        total_users: 0,
        deleted_users: 0,
        anonymized_users: 0,
        active_consents: 0,
        pending_exports: 0,
        compliance_score: 100.0,
        generated_at: DateTime.utc_now()
      }
      {:ok, report}
    rescue
      error -> {:error, {:compliance_report_failed, error}}
    end
  end

  @doc """
  Cancels a pending user deletion request.

  ## Parameters
  - user_id: UUID of the user
  - actor_id: UUID of the user performing the action (for audit)

  ## Returns
  - {:ok, user} on successful cancellation
  - {:error, reason} on failure
  """
  def cancel_user_deletion(user_id, actor_id \\ nil) do
    Repo.transaction(fn ->
      user = Repo.get(UserSchema, user_id)

      case user do
        nil ->
          Repo.rollback(:user_not_found)
        %UserSchema{status: "deleted"} = user ->
          # Restore user
          changeset = Ecto.Changeset.change(user, %{
            status: "active",
            deleted_at: nil,
            deletion_reason: nil,
            gdpr_retention_expires_at: nil
          })

          case Repo.update(changeset) do
            {:ok, restored_user} ->
              AuditTrail.log_action(user_id, "deletion_cancelled", actor_id, %{})
              restored_user
            {:error, reason} ->
              Repo.rollback(reason)
          end
        _ ->
          AuditTrail.log_action(user_id, "deletion_cancelled_already_active", actor_id, %{})
          user
      end
    end)
  end

  # Private functions

  defp soft_delete_user(user_id, reason) do
    user = Repo.get(UserSchema, user_id)

    case user do
      nil ->
        {:error, :user_not_found}
      %UserSchema{status: "active"} = user ->
        retention_expires_at = DateTime.add(DateTime.utc_now(), @deletion_retention_days, :day)

        changeset = Ecto.Changeset.change(user, %{
          status: "deleted",
          deleted_at: DateTime.utc_now(),
          deletion_reason: reason,
          gdpr_retention_expires_at: retention_expires_at
        })

        Repo.update(changeset)
      %UserSchema{status: "deleted"} ->
        {:ok, user}  # Already deleted
      _ ->
        {:error, :invalid_user_status}
    end
  end

  defp schedule_retention_cleanup(user_id, retention_days) do
    expires_at = DateTime.add(DateTime.utc_now(), retention_days, :day)
    DataRetention.schedule_cleanup(user_id, expires_at, categories: ["core_identity", "activity_data"])
  end

  defp generate_final_data_export(user_id) do
    Export.create_export(user_id, "json", purpose: "deletion_backup")
  end
end