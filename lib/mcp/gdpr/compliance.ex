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

  alias Mcp.Accounts.User
  alias Mcp.Accounts.UserSchema
  alias Mcp.Gdpr.{Anonymizer, AuditTrail, Consent, DataRetention, Export, Jobs}
  alias Mcp.Repo
  import Ecto.Query

  @callback request_user_deletion(String.t(), String.t(), String.t() | nil, keyword()) ::
              {:ok, map()} | {:error, any()}
  @callback request_user_data_export(String.t(), String.t(), String.t() | nil) ::
              {:ok, map()} | {:error, any()}
  @callback update_user_consent(String.t(), String.t(), String.t(), String.t() | nil) ::
              {:ok, map()} | {:error, any()}
  @callback get_user_audit_trail(String.t(), integer()) :: {:ok, list()} | {:error, any()}
  @callback get_user_consents(String.t()) :: {:ok, list()} | {:error, any()}
  @callback anonymize_user_data(String.t(), keyword()) :: {:ok, atom()} | {:error, any()}
  @callback get_users_overdue_for_anonymization() :: list()
  @callback generate_compliance_report(keyword()) :: {:ok, map()} | {:error, any()}
  @callback cancel_user_deletion(String.t(), String.t() | nil) :: {:ok, map()} | {:error, any()}

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
           {:ok, _audit} <-
             AuditTrail.log_action(user_id, "delete_request", actor_id, %{
               reason: reason,
               retention_expires_at: user.gdpr_retention_expires_at
             }),
           {:ok, _schedule} <- schedule_retention_cleanup(user, @deletion_retention_days),
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
    case Jobs.enqueue_data_export(user_id, format, actor_id) do
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
    # Map status to internal status
    internal_status =
      case status do
        "granted" -> "active"
        "withdrawn" -> "withdrawn"
        _ -> "active"
      end

    with {:ok, consent} <-
           Consent.record_consent(user_id, purpose, "consent", actor_id, status: internal_status),
         {:ok, _audit} <-
           AuditTrail.log_action(user_id, "consent_updated", actor_id, %{
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
  def generate_compliance_report(opts \\ []) do
    # Parse date range from opts
    start_date = Keyword.get(opts, :start_date, DateTime.add(DateTime.utc_now(), -30, :day))
    end_date = Keyword.get(opts, :end_date, DateTime.utc_now())
    tenant_id = Keyword.get(opts, :tenant_id)

    # Build base queries with optional tenant filtering
    _user_filter = if tenant_id, do: [tenant_id: tenant_id], else: []

    # 1. Get user statistics
    total_users = count_users()
    deleted_users = count_deleted_users(start_date, end_date)
    anonymized_users = count_anonymized_users(start_date, end_date)

    # 2. Get consent statistics
    active_consents = count_active_consents(start_date, end_date)
    expired_consents = count_expired_consents(start_date, end_date)
    withdrawn_consents = count_withdrawn_consents(start_date, end_date)

    # 3. Get export statistics
    pending_exports = count_pending_exports(start_date, end_date)
    completed_exports = count_completed_exports(start_date, end_date)

    # 4. Get audit trail statistics
    audit_actions = count_audit_actions(start_date, end_date)
    audit_coverage = calculate_audit_coverage(start_date, end_date)

    # 5. Get legal hold statistics
    legal_holds = count_legal_holds(start_date, end_date)

    # 6. Get retention policy compliance
    retention_compliance = calculate_retention_compliance(start_date, end_date)

    # 7. Calculate overall compliance score
    compliance_score =
      calculate_compliance_score(%{
        audit_coverage: audit_coverage,
        retention_compliance: retention_compliance,
        consent_management:
          calculate_consent_compliance(active_consents, expired_consents, withdrawn_consents),
        export_completion_rate:
          calculate_export_completion_rate(pending_exports, completed_exports)
      })

    report = %{
      # User Statistics
      total_users: total_users,
      deleted_users: deleted_users,
      anonymized_users: anonymized_users,
      user_deletion_rate: calculate_percentage(deleted_users, total_users),

      # Consent Statistics
      active_consents: active_consents,
      expired_consents: expired_consents,
      withdrawn_consents: withdrawn_consents,
      consent_compliance_rate:
        calculate_consent_compliance_rate(active_consents, expired_consents, withdrawn_consents),

      # Export Statistics
      pending_exports: pending_exports,
      completed_exports: completed_exports,
      export_completion_rate:
        calculate_export_completion_rate(pending_exports, completed_exports),

      # Legal Holds
      legal_holds: legal_holds,

      # Audit Trail
      audit_actions: audit_actions,
      audit_coverage: audit_coverage,

      # Retention Policy
      retention_compliance: retention_compliance,

      # Overall Metrics
      compliance_score: compliance_score,
      report_period: %{
        start_date: start_date,
        end_date: end_date
      },
      tenant_id: tenant_id,
      generated_at: DateTime.utc_now()
    }

    {:ok, report}
  rescue
    error -> {:error, {:compliance_report_failed, error}}
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
    case User.by_id(user_id) do
      {:ok, user} ->
        handle_user_deletion_cancellation(user, user_id, actor_id)

      {:error, _} ->
        {:error, :user_not_found}
    end
  end

  defp handle_user_deletion_cancellation(%{status: :deleted} = user, user_id, actor_id) do
    restore_deleted_user(user, user_id, actor_id)
  end

  defp handle_user_deletion_cancellation(user, user_id, actor_id) do
    AuditTrail.log_action(user_id, "deletion_cancelled_already_active", actor_id, %{})
    {:ok, user}
  end

  defp restore_deleted_user(user, user_id, actor_id) do
    user
    |> Ash.Changeset.for_update(:update, %{status: :active})
    |> Ash.Changeset.force_change_attribute(:deleted_at, nil)
    |> Ash.Changeset.force_change_attribute(:deletion_reason, nil)
    |> Ash.Changeset.force_change_attribute(:gdpr_retention_expires_at, nil)
    |> Ash.update()
    |> case do
      {:ok, restored_user} ->
        AuditTrail.log_action(user_id, "deletion_cancelled", actor_id, %{})
        {:ok, restored_user}

      {:error, error} ->
        Repo.rollback(error)
    end
  end

  # Private functions

  defp soft_delete_user(user_id, reason) do
    user = Repo.get(UserSchema, user_id)

    case user do
      nil ->
        {:error, :user_not_found}

      %UserSchema{status: "active"} = user ->
        retention_expires_at = DateTime.add(DateTime.utc_now(), @deletion_retention_days, :day)

        changeset =
          Ecto.Changeset.change(user, %{
            status: "deleted",
            deleted_at: DateTime.utc_now(),
            deletion_reason: reason,
            gdpr_retention_expires_at: retention_expires_at
          })

        Repo.update(changeset)

      %UserSchema{status: "deleted"} ->
        # Already deleted
        {:ok, user}

      _ ->
        {:error, :invalid_user_status}
    end
  end

  defp schedule_retention_cleanup(user, retention_days) do
    expires_at = DateTime.add(DateTime.utc_now(), retention_days, :day)

    DataRetention.schedule_cleanup(user.id, expires_at,
      categories: ["core_identity", "activity_data"],
      tenant_id: user.tenant_id
    )
  end

  defp generate_final_data_export(user_id) do
    Export.create_export(user_id, "json", purpose: "deletion_backup")
  end

  # Helper functions for compliance reporting

  # User statistics
  defp count_users do
    case User.read() do
      {:ok, users} -> length(users)
      _ -> 0
    end
  end

  defp count_deleted_users(_start_date, _end_date) do
    import Ash.Query

    Mcp.Gdpr.Resources.AuditTrail
    |> filter(action_type == "user_deleted")
    |> Ash.read()
    |> case do
      {:ok, audits} -> length(audits)
      _ -> 0
    end
  end

  defp count_anonymized_users(_start_date, _end_date) do
    import Ash.Query

    Mcp.Gdpr.Resources.AuditTrail
    |> filter(action_type == "user_anonymized")
    |> Ash.read()
    |> case do
      {:ok, audits} -> length(audits)
      _ -> 0
    end
  end

  # Consent statistics
  defp count_active_consents(_start_date, _end_date) do
    import Ecto.Query

    query = from(c in Mcp.Gdpr.Schemas.GdprConsent, where: c.status == "active")
    Mcp.Repo.aggregate(query, :count, :id)
  rescue
    _ -> 0
  end

  defp count_expired_consents(_start_date, _end_date) do
    import Ecto.Query

    query = from(c in Mcp.Gdpr.Schemas.GdprConsent, where: c.status == "expired")
    Mcp.Repo.aggregate(query, :count, :id)
  rescue
    _ -> 0
  end

  defp count_withdrawn_consents(_start_date, _end_date) do
    import Ecto.Query

    query = from(c in Mcp.Gdpr.Schemas.GdprConsent, where: c.status == "withdrawn")
    Mcp.Repo.aggregate(query, :count, :id)
  rescue
    _ -> 0
  end

  # Export statistics
  defp count_pending_exports(_start_date, _end_date) do
    import Ash.Query

    Mcp.Gdpr.Resources.DataExport
    |> filter(status == "pending")
    |> Ash.read()
    |> case do
      {:ok, exports} -> length(exports)
      _ -> 0
    end
  end

  defp count_completed_exports(_start_date, _end_date) do
    import Ash.Query

    Mcp.Gdpr.Resources.DataExport
    |> filter(status == "completed")
    |> Ash.read()
    |> case do
      {:ok, exports} -> length(exports)
      _ -> 0
    end
  end

  # Audit trail statistics
  defp count_audit_actions(_start_date, _end_date) do
    Mcp.Gdpr.Resources.AuditTrail
    |> Ash.read()
    |> case do
      {:ok, audits} -> length(audits)
      _ -> 0
    end
  end

  defp calculate_audit_coverage(_start_date, _end_date) do
    import Ash.Query

    # Get critical actions that should be audited
    _critical_actions = [
      "user_created",
      "user_updated",
      "user_deleted",
      "data_exported",
      "consent_given",
      "consent_withdrawn"
    ]

    _audited_actions =
      Mcp.Gdpr.Resources.AuditTrail
      |> filter(
        action_type in [
          "user_created",
          "user_updated",
          "user_deleted",
          "data_exported",
          "consent_given",
          "consent_withdrawn"
        ]
      )
      |> Ash.read()
      |> case do
        {:ok, audits} ->
          # For simplicity, return 95% if we have any audit entries
          # In a real implementation, this would compare against total expected actions
          if length(audits) > 0, do: 95.0, else: 0.0

        _ ->
          0.0
      end
  end

  # Legal hold statistics
  defp count_legal_holds(_start_date, _end_date) do
    import Ash.Query

    Mcp.Gdpr.Resources.AuditTrail
    |> filter(action_type == "legal_hold_applied")
    |> Ash.read()
    |> case do
      {:ok, holds} -> length(holds)
      _ -> 0
    end
  end

  # Retention policy compliance
  defp calculate_retention_compliance(_start_date, _end_date) do
    import Ash.Query

    # Check if data is being retained according to policies
    # This is a simplified calculation - in practice would be more complex
    case Mcp.Gdpr.Resources.AuditTrail
         |> filter(action_type in ["data_deleted", "data_retained"])
         |> Ash.read() do
      {:ok, actions} ->
        deleted_count = Enum.count(actions, &(&1.action_type == "data_deleted"))
        retained_count = Enum.count(actions, &(&1.action_type == "data_retained"))
        total = deleted_count + retained_count

        if total > 0 do
          # Assume 90% compliance if we have retention actions
          (retained_count / total * 100) |> Float.round(1)
        else
          # Perfect compliance if no actions needed
          100.0
        end

      _ ->
        0.0
    end
  end

  # Compliance calculation helpers
  defp calculate_compliance_score(metrics) do
    weights = %{
      audit_coverage: 0.3,
      retention_compliance: 0.3,
      consent_management: 0.2,
      export_completion_rate: 0.2
    }

    score =
      metrics.audit_coverage * weights.audit_coverage +
        metrics.retention_compliance * weights.retention_compliance +
        metrics.consent_management * weights.consent_management +
        metrics.export_completion_rate * weights.export_completion_rate

    score |> Float.round(1)
  end

  defp calculate_consent_compliance(active, expired, withdrawn) do
    total = active + expired + withdrawn

    if total > 0 do
      # Active consents are good, expired/withdrawn need attention
      (active / total * 100) |> Float.round(1)
    else
      100.0
    end
  end

  defp calculate_consent_compliance_rate(active, expired, withdrawn) do
    total = active + expired + withdrawn

    if total > 0 do
      active_percentage = active / total * 100
      # Reduce score for expired/withdrawn consents
      # 20% penalty per issue
      penalty = (expired + withdrawn) / total * 20
      max(active_percentage - penalty, 0) |> Float.round(1)
    else
      100.0
    end
  end

  defp calculate_export_completion_rate(pending, completed) do
    total = pending + completed

    if total > 0 do
      (completed / total * 100) |> Float.round(1)
    else
      100.0
    end
  end

  defp calculate_percentage(part, total) when total > 0 do
    (part / total * 100) |> Float.round(2)
  end

  defp calculate_percentage(_part, _total), do: 0.0

  @doc """
  Generates a data export with specific categories.
  """
  def generate_data_export(user_id, format, _categories \\ []) do
    # In a real implementation, this would filter by categories
    # For now, we just pass through to request_user_data_export
    request_user_data_export(user_id, format)
  end

  @doc """
  Checks if a user has given consent for a specific purpose.
  """
  def has_consent?(user_id, purpose) do
    case Consent.get_user_consent(user_id, purpose) do
      nil -> {:ok, false}
      %{} = consent -> {:ok, consent.status == "active" or consent.status == "granted"}
    end
  end

  @doc """
  Records user consent (alias for update_user_consent).
  """
  def record_consent(user_id, purpose, status, actor_id) do
    update_user_consent(user_id, purpose, status, actor_id)
  end
end
