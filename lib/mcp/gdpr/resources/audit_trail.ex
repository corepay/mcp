defmodule Mcp.Gdpr.Resources.AuditTrail do
  @moduledoc """
  Ash resource for GDPR audit trail.

  Tracks all GDPR-related actions for compliance and auditing purposes.
  """

  use Ash.Resource,
    domain: Mcp.Domains.Gdpr,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "gdpr_audit_trail"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
    end

    attribute :action_type, :string do
      allow_nil? false
    end

    attribute :actor_type, :string
    attribute :actor_id, :uuid
    attribute :ip_address, :string
    attribute :user_agent, :string
    attribute :request_id, :string

    attribute :data_categories, {:array, :string} do
      default []
    end

    attribute :legal_basis, :string
    attribute :retention_period_days, :integer
    attribute :details, :map do
      default %{}
    end

    attribute :processed_at, :utc_datetime_usec

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
    end

    read :by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end
      filter expr(user_id == ^arg(:user_id))
    end

    read :by_action_type do
      argument :action_type, :string do
        allow_nil? false
      end
      filter expr(action_type == ^arg(:action_type))
    end

    create :create_entry do
      accept [
        :user_id,
        :action_type,
        :actor_type,
        :actor_id,
        :ip_address,
        :user_agent,
        :request_id,
        :data_categories,
        :legal_basis,
        :retention_period_days,
        :details
      ]
    end
  end

  relationships do
    belongs_to :user, Mcp.Gdpr.Resources.User do
      allow_nil? false
    end
  end

  validations do
    validate present([:user_id, :action_type])
  end

  end