defmodule Mcp.Platform.Reseller do
  @moduledoc """
  Reseller (White-label Partner) resource.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    # , AshPaperTrail.Resource]
    extensions: [AshJsonApi.Resource, AshArchival, AshOban],
    notifiers: []

  # paper_trail do
  # end

  postgres do
    table "resellers"
    repo(Mcp.Repo)
  end

  json_api do
    type "reseller"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :slug,
        :company_name,
        :subdomain,
        :custom_domain,
        :contact_name,
        :contact_email,
        :contact_phone,
        :developer_id,
        :commission_rate,
        :status
      ]

      change run_oban_trigger(:sync_to_graph)
    end

    update :update do
      primary? true

      accept [
        :company_name,
        :subdomain,
        :custom_domain,
        :contact_name,
        :contact_email,
        :contact_phone,
        :commission_rate,
        :status
      ]

      change run_oban_trigger(:sync_to_graph)
    end

    update :sync_to_graph do
      accept []
      require_atomic? false

      change fn changeset, _ ->
        Ash.Changeset.after_action(changeset, fn _changeset, reseller ->
          Mcp.Graph.Notifier.sync_to_graph(Mcp.Platform.Reseller, reseller, reseller.id)
          {:ok, reseller}
        end)
      end
    end
  end

  oban do
    triggers do
      trigger :sync_to_graph do
        action :sync_to_graph
        queue(:graph_sync)
        worker_module_name(:reseller_graph_sync)
        scheduler_module_name(:reseller_graph_sync_scheduler)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :company_name, :string do
      allow_nil? false
    end

    attribute :subdomain, :string do
      allow_nil? false
    end

    attribute :custom_domain, :string

    attribute :contact_name, :string do
      allow_nil? false
    end

    attribute :contact_email, :string do
      allow_nil? false
    end

    attribute :contact_phone, :string

    # Business & Contract
    attribute :commission_rate, :decimal, default: 0.00
    attribute :revenue_share_model, :map, default: %{}
    attribute :banking_info, :map, default: %{}, sensitive?: true
    attribute :tax_id, :string

    attribute :contract_start_date, :date
    attribute :contract_end_date, :date

    attribute :support_tier, :atom do
      constraints one_of: [:standard, :priority]
      default :standard
    end

    # White Label & Branding
    attribute :branding, :map, default: %{}
    attribute :settings, :map, default: %{}

    attribute :max_merchants, :integer, default: 50

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :pending]
      default :active
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Mcp.Accounts.User
    belongs_to :developer, Mcp.Platform.Developer
    has_many :merchants, Mcp.Platform.Merchant
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
  end
end
