defmodule Mcp.Platform.TenantSettings do
  @moduledoc """
  Resource representing settings for a tenant.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [Ash.Resource.Dsl]

  alias Mcp.Platform.TenantSettings.Changes
  alias Mcp.Repo

  postgres do
    table "tenant_settings"
    repo(Repo)
  end

  actions do
    defaults [:read, :destroy]

    create :create_setting do
      primary? true

      accept [
        :tenant_id,
        :category,
        :key,
        :value,
        :value_type,
        :description,
        :last_updated_by,
        :encrypted,
        :validation_rules
      ]

      change &Changes.validate_value/2
      change &Changes.encrypt_value/2
    end

    update :update_setting do
      accept [:value, :last_updated_by]
      change &Changes.validate_value/2
      change &Changes.encrypt_value/2
      require_atomic? false
    end

    read :by_tenant do
      argument :tenant_id, :string, allow_nil?: false
      filter expr(tenant_id == ^arg(:tenant_id))
    end

    read :by_category do
      argument :tenant_id, :string, allow_nil?: false
      argument :category, :atom, allow_nil?: false
      filter expr(tenant_id == ^arg(:tenant_id) and category == ^arg(:category))
    end

    read :get_setting do
      argument :tenant_id, :string, allow_nil?: false
      argument :category, :atom, allow_nil?: false
      argument :key, :string, allow_nil?: false

      filter expr(
               tenant_id == ^arg(:tenant_id) and category == ^arg(:category) and key == ^arg(:key)
             )

      # Expect one result
      get? true
    end

    destroy :destroy_setting do
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :string do
      allow_nil? false
    end

    attribute :category, :atom do
      allow_nil? false

      constraints one_of: [
                    :general,
                    :billing,
                    :business_info,
                    :security,
                    :notifications,
                    :integrations
                  ]
    end

    attribute :key, :string do
      allow_nil? false
    end

    attribute :value, :map do
      allow_nil? true
    end

    attribute :value_type, :atom do
      allow_nil? false
      constraints one_of: [:string, :integer, :float, :boolean, :map, :array, :json]
      default :string
    end

    attribute :description, :string
    attribute :last_updated_by, :string
    attribute :encrypted, :boolean, default: false
    attribute :validation_rules, :map, default: %{}

    timestamps()
  end

  identities do
    identity :tenant_category_key, [:tenant_id, :category, :key]
  end
end
