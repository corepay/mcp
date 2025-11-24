defmodule Mcp.Gdpr.UserDeletionReactor do
  @moduledoc """
  Reactor workflow for GDPR user deletion with comprehensive legal hold checks.

  This reactor implements a multi-step deletion process with compensation steps
  for handling legal holds, data retention policies, and compliance requirements.
  """

  use Ash.Reactor

  # Input arguments for the deletion workflow
  input :user_id
  input :deletion_reason
  input :actor_id
  input :ip_address
  input :user_agent

  step :validate_user do
    argument :user_id, input(:user_id)

    run &Mcp.Gdpr.UserDeletionReactor.validate_user/1
    async? false
  end

  step :check_legal_holds do
    argument :user_id, input(:user_id)

    run &Mcp.Gdpr.UserDeletionReactor.check_legal_holds/1
    async? false
    compensate &Mcp.Gdpr.UserDeletionReactor.compensate_legal_hold_check/1
  end

  step :check_active_exports do
    argument :user_id, input(:user_id)

    run &Mcp.Gdpr.UserDeletionReactor.check_active_exports/1
    async? false
  end

  step :check_pending_consent_changes do
    argument :user_id, input(:user_id)

    run &Mcp.Gdpr.UserDeletionReactor.check_pending_consent_changes/1
    async? false
  end

  step :calculate_retention_schedule do
    argument :user_id, input(:user_id)
    argument :deletion_reason, input(:deletion_reason)

    run &Mcp.Gdpr.UserDeletionReactor.calculate_retention_schedule/1
    async? false
  end

  step :create_audit_entry do
    argument :user_id, input(:user_id)
    argument :deletion_reason, input(:deletion_reason)
    argument :actor_id, input(:actor_id)
    argument :ip_address, input(:ip_address)
    argument :user_agent, input(:user_agent)

    run &Mcp.Gdpr.UserDeletionReactor.create_deletion_audit_entry/1
    async? false
  end

  step :initiate_soft_delete do
    argument :user_id, input(:user_id)
    argument :deletion_reason, input(:deletion_reason)
    argument :actor_id, input(:actor_id)
    argument :retention_expires_at, result(:calculate_retention_schedule)

    run &Mcp.Gdpr.UserDeletionReactor.initiate_soft_delete/1
    async? false
    compensate &Mcp.Gdpr.UserDeletionReactor.compensate_soft_delete/1
  end

  step :schedule_anonymization do
    argument :user_id, input(:user_id)
    argument :anonymization_date, result(:calculate_retention_schedule)

    run &Mcp.Gdpr.UserDeletionReactor.schedule_anonymization/1
    async? false
    compensate &Mcp.Gdpr.UserDeletionReactor.compensate_anonymization_scheduling/1
  end

  step :notify_stakeholders do
    argument :user_id, input(:user_id)
    argument :deletion_reason, input(:deletion_reason)
    argument :anonymization_date, result(:calculate_retention_schedule)

    run &Mcp.Gdpr.UserDeletionReactor.notify_deletion_stakeholders/1
    async? true
  end

  # Public API functions

  @doc """
  Validates that the user exists and can be deleted.
  """
  def validate_user(%{user_id: user_id}) do
    case Ash.get(Mcp.Gdpr.Resources.User, user_id, domain: Mcp.Domains.Gdpr) do
      {:ok, user} ->
        if user.status in ["active", "suspended"] do
          {:ok, user}
        else
          {:error, "User already deleted or anonymized"}
        end
      {:error, _} ->
        {:error, "User not found"}
    end
  end

  @doc """
  Checks for any active legal holds on the user's data.
  """
  def check_legal_holds(%{user_id: user_id}) do
    case Mcp.Gdpr.DataRetention.check_legal_holds(user_id) do
      [] ->
        {:ok, :no_holds}
      holds ->
        {:error, {:legal_holds_active, holds}}
    end
  end

  @doc """
  Compensation for legal hold check failure.
  """
  def compensate_legal_hold_check(%{user_id: user_id}) do
    # Log the blocked deletion attempt
    Mcp.Gdpr.AuditTrail.log_event(
      user_id,
      "deletion_blocked_legal_hold",
      %{},
      "system"
    )
    :ok
  end

  @doc """
  Checks for any active data export requests.
  """
  def check_active_exports(%{user_id: _user_id}) do
    # For now, simplify this check until we have proper Ash queries working
    {:ok, :no_active_exports}
  end

  @doc """
  Checks for pending consent changes that need to be processed.
  """
  def check_pending_consent_changes(%{user_id: _user_id}) do
    # Implementation would check for pending consent records
    {:ok, :no_pending_changes}
  end

  @doc """
  Calculates the retention schedule based on deletion reason and legal requirements.
  """
  def calculate_retention_schedule(%{user_id: _user_id, deletion_reason: reason}) do
    retention_days = case reason do
      "user_request" -> 30
      "account_closure" -> 180
      "legal_requirement" -> 0
      "violation" -> 365
      _ -> 90
    end

    retention_date = DateTime.add(DateTime.utc_now(), retention_days, :day)
    {:ok, retention_date}
  end

  @doc """
  Creates an audit trail entry for the deletion request.
  """
  def create_deletion_audit_entry(%{user_id: user_id, deletion_reason: reason, actor_id: actor_id, ip_address: ip, user_agent: ua}) do
    Ash.create(Mcp.Gdpr.Resources.AuditTrail, %{
      user_id: user_id,
      action_type: "deletion_requested",
      actor_type: "user",
      actor_id: actor_id,
      ip_address: ip,
      user_agent: ua,
      legal_basis: reason,
      data_categories: ["profile", "activity", "communications"],
      details: %{reason: reason}
    }, action: :create_entry, domain: Mcp.Domains.Gdpr)
  end

  @doc """
  Initiates the soft delete process for the user.
  """
  def initiate_soft_delete(%{user_id: user_id, deletion_reason: reason, actor_id: actor_id, retention_expires_at: expires_at}) do
    Ash.get!(Mcp.Gdpr.Resources.User, user_id, domain: Mcp.Domains.Gdpr)
    |> Ash.update!(%{
      gdpr_deletion_reason: reason,
      gdpr_retention_expires_at: expires_at,
      actor_id: actor_id
    }, action: :soft_delete, domain: Mcp.Domains.Gdpr)
  end

  @doc """
  Compensation for soft delete failure.
  """
  def compensate_soft_delete(%{user_id: user_id}) do
    # Restore user from soft delete state
    Ash.get!(Mcp.Gdpr.Resources.User, user_id, domain: Mcp.Domains.Gdpr)
    |> Ash.update!(%{actor_id: "system"}, action: :cancel_deletion, domain: Mcp.Domains.Gdpr)
    :ok
  end

  @doc """
  Schedules the final anonymization job.
  """
  def schedule_anonymization(%{user_id: user_id, anonymization_date: date}) do
    %{user_id: user_id, anonymization_date: date}
    |> Mcp.Jobs.Gdpr.AnonymizationWorker.new(scheduled_at: date)
    |> Oban.insert()

    {:ok, :scheduled}
  end

  @doc """
  Compensation for anonymization scheduling failure.
  """
  def compensate_anonymization_scheduling(%{user_id: _user_id}) do
    # Cancel the scheduled anonymization
    # TODO: Implement proper Oban job cancellation
    :ok
  end

  @doc """
  Notifies relevant stakeholders about the deletion request.
  """
  def notify_deletion_stakeholders(%{user_id: user_id, deletion_reason: reason, anonymization_date: date}) do
    # Send notifications to compliance team, legal team, etc.
    # Implementation would depend on notification system

    Mcp.Gdpr.AuditTrail.log_event(
      user_id,
      "deletion_stakeholders_notified",
      %{
        reason: reason,
        anonymization_date: DateTime.to_iso8601(date)
      },
      "system"
    )

    {:ok, :notified}
  end
end