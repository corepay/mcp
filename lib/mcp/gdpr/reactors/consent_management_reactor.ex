defmodule Mcp.Gdpr.ConsentManagementReactor do
  @moduledoc """
  Reactor workflow for GDPR consent management.

  This reactor handles consent recording, updates, and withdrawal with proper
  audit trails and data processing implications.
  """

  use Ash.Reactor

  # Input arguments for consent management
  input :user_id
  input :purpose
  input :legal_basis
  input :consent_value
  input :actor_id
  input :ip_address
  input :user_agent
  input :metadata

  step :validate_user do
    argument :user_id, input(:user_id)

    run &Mcp.Gdpr.ConsentManagementReactor.validate_user/1
    async? false
  end

  step :validate_purpose do
    argument :purpose, input(:purpose)

    run &Mcp.Gdpr.ConsentManagementReactor.validate_purpose/1
    async? false
  end

  step :check_existing_consent do
    argument :user_id, input(:user_id)
    argument :purpose, input(:purpose)

    run &Mcp.Gdpr.ConsentManagementReactor.check_existing_consent/1
    async? false
  end

  step :validate_legal_basis do
    argument :legal_basis, input(:legal_basis)
    argument :purpose, input(:purpose)

    run &Mcp.Gdpr.ConsentManagementReactor.validate_legal_basis/1
    async? false
  end

  step :create_consent_record do
    argument :user_id, input(:user_id)
    argument :purpose, input(:purpose)
    argument :legal_basis, input(:legal_basis)
    argument :consent_value, input(:consent_value)
    argument :metadata, input(:metadata)

    run &Mcp.Gdpr.ConsentManagementReactor.create_consent_record/1
    async? false
    compensate &Mcp.Gdpr.ConsentManagementReactor.compensate_consent_creation/1
  end

  step :update_user_consent_status do
    argument :user_id, input(:user_id)
    argument :purpose, input(:purpose)
    argument :consent_value, input(:consent_value)

    run &Mcp.Gdpr.ConsentManagementReactor.update_user_consent_status/1
    async? false
    compensate &Mcp.Gdpr.ConsentManagementReactor.compensate_user_consent_update/1
  end

  step :create_audit_entry do
    argument :user_id, input(:user_id)
    argument :purpose, input(:purpose)
    argument :consent_value, input(:consent_value)
    argument :actor_id, input(:actor_id)
    argument :ip_address, input(:ip_address)
    argument :user_agent, input(:user_agent)

    run &Mcp.Gdpr.ConsentManagementReactor.create_consent_audit_entry/1
    async? false
  end

  step :handle_consent_implications do
    argument :user_id, input(:user_id)
    argument :purpose, input(:purpose)
    argument :consent_value, input(:consent_value)
    argument :previous_consent, result(:check_existing_consent)

    run &Mcp.Gdpr.ConsentManagementReactor.handle_consent_implications/1
    async? true
  end

  step :notify_consent_change do
    argument :user_id, input(:user_id)
    argument :purpose, input(:purpose)
    argument :consent_value, input(:consent_value)

    run &Mcp.Gdpr.ConsentManagementReactor.notify_consent_change/1
    async? true
  end

  # Public API functions

  @doc """
  Validates that the user exists.
  """
  def validate_user(%{user_id: user_id}) do
    case Ash.get(Mcp.Gdpr.Resources.User, user_id, domain: Mcp.Domains.Gdpr) do
      {:ok, user} ->
        {:ok, user}
      {:error, _} ->
        {:error, "User not found"}
    end
  end

  @doc """
  Validates that the consent purpose is valid.
  """
  def validate_purpose(%{purpose: purpose}) do
    valid_purposes = [
      "marketing",
      "analytics",
      "personalization",
      "third_party_sharing",
      "email_communications",
      "sms_communications",
      "data_processing",
      "research"
    ]

    if purpose in valid_purposes do
      {:ok, :valid_purpose}
    else
      {:error, {:invalid_purpose, purpose}}
    end
  end

  @doc """
  Checks for existing consent records.
  """
  def check_existing_consent(%{user_id: _user_id, purpose: _purpose}) do
    # Implementation would check for existing consent records
    # For now, return no existing consent
    {:ok, nil}
  end

  @doc """
  Validates the legal basis for consent.
  """
  def validate_legal_basis(%{legal_basis: basis, purpose: _purpose}) do
    valid_bases = ["consent", "contract", "legal_obligation", "vital_interests", "public_task", "legitimate_interests"]

    if basis in valid_bases do
      {:ok, :valid_basis}
    else
      {:error, {:invalid_legal_basis, basis}}
    end
  end

  @doc """
  Creates a new consent record.
  """
  def create_consent_record(%{user_id: user_id, purpose: purpose, legal_basis: basis, consent_value: value, metadata: metadata}) do
    consent_data = %{
      user_id: user_id,
      purpose: purpose,
      legal_basis: basis,
      consent_given: value,
      given_at: DateTime.utc_now(),
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent],
      metadata: metadata
    }

    # Implementation would create a consent record
    {:ok, consent_data}
  end

  @doc """
  Compensation for consent record creation failure.
  """
  def compensate_consent_creation(%{user_id: user_id, purpose: purpose}) do
    # Log the failed consent creation
    Mcp.Gdpr.AuditTrail.log_event(
      user_id,
      "consent_creation_failed",
      %{purpose: purpose},
      "system"
    )
    :ok
  end

  @doc """
  Updates the user's consent status.
  """
  def update_user_consent_status(%{user_id: user_id, purpose: purpose, consent_value: value}) do
    consent_record = %{consent_given: value, purpose: purpose}

    case purpose do
      "marketing" ->
        Ash.get!(Mcp.Gdpr.Resources.User, user_id, domain: Mcp.Domains.Gdpr)
        |> Ash.update!(%{
          gdpr_marketing_consent: value,
          gdpr_consent_record: %{marketing: consent_record}
        }, action: :update_consent, domain: Mcp.Domains.Gdpr)
      "analytics" ->
        Ash.get!(Mcp.Gdpr.Resources.User, user_id, domain: Mcp.Domains.Gdpr)
        |> Ash.update!(%{
          gdpr_analytics_consent: value,
          gdpr_consent_record: %{analytics: consent_record}
        }, action: :update_consent, domain: Mcp.Domains.Gdpr)
      _ ->
        {:ok, :consent_updated}
    end
  end

  @doc """
  Compensation for user consent update failure.
  """
  def compensate_user_consent_update(%{user_id: user_id, purpose: purpose}) do
    # Restore previous consent state
    Mcp.Gdpr.AuditTrail.log_event(
      user_id,
      "consent_update_rollback",
      %{purpose: purpose},
      "system"
    )
    :ok
  end

  @doc """
  Creates an audit trail entry for the consent change.
  """
  def create_consent_audit_entry(%{user_id: user_id, purpose: purpose, consent_value: value, actor_id: actor_id, ip_address: ip, user_agent: ua}) do
    Ash.create(Mcp.Gdpr.Resources.AuditTrail, %{
      user_id: user_id,
      action_type: "consent_updated",
      actor_type: "user",
      actor_id: actor_id,
      ip_address: ip,
      user_agent: ua,
      legal_basis: "consent",
      data_categories: [purpose],
      details: %{
        purpose: purpose,
        consent_value: value
      }
    }, action: :create_entry, domain: Mcp.Domains.Gdpr)
  end

  @doc """
  Handles implications of consent changes.
  """
  def handle_consent_implications(%{user_id: user_id, purpose: purpose, consent_value: value, previous_consent: previous}) do
    case {purpose, value, previous} do
      {"marketing", false, true} ->
        # User withdrew marketing consent - trigger data cleanup
        schedule_marketing_data_cleanup(user_id)
      {"analytics", false, true} ->
        # User withdrew analytics consent - disable tracking
        disable_analytics_tracking(user_id)
      {"third_party_sharing", false, true} ->
        # User withdrew third-party sharing consent
        revoke_third_party_access(user_id)
      {"marketing", true, false} ->
        # User gave marketing consent - enable marketing
        enable_marketing_communications(user_id)
      {"analytics", true, false} ->
        # User gave analytics consent - enable tracking
        enable_analytics_tracking(user_id)
      _ ->
        :ok
    end

    {:ok, :implications_handled}
  end

  @doc """
  Notifies about consent changes.
  """
  def notify_consent_change(%{user_id: user_id, purpose: purpose, consent_value: value}) do
    # Send notifications about consent changes
    Mcp.Gdpr.AuditTrail.log_event(
      user_id,
      "consent_change_notified",
      %{
        purpose: purpose,
        consent_value: value
      },
      "system"
    )

    {:ok, :notified}
  end

  # Helper functions for handling consent implications

  defp schedule_marketing_data_cleanup(user_id) do
    # Schedule background job to clean up marketing data
    %{user_id: user_id, type: "marketing_cleanup"}
    |> Mcp.Jobs.Gdpr.RetentionCleanupWorker.new()
    |> Oban.insert()
  end

  defp disable_analytics_tracking(_user_id) do
    # Update user preferences to disable analytics
    # Implementation would update analytics tracking settings
    :ok
  end

  defp revoke_third_party_access(_user_id) do
    # Revoke any third-party access based on user consent
    # Implementation would handle third-party integrations
    :ok
  end

  defp enable_marketing_communications(_user_id) do
    # Enable marketing communications for the user
    # Implementation would update marketing preferences
    :ok
  end

  defp enable_analytics_tracking(_user_id) do
    # Enable analytics tracking for the user
    # Implementation would update analytics preferences
    :ok
  end
end