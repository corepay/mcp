defmodule Mcp.Gdpr.Resources.RetentionPolicy do
  @moduledoc """
  Ash resource for GDPR data retention policies.

  Defines how long different types of data should be retained
  and under what conditions they should be anonymized or deleted.
  """

  use Ash.Resource,
    domain: Mcp.Domains.Gdpr,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "gdpr_retention_policies"
    repo(Mcp.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      description "Tenant this policy applies to"
    end

    attribute :entity_type, :string do
      allow_nil? false
      description "Type of entity this policy applies to (user, audit_trail, consent, etc.)"
    end

    attribute :retention_days, :integer do
      allow_nil? false
      default 365
      description "Number of days to retain the data"
    end

    attribute :action, :string do
      allow_nil? false
      default "anonymize"
      description "Action to take when retention period expires (anonymize, delete, archive)"
    end

    attribute :legal_hold, :boolean do
      default false
      description "Whether this policy is on legal hold and should not be processed"
    end

    attribute :legal_hold_reason, :string do
      description "Reason for legal hold if applicable"
    end

    attribute :legal_hold_until, :utc_datetime_usec do
      description "When the legal hold expires"
    end

    attribute :conditions, :map do
      default %{}
      description "Additional conditions for when this policy applies"
    end

    attribute :priority, :integer do
      default 100
      description "Priority of this policy (lower numbers = higher priority)"
    end

    attribute :active, :boolean do
      default true
      description "Whether this policy is currently active"
    end

    attribute :description, :string do
      description "Human-readable description of this policy"
    end

    attribute :last_processed_at, :utc_datetime_usec do
      description "When this policy was last processed for retention cleanup"
    end

    attribute :processing_frequency_hours, :integer do
      default 24
      description "How often this policy should be processed (in hours)"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
    end

    read :by_tenant do
      argument :tenant_id, :uuid do
        allow_nil? false
      end

      filter expr(tenant_id == ^arg(:tenant_id))
    end

    read :by_entity_type do
      argument :entity_type, :string do
        allow_nil? false
      end

      filter expr(entity_type == ^arg(:entity_type))
    end

    read :active_policies do
      filter expr(active == true and legal_hold == false)
    end

    read :policies_due_for_processing do
      argument :current_time, :utc_datetime_usec do
        allow_nil? false
        default &DateTime.utc_now/0
      end

      filter expr(
               active == true and
                 legal_hold == false and
                 (is_nil(last_processed_at) or
                    last_processed_at <
                      DateTime.add(
                        ^arg(:current_time),
                        -processing_frequency_hours * 3600,
                        :second
                      ))
             )
    end

    create :create_policy do
      accept [
        :tenant_id,
        :entity_type,
        :retention_days,
        :action,
        :legal_hold,
        :legal_hold_reason,
        :legal_hold_until,
        :conditions,
        :priority,
        :active,
        :description,
        :processing_frequency_hours
      ]

      argument :actor_id, :uuid
    end

    update :update_policy do
      accept [
        :retention_days,
        :action,
        :legal_hold,
        :legal_hold_reason,
        :legal_hold_until,
        :conditions,
        :priority,
        :active,
        :description,
        :processing_frequency_hours
      ]

      argument :actor_id, :uuid
    end

    update :place_on_legal_hold do
      accept [
        :legal_hold_reason,
        :legal_hold_until
      ]

      argument :actor_id, :uuid

      change set_attribute(:legal_hold, true)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :remove_legal_hold do
      argument :actor_id, :uuid

      change set_attribute(:legal_hold, false)
      change set_attribute(:legal_hold_reason, nil)
      change set_attribute(:legal_hold_until, nil)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :mark_processed do
      accept []

      argument :actor_id, :uuid

      change set_attribute(:last_processed_at, &DateTime.utc_now/0)
    end

    update :deactivate_policy do
      accept []

      argument :actor_id, :uuid

      change set_attribute(:active, false)
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? false
      domain Mcp.Platform
    end
  end

  validations do
    validate present([:tenant_id, :entity_type, :retention_days, :action])
  end
end
