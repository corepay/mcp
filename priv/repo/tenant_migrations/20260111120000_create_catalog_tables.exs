defmodule Mcp.Repo.TenantMigrations.CreateCatalogTables do
  @moduledoc """
  Creates the catalog tables: categories, products, and product_variants.
  These tables are tenant-scoped for multi-tenant isolation.
  """

  use Ecto.Migration

  def up do
    # Create categories table first (products reference it)
    create table(:categories, primary_key: false, prefix: prefix()) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :slug, :text
      add :description, :text
      add :parent_id, :uuid

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    # Self-referencing foreign key for nested categories
    alter table(:categories, prefix: prefix()) do
      modify :parent_id,
             references(:categories,
               column: :id,
               name: "categories_parent_id_fkey",
               type: :uuid,
               prefix: prefix(),
               on_delete: :nilify_all
             )
    end

    # Create products table
    create table(:products, primary_key: false, prefix: prefix()) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :sku, :text, null: false
      add :description, :text
      add :price, :money_with_currency, null: false
      add :compare_at_price, :money_with_currency
      add :cost, :money_with_currency
      add :status, :text, null: false, default: "draft"
      add :track_inventory, :boolean, null: false, default: false
      add :quantity_on_hand, :bigint, null: false, default: 0
      add :low_stock_threshold, :bigint, null: false, default: 10
      add :image_url, :text
      add :images, {:array, :text}, null: false, default: []
      add :metadata, :map, null: false, default: %{}

      add :category_id,
          references(:categories,
            column: :id,
            name: "products_category_id_fkey",
            type: :uuid,
            prefix: prefix(),
            on_delete: :nilify_all
          )

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:products, [:sku], name: "products_unique_sku_per_tenant_index")

    # Create product_variants table
    create table(:product_variants, primary_key: false, prefix: prefix()) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :sku, :text, null: false
      add :price, :money_with_currency
      add :quantity_on_hand, :bigint, null: false, default: 0
      add :option_values, :map, null: false, default: %{}

      add :product_id,
          references(:products,
            column: :id,
            name: "product_variants_product_id_fkey",
            type: :uuid,
            prefix: prefix(),
            on_delete: :delete_all
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:product_variants, [:sku],
             name: "product_variants_unique_variant_sku_per_tenant_index"
           )
  end

  def down do
    drop_if_exists unique_index(:product_variants, [:sku],
                     name: "product_variants_unique_variant_sku_per_tenant_index"
                   )

    drop constraint(:product_variants, "product_variants_product_id_fkey")
    drop table(:product_variants, prefix: prefix())

    drop_if_exists unique_index(:products, [:sku], name: "products_unique_sku_per_tenant_index")
    drop constraint(:products, "products_category_id_fkey")
    drop table(:products, prefix: prefix())

    drop constraint(:categories, "categories_parent_id_fkey")
    drop table(:categories, prefix: prefix())
  end
end
