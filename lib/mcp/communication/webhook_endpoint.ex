defmodule Mcp.Communication.WebhookEndpoint do
  @moduledoc """
  Resource representing webhook endpoints for event delivery.
  """
  use Ash.Resource,
    otp_app: :mcp,
    domain: Mcp.Communication,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "webhook_endpoints"
    repo(Mcp.Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    attribute :secret, :string do
      allow_nil? false
      sensitive? true
      # Only expose on creation or explicit rotate
      public? false
    end

    attribute :events, {:array, :string} do
      allow_nil? false
      public? true
    end

    attribute :enabled, :boolean do
      allow_nil? false
      default true
      public? true
    end

    attribute :description, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      domain Mcp.Platform
      allow_nil? false
    end

    has_many :deliveries, Mcp.Communication.WebhookDelivery do
      destination_attribute :endpoint_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:url, :events, :enabled, :description, :tenant_id]
      change set_attribute(:secret, &Ash.UUID.generate/0)
    end

    update :update do
      accept [:url, :events, :enabled, :description]
    end

    update :rotate_secret do
      change set_attribute(:secret, &Ash.UUID.generate/0)
    end
  end

  policies do
    # Direct tenant access policy
    policy action_type(:create) do
      authorize_if Mcp.Platform.Checks.TenantIdAccessForCreate
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if Mcp.Platform.Checks.TenantIdAccess
    end
  end
end
