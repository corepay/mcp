defmodule Mcp.Communication.WebhookDelivery do
  @moduledoc """
  Resource tracking individual webhook delivery attempts and their status.
  """
  use Ash.Resource,
    otp_app: :mcp,
    domain: Mcp.Communication,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "webhook_deliveries"
    repo(Mcp.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :payload, :map do
      allow_nil? false
      public? true
    end

    attribute :response_code, :integer do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:scheduled, :success, :failure, :retrying]
      default :scheduled
      allow_nil? false
      public? true
    end

    attribute :attempt_count, :integer do
      default 0
      allow_nil? false
      public? true
    end

    attribute :endpoint_id, :uuid do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :endpoint, Mcp.Communication.WebhookEndpoint do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:payload, :endpoint_id, :status]
    end

    update :update do
      accept [:status, :response_code, :attempt_count]
    end
  end

  # Temporary simple policy to unblock creation. We will refine.
  # Since deliveries are created by system, we might need `authorize_if always()` for system actor?
  # For user reading:
  policies do
    policy action_type(:read) do
      authorize_if Mcp.Communication.Checks.EndpointTenantAccess
    end

    policy action_type(:create) do
      # System only? Or triggered by actions.
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if always()
    end
  end
end
