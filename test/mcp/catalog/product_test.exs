defmodule Mcp.Catalog.ProductTest do
  use Mcp.DataCase, async: false

  alias Mcp.Catalog.Category
  alias Mcp.Catalog.Product

  @moduletag :slow

  # Use the pre-configured test template schema
  @test_tenant "acq_test_template"

  setup do
    Mcp.Repo.query!("SET search_path TO public, platform")
    %{tenant: @test_tenant}
  end

  describe "product creation" do
    test "creates product with valid attributes", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      attrs = %{
        name: "Test Product #{unique_id}",
        sku: "SKU-#{unique_id}",
        price: Money.new(1999, :USD),
        status: :active,
        track_inventory: true,
        quantity_on_hand: 100
      }

      assert {:ok, product} = Product.create(attrs, tenant: tenant)
      assert product.name == "Test Product #{unique_id}"
      assert product.sku == "SKU-#{unique_id}"
      assert product.price == Money.new(1999, :USD)
      assert product.status == :active
      assert product.track_inventory == true
      assert product.quantity_on_hand == 100
    end

    test "requires name", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      attrs = %{
        sku: "SKU-#{unique_id}",
        price: Money.new(1999, :USD)
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Product.create(attrs, tenant: tenant)
      assert Enum.any?(errors, fn e -> e.field == :name end)
    end

    test "requires sku", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      attrs = %{
        name: "Test Product #{unique_id}",
        price: Money.new(1999, :USD)
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Product.create(attrs, tenant: tenant)
      assert Enum.any?(errors, fn e -> e.field == :sku end)
    end

    test "enforces unique sku within tenant", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      attrs = %{
        name: "Test Product #{unique_id}",
        sku: "UNIQUE-SKU-#{unique_id}",
        price: Money.new(1999, :USD)
      }

      assert {:ok, _product1} = Product.create(attrs, tenant: tenant)

      attrs2 = %{
        name: "Another Product #{unique_id}",
        sku: "UNIQUE-SKU-#{unique_id}",
        price: Money.new(2999, :USD)
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Product.create(attrs2, tenant: tenant)
      assert Enum.any?(errors, fn e -> e.field == :sku end)
    end
  end

  describe "list_products" do
    test "returns paginated products", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      # Create multiple products
      for i <- 1..15 do
        attrs = %{
          name: "Product #{unique_id}-#{i}",
          sku: "SKU-LIST-#{unique_id}-#{i}",
          price: Money.new(1000 * i, :USD)
        }

        Product.create!(attrs, tenant: tenant)
      end

      # Get first page
      assert {:ok, page} = Product.list_products(tenant: tenant, page: [limit: 10])
      assert length(page.results) == 10

      # Get second page
      assert {:ok, page2} = Product.list_products(tenant: tenant, page: [limit: 10, offset: 10])
      assert length(page2.results) >= 5
    end

    test "filters by category_id", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      # Create a category
      {:ok, category} =
        Category.create(%{name: "Electronics #{unique_id}"}, tenant: tenant)

      # Create products with and without category
      {:ok, product_with_cat} =
        Product.create(
          %{
            name: "With Category #{unique_id}",
            sku: "CAT-#{unique_id}",
            price: Money.new(1999, :USD),
            category_id: category.id
          },
          tenant: tenant
        )

      {:ok, _product_without_cat} =
        Product.create(
          %{
            name: "Without Category #{unique_id}",
            sku: "NO-CAT-#{unique_id}",
            price: Money.new(2999, :USD)
          },
          tenant: tenant
        )

      assert {:ok, page} =
               Product.list_products(
                 %{category_id: category.id},
                 tenant: tenant
               )

      assert length(page.results) == 1
      assert hd(page.results).id == product_with_cat.id
    end

    test "filters by status", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      # Create products with different statuses
      {:ok, active_product} =
        Product.create(
          %{
            name: "Active Product #{unique_id}",
            sku: "ACTIVE-#{unique_id}",
            price: Money.new(1999, :USD),
            status: :active
          },
          tenant: tenant
        )

      {:ok, _draft_product} =
        Product.create(
          %{
            name: "Draft Product #{unique_id}",
            sku: "DRAFT-#{unique_id}",
            price: Money.new(2999, :USD),
            status: :draft
          },
          tenant: tenant
        )

      assert {:ok, page} =
               Product.list_products(
                 %{status: :active},
                 tenant: tenant
               )

      assert Enum.all?(page.results, fn p -> p.status == :active end)
      assert Enum.any?(page.results, fn p -> p.id == active_product.id end)
    end

    test "searches by name and sku", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      {:ok, product1} =
        Product.create(
          %{
            name: "Searchable Widget #{unique_id}",
            sku: "WIDGET-#{unique_id}",
            price: Money.new(1999, :USD)
          },
          tenant: tenant
        )

      {:ok, _product2} =
        Product.create(
          %{
            name: "Other Thing #{unique_id}",
            sku: "OTHER-#{unique_id}",
            price: Money.new(2999, :USD)
          },
          tenant: tenant
        )

      # Search by name
      assert {:ok, page} =
               Product.list_products(
                 %{search: "Widget"},
                 tenant: tenant
               )

      assert length(page.results) >= 1
      assert Enum.any?(page.results, fn p -> p.id == product1.id end)

      # Search by SKU
      assert {:ok, page} =
               Product.list_products(
                 %{search: "WIDGET-#{unique_id}"},
                 tenant: tenant
               )

      assert length(page.results) == 1
      assert hd(page.results).id == product1.id
    end
  end

  describe "get_product_stats" do
    test "returns aggregate counts", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      # Create products with different statuses
      for i <- 1..3 do
        Product.create!(
          %{
            name: "Active #{unique_id}-#{i}",
            sku: "STATS-ACTIVE-#{unique_id}-#{i}",
            price: Money.new(1999, :USD),
            status: :active
          },
          tenant: tenant
        )
      end

      for i <- 1..2 do
        Product.create!(
          %{
            name: "Draft #{unique_id}-#{i}",
            sku: "STATS-DRAFT-#{unique_id}-#{i}",
            price: Money.new(1999, :USD),
            status: :draft
          },
          tenant: tenant
        )
      end

      Product.create!(
        %{
          name: "Archived #{unique_id}",
          sku: "STATS-ARCHIVED-#{unique_id}",
          price: Money.new(1999, :USD),
          status: :archived
        },
        tenant: tenant
      )

      assert {:ok, stats} = Product.get_product_stats(tenant: tenant)
      assert stats.total_products >= 6
      assert stats.active_products >= 3
      assert stats.draft_products >= 2
    end
  end

  describe "calculations" do
    test "is_low_stock returns true when quantity below threshold", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      {:ok, product} =
        Product.create(
          %{
            name: "Low Stock Product #{unique_id}",
            sku: "LOW-STOCK-#{unique_id}",
            price: Money.new(1999, :USD),
            track_inventory: true,
            quantity_on_hand: 5,
            low_stock_threshold: 10
          },
          tenant: tenant
        )

      {:ok, product} = Product.get_by_id(product.id, tenant: tenant, load: [:is_low_stock])
      assert product.is_low_stock == true
    end

    test "is_low_stock returns false when quantity above threshold", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      {:ok, product} =
        Product.create(
          %{
            name: "Well Stocked Product #{unique_id}",
            sku: "WELL-STOCKED-#{unique_id}",
            price: Money.new(1999, :USD),
            track_inventory: true,
            quantity_on_hand: 100,
            low_stock_threshold: 10
          },
          tenant: tenant
        )

      {:ok, product} = Product.get_by_id(product.id, tenant: tenant, load: [:is_low_stock])
      assert product.is_low_stock == false
    end

    test "margin_percentage calculates correctly", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      {:ok, product} =
        Product.create(
          %{
            name: "Margin Product #{unique_id}",
            sku: "MARGIN-#{unique_id}",
            price: Money.new(10_000, :USD),
            cost: Money.new(6_000, :USD)
          },
          tenant: tenant
        )

      {:ok, product} = Product.get_by_id(product.id, tenant: tenant, load: [:margin_percentage])
      # (price - cost) / price * 100 = (10000 - 6000) / 10000 * 100 = 40%
      assert product.margin_percentage == Decimal.new("40.00")
    end
  end

  describe "product with category" do
    test "can associate product with category", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      {:ok, category} = Category.create(%{name: "Test Category #{unique_id}"}, tenant: tenant)

      {:ok, product} =
        Product.create(
          %{
            name: "Categorized Product #{unique_id}",
            sku: "CAT-PROD-#{unique_id}",
            price: Money.new(1999, :USD),
            category_id: category.id
          },
          tenant: tenant
        )

      {:ok, loaded_product} = Product.get_by_id(product.id, tenant: tenant, load: [:category])
      assert loaded_product.category.id == category.id
    end
  end
end
