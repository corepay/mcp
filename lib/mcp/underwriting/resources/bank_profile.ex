defmodule Mcp.Underwriting.BankProfile do
  @moduledoc """
  Represents a specific underwriting profile or "appetite" for a Processor.
  Determines placement logic for applications.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(role == :admin)
    end
  end

  postgres do
    table "underwriting_bank_profiles"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy, :update]

    create :create do
      primary? true
      accept [:name, :appetite_rules, :risk_weight, :is_default, :processor_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :appetite_rules, :map do
      description "JSON matrix defining industries, max volume, and risk thresholds."

      default %{
        "allowed_industries" => [],
        "min_score" => 70,
        "max_monthly_volume" => 100_000
      }
    end

    attribute :risk_weight, :integer do
      description "Lower is safer."
      default 50
    end

    attribute :is_default, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :processor, Mcp.Underwriting.Processor do
      allow_nil? false
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
