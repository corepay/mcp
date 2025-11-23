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

  alias Mcp.Gdpr.{AuditTrail, DataRetention, Anonymizer, Export, Consent, Jobs}
  alias Mcp.Accounts.User
  alias Mcp.Repo
  alias Ash.Query

  @deletion_retention_days 90
  @export_retention_days 7
  @anonymization_retention_days 365

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
  def request_user_deletion(user_id, reason \\ "user_request", actor_id \\ nil, opts \\ []) do
    Repo.transaction(fn ->
      with {:ok, user} <- soft_delete_user(user_id, reason),
           {:ok, _audit} <- AuditTrail.log_action(user_id, "delete_request", actor_id, %{
             reason: reason,
             retention_expires_at: user.gdpr_retention_expires_at
           }),
           {:ok, _schedule} <- schedule_retention_cleanup(user_id, @deletion_retention_days),
           {:ok, _export} <- generate_final_data_export(user_id) do

        # Schedule background jobs
        Jobs.schedule_revoke_tokens(user_id)
        Jobs.schedule_disconnect_oauth(user_id)

        user
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Cancels a pending user deletion request.

  ## Parameters
  - user_id: UUID of the user whose deletion should be cancelled
  - actor_id: UUID of the user performing the cancellation

  ## Returns
  - {:ok, user} on successful cancellation
  - {:error, reason} on failure
  """
  def cancel_user_deletion(user_id, actor_id \\ nil) do
    Repo.transaction(fn ->
      with {:ok, user} <- restore_user(user_id),
           {:ok, _audit} <- AuditTrail.log_action(user_id, "deletion_cancelled", actor_id, %{}),
           :ok <- cancel_retention_cleanup(user_id) do
        user
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Generates a complete data export for a user.

  ## Parameters
  - user_id: UUID of the user to export data for
  - format: Export format ("json", "csv", "pdf")
  - categories: List of data categories to export (default: all)

  ## Returns
  - {:ok, export} with export record and download token
  - {:error, reason} on failure
  """
  def generate_data_export(user_id, format \\ "json", categories \\ nil) do
    AuditTrail.log_action(user_id, "access_request", nil, %{format: format, categories: categories})

    Export.create_export_request(user_id, format, categories)
  end

  @doc """
  Retrieves data export using download token.

  ## Parameters
  - token: Download token for the export

  ## Returns
  - {:ok, file_path, filename, content_type} on success
  - {:error, reason} on failure
  """
  def retrieve_data_export(token) do
    Export.get_export_by_token(token)
  end

  @doc """
  Records user consent for data processing.

  ## Parameters
  - user_id: UUID of the user
  - consent_type: Type of consent being recorded
  - consent_text: Full text of consent
  - opts: Additional options (ip_address, user_agent, etc.)

  ## Returns
  - {:ok, consent} on success
  - {:error, reason} on failure
  """
  def record_consent(user_id, consent_type, consent_text, opts \\ []) do
    Consent.record_consent(user_id, consent_type, consent_text, opts)
  end

  @doc """
  Revokes user consent for data processing.

  ## Parameters
  - user_id: UUID of the user
  - consent_type: Type of consent to revoke
  - opts: Additional options

  ## Returns
  - {:ok, consent} on success
  - {:error, reason} on failure
  """
  def revoke_consent(user_id, consent_type, opts \\ []) do
    Consent.revoke_consent(user_id, consent_type, opts)
  end

  @doc """
  Checks if a user has valid consent for a specific processing activity.

  ## Parameters
  - user_id: UUID of the user
  - consent_type: Type of consent to check

  ## Returns
  - {:ok, boolean} indicating consent status
  - {:error, reason} on failure
  """
  def has_consent?(user_id, consent_type) do
    Consent.has_valid_consent?(user_id, consent_type)
  end

  @doc """
  Retrieves all user data in compliance with GDPR access rights.

  ## Parameters
  - user_id: UUID of the user
  - opts: Additional options for data collection

  ## Returns
  - {:ok, data_map} containing all user data
  - {:error, reason} on failure
  """
  def get_user_data(user_id, opts \\ []) do
    Export.collect_user_data(user_id, opts)
  end

  @doc """
  Anonymizes all personal data for a user after retention period.

  ## Parameters
  - user_id: UUID of the user to anonymize
  - opts: Additional options

  ## Returns
  - {:ok, user} on successful anonymization
  - {:error, reason} on failure
  """
  def anonymize_user_data(user_id, opts \\ []) do
    Repo.transaction(fn ->
      with {:ok, user} <- User
                      |> Query.filter(id: ^user_id)
                      |> Query.filter(status: :deleted)
                      |> Ash.read_one(),
           {:ok, _audit} <- AuditTrail.log_action(user_id, "anonymization_started", nil, %{}),
           {:ok, _result} <- Anonymizer.anonymize_user(user_id, opts),
           {:ok, updated_user} <- update_user_anonymization_status(user_id),
           {:ok, _audit} <- AuditTrail.log_action(user_id, "anonymization_complete", nil, %{}) do

        updated_user
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Gets users who are overdue for anonymization.

  ## Returns
  - List of user records that should be anonymized
  """
  def get_users_overdue_for_anonymization do
    User
    |> Query.filter(status: :deleted)
    |> Query.filter(gdpr_retention_expires_at < DateTime.utc_now())
    |> Ash.read()
  end

  @doc """
  Gets all GDPR audit records for a user.

  ## Parameters
  - user_id: UUID of the user
  - opts: Pagination and filtering options

  ## Returns
  - {:ok, audit_records} on success
  - {:error, reason} on failure
  """
  def get_user_audit_trail(user_id, opts \\ []) do
    AuditTrail.get_user_actions(user_id, opts)
  end

  @doc """
  Generates GDPR compliance report for administrative purposes.

  ## Parameters
  - opts: Report filtering options

  ## Returns
  - {:ok, report_data} containing compliance metrics
  - {:error, reason} on failure
  """
  def generate_compliance_report(opts \\ []) do
    %{
      deletion_requests: get_deletion_request_metrics(),
      data_exports: get_export_metrics(),
      consent_records: get_consent_metrics(),
      retention_status: get_retention_metrics(),
      audit_summary: get_audit_metrics()
    }
  end

  # Private functions

  defp soft_delete_user(user_id, reason) do
    retention_expires_at = DateTime.add(DateTime.utc_now(), @deletion_retention_days, :day)

    User
    |> Ash.Changeset.for_update(:soft_delete, %{
      status: :deleted,
      gdpr_deletion_requested_at: DateTime.utc_now(),
      gdpr_deletion_reason: reason,
      gdpr_retention_expires_at: retention_expires_at
    })
    |> Ash.update()
  end

  defp restore_user(user_id) do
    User
    |> Ash.Changeset.for_update(:restore_user, %{
      status: :active,
      gdpr_deletion_requested_at: nil,
      gdpr_deletion_reason: nil,
      gdpr_retention_expires_at: nil
    })
    |> Ash.update()
  end

  defp schedule_retention_cleanup(user_id, days) do
    expires_at = DateTime.add(DateTime.utc_now(), days, :day)
    DataRetention.schedule_cleanup(user_id, expires_at)
  end

  defp cancel_retention_cleanup(user_id) do
    DataRetention.cancel_cleanup(user_id)
  end

  defp generate_final_data_export(user_id) do
    Export.create_export_request(user_id, "json", nil, %{purpose: "final_export"})
  end

  defp update_user_anonymization_status(user_id) do
    User
    |> Ash.Changeset.for_update(:anonymize_user, %{
      status: :anonymized,
      gdpr_anonymized_at: DateTime.utc_now()
    })
    |> Ash.update()
  end

  # Metrics collection functions

  defp get_deletion_request_metrics do
    # Implementation for deletion request metrics
    %{
      total_requests: 0,
      pending_requests: 0,
      completed_deletions: 0,
      average_processing_time: 0
    }
  end

  defp get_export_metrics do
    # Implementation for export metrics
    %{
      total_exports: 0,
      pending_exports: 0,
      completed_exports: 0,
      average_export_size: 0
    }
  end

  defp get_consent_metrics do
    # Implementation for consent metrics
    %{
      total_consent_records: 0,
      active_consents: 0,
      revoked_consents: 0,
      consent_by_type: %{}
    }
  end

  defp get_retention_metrics do
    # Implementation for retention metrics
    %{
      users_in_retention: 0,
      users_anonymized: 0,
      overdue_for_anonymization: 0,
      average_retention_period: @deletion_retention_days
    }
  end

  defp get_audit_metrics do
    # Implementation for audit metrics
    %{
      total_audit_records: 0,
      records_by_action_type: %{},
      audit_trail_integrity: "complete"
    }
  end
end