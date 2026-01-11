defmodule Mcp.Catalog.Product do
  @moduledoc """
  Product resource for the Catalog domain.

  Manages product information including pricing, inventory, and categorization.
  Products are tenant-scoped for multi-tenant isolation.
  """

  use Ash.Resource,
    domain: Mcp.Catalog,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  postgres do
    table "products"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_sku_per_tenant, [:sku]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :sku,
        :description,
        :price,
        :compare_at_price,
        :cost,
        :status,
        :track_inventory,
        :quantity_on_hand,
        :low_stock_threshold,
        :image_url,
        :images,
        :metadata,
        :category_id
      ]
    end

    update :update do
      primary? true

      accept [
        :name,
        :sku,
        :description,
        :price,
        :compare_at_price,
        :cost,
        :status,
        :track_inventory,
        :quantity_on_hand,
        :low_stock_threshold,
        :image_url,
        :images,
        :metadata,
        :category_id
      ]
    end

    read :list_products do
      argument :category_id, :uuid
      argument :status, :atom
      argument :search, :string

      pagination offset?: true, default_limit: 25, max_page_size: 100

      prepare fn query, _context ->
        query
        |> apply_category_filter()
        |> apply_status_filter()
        |> apply_search_filter()
      end
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end

    action :get_product_stats, :map do
      run fn _input, context ->
        tenant = context.tenant

        total_query =
          __MODULE__
          |> Ash.Query.for_read(:read, %{}, tenant: tenant)

        active_query =
          __MODULE__
          |> Ash.Query.for_read(:read, %{}, tenant: tenant)
          |> Ash.Query.filter(status == :active)

        draft_query =
          __MODULE__
          |> Ash.Query.for_read(:read, %{}, tenant: tenant)
          |> Ash.Query.filter(status == :draft)

        with {:ok, total} <- Ash.count(total_query, tenant: tenant),
             {:ok, active} <- Ash.count(active_query, tenant: tenant),
             {:ok, draft} <- Ash.count(draft_query, tenant: tenant) do
          {:ok, %{total_products: total, active_products: active, draft_products: draft}}
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :sku, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :price, AshMoney.Types.Money do
      allow_nil? false
    end

    attribute :compare_at_price, AshMoney.Types.Money

    attribute :cost, AshMoney.Types.Money

    attribute :status, :atom do
      constraints one_of: [:draft, :active, :archived]
      default :draft
      allow_nil? false
    end

    attribute :track_inventory, :boolean do
      default false
      allow_nil? false
    end

    attribute :quantity_on_hand, :integer do
      default 0
      allow_nil? false
    end

    attribute :low_stock_threshold, :integer do
      default 10
      allow_nil? false
    end

    attribute :image_url, :string

    attribute :images, {:array, :string} do
      default []
      allow_nil? false
    end

    attribute :metadata, :map do
      default %{}
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :category, Mcp.Catalog.Category do
      allow_nil? true
    end

    has_many :variants, Mcp.Catalog.ProductVariant
  end

  calculations do
    calculate :is_low_stock,
              :boolean,
              expr(track_inventory and quantity_on_hand < low_stock_threshold)

    calculate :margin_percentage,
              :decimal,
              expr(
                if not is_nil(cost) and not is_nil(price) do
                  # Calculate margin as ((price - cost) / price) * 100
                  # money_with_currency is a composite type (currency_code, amount)
                  # Use parentheses to access composite type fields: (column).field
                  fragment(
                    "CASE WHEN ((?).amount)::numeric > 0 THEN ROUND(((((?)::money_with_currency).amount - ((?)::money_with_currency).amount) / ((?)::money_with_currency).amount) * 100, 2) ELSE NULL END",
                    price,
                    price,
                    cost,
                    price
                  )
                else
                  nil
                end
              )
  end

  aggregates do
    count :variant_count, :variants
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :list_products
    define :get_by_id, action: :by_id, args: [:id]
    define :get_product_stats
  end

  # Private helper functions for query preparation
  defp apply_category_filter(query) do
    case Ash.Query.get_argument(query, :category_id) do
      nil -> query
      category_id -> Ash.Query.filter(query, category_id == ^category_id)
    end
  end

  defp apply_status_filter(query) do
    case Ash.Query.get_argument(query, :status) do
      nil -> query
      status -> Ash.Query.filter(query, status == ^status)
    end
  end

  defp apply_search_filter(query) do
    case Ash.Query.get_argument(query, :search) do
      nil ->
        query

      "" ->
        query

      search ->
        search_pattern = "%#{search}%"
        Ash.Query.filter(query, ilike(name, ^search_pattern) or ilike(sku, ^search_pattern))
    end
  end
end
