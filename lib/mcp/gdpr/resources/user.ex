defmodule Mcp.Gdpr.Resources.User do
  @moduledoc """
  Ash resource for GDPR user operations.

  Extends user management with GDPR-specific actions and data privacy compliance.
  """

  use Ash.Resource,
    domain: Mcp.Domains.Gdpr,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "users"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
    end

    attribute :status, :string do
      default "active"
    end

    # GDPR deletion tracking
    attribute :gdpr_deletion_requested_at, :utc_datetime_usec
    attribute :gdpr_deletion_reason, :string
    attribute :gdpr_retention_expires_at, :utc_datetime_usec
    attribute :gdpr_anonymized_at, :utc_datetime_usec

    # Data export functionality
    attribute :gdpr_data_export_token, :uuid
    attribute :gdpr_last_exported_at, :utc_datetime_usec

    # Consent management
    attribute :gdpr_consent_record, :map do
      default %{}
    end

    attribute :gdpr_marketing_consent, :boolean do
      default false
    end

    attribute :gdpr_analytics_consent, :boolean do
      default false
    end

    # Account deletion request tracking
    attribute :gdpr_deletion_request_ip, :string
    attribute :gdpr_deletion_request_user_agent, :string

    # Account management fields
    attribute :deleted_at, :utc_datetime_usec
    attribute :deletion_reason, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
    end

    read :by_email do
      argument :email, :string do
        allow_nil? false
      end
      get_by [:email]
    end

    read :by_id do
      argument :id, :uuid do
        allow_nil? false
      end
      get_by [:id]
    end

    read :active_users do
      filter expr(status == "active")
    end

    read :deleted_users do
      filter expr(status == "deleted")
    end

    read :anonymized_users do
      filter expr(status == "anonymized")
    end

    create :create_user do
      accept [:email, :status]
    end

    update :update_user do
      accept [:email, :status]
    end

    # GDPR Actions
    update :soft_delete do
      accept [
        :gdpr_deletion_reason,
        :gdpr_retention_expires_at,
        :gdpr_deletion_request_ip,
        :gdpr_deletion_request_user_agent
      ]

      argument :actor_id, :uuid

      change set_attribute(:status, "deleted")
      change set_attribute(:gdpr_deletion_requested_at, &DateTime.utc_now/0)
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end

    update :anonymize_user do
      accept [
        :gdpr_deletion_reason
      ]

      argument :actor_id, :uuid
      argument :anonymization_mode, :string do
        default "full"
      end
      argument :fields_to_anonymize, {:array, :string}

      change set_attribute(:status, "anonymized")
      change set_attribute(:gdpr_anonymized_at, &DateTime.utc_now/0)
    end

    update :cancel_deletion do
      argument :actor_id, :uuid

      change set_attribute(:status, "active")
      change set_attribute(:deleted_at, nil)
      change set_attribute(:gdpr_deletion_requested_at, nil)
      change set_attribute(:gdpr_deletion_reason, nil)
      change set_attribute(:gdpr_retention_expires_at, nil)
    end

    update :update_consent do
      accept [
        :gdpr_marketing_consent,
        :gdpr_analytics_consent,
        :gdpr_consent_record
      ]

      argument :actor_id, :uuid
    end
  end

  # Relationships will be added when related resources are created
  # relationships do
  #   has_many :gdpr_exports, Mcp.Gdpr.Resources.DataExport do
  #     destination_field :user_id
  #   end

  #   has_many :gdpr_audit_trail, Mcp.Gdpr.Resources.AuditTrail do
  #     destination_field :user_id
  #   end

  #   has_many :gdpr_consent_records, Mcp.Gdpr.Resources.ConsentRecord do
  #     destination_field :user_id
  #   end
  # end

  # Aggregates will be added when related resources are created
  # aggregates do
  #   count :gdpr_exports_count, :gdpr_exports
  #   count :gdpr_audit_entries_count, :gdpr_audit_trail
  # end

  # Basic validations
  validations do
    validate match(:email, ~r/@/)
  end
end