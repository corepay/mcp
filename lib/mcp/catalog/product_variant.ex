defmodule Mcp.Catalog.ProductVariant do
  @moduledoc """
  ProductVariant resource for product variations.

  Represents different versions of a product (e.g., size, color combinations).
  Each variant has its own SKU, price, and inventory tracking.
  """

  use Ash.Resource,
    domain: Mcp.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "product_variants"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_variant_sku_per_tenant, [:sku]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :sku,
        :price,
        :quantity_on_hand,
        :option_values,
        :product_id
      ]
    end

    update :update do
      primary? true

      accept [
        :name,
        :sku,
        :price,
        :quantity_on_hand,
        :option_values
      ]
    end

    read :list do
      pagination offset?: true, default_limit: 25
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    read :by_product do
      argument :product_id, :uuid, allow_nil?: false
      filter expr(product_id == ^arg(:product_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Variant name, e.g., 'Small / Blue'"
    end

    attribute :sku, :string do
      allow_nil? false
    end

    attribute :price, AshMoney.Types.Money

    attribute :quantity_on_hand, :integer do
      default 0
      allow_nil? false
    end

    attribute :option_values, :map do
      default %{}
      allow_nil? false
      description ~S(Option values, e.g., %{"size" => "small", "color" => "blue"})
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Mcp.Catalog.Product do
      allow_nil? false
    end
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :list, action: :list
    define :by_id, action: :by_id, args: [:id]
    define :by_product, action: :by_product, args: [:product_id]
  end
end
