defmodule Mcp.Underwriting.Boarding do
  @moduledoc """
  Represents a merchant boarding record to a processor.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy :context
  end

  policies do
    # Platform Admin bypass
    policy expr(role == :admin) do
      authorize_if always()
    end

    # Tenant users can only access boardings within their own tenant context.
    # Since we use context multitenancy, the schema already isolates data.
    # This policy ensures the user is authenticated.
    policy always() do
      authorize_if actor_present()
    end
  end

  postgres do
    table "underwriting_boardings"
    repo(Mcp.Repo)
  end

  actions do
    read :read do
      primary? true
    end

    destroy :destroy do
      primary? true
    end

    update :update do
      primary? true
      accept [:mid, :tid, :status, :metadata, :error_metadata]
    end

    create :create do
      primary? true

      accept [
        :mid,
        :tid,
        :status,
        :metadata,
        :application_id,
        :processor_id,
        :bank_profile_id,
        :rationale,
        :error_metadata
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :mid, :string, allow_nil?: true
    attribute :tid, :string, allow_nil?: true

    attribute :status, :atom do
      constraints one_of: [:pending, :active, :failed]
      default :pending
    end

    attribute :metadata, :map do
      default %{}
    end

    attribute :rationale, :string do
      description "The logic/reasoning from PlacementIntelligence for choosing this bank."
    end

    attribute :error_metadata, :map do
      description "Stores detailed error info if boarding fails."
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application do
      allow_nil? false
    end

    belongs_to :processor, Mcp.Underwriting.Processor do
      allow_nil? false
    end

    belongs_to :bank_profile, Mcp.Underwriting.BankProfile do
      allow_nil? false
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end
