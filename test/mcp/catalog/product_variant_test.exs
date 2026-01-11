defmodule Mcp.Catalog.ProductVariantTest do
  use Mcp.DataCase, async: false

  alias Mcp.Catalog.Product
  alias Mcp.Catalog.ProductVariant

  @moduletag :slow

  # Use the pre-configured test template schema
  @test_tenant "acq_test_template"

  setup do
    Mcp.Repo.query!("SET search_path TO public, platform")
    %{tenant: @test_tenant}
  end

  defp create_product(tenant) do
    unique_id = System.unique_integer([:positive])

    Product.create!(
      %{
        name: "Test Product #{unique_id}",
        sku: "PROD-#{unique_id}",
        price: Money.new(1999, :USD)
      },
      tenant: tenant
    )
  end

  describe "variant creation" do
    test "creates variant with required fields (name, sku, product_id)", %{tenant: tenant} do
      product = create_product(tenant)
      unique_id = System.unique_integer([:positive])

      attrs = %{
        name: "Small / Blue",
        sku: "VAR-#{unique_id}",
        product_id: product.id
      }

      assert {:ok, variant} = ProductVariant.create(attrs, tenant: tenant)
      assert variant.name == "Small / Blue"
      assert variant.sku == "VAR-#{unique_id}"
      assert variant.product_id == product.id
      assert variant.quantity_on_hand == 0
      assert variant.option_values == %{}
    end

    test "creates variant with all attributes", %{tenant: tenant} do
      product = create_product(tenant)
      unique_id = System.unique_integer([:positive])

      attrs = %{
        name: "Large / Red",
        sku: "VAR-FULL-#{unique_id}",
        product_id: product.id,
        price: Money.new(2499, :USD),
        quantity_on_hand: 50,
        option_values: %{"size" => "large", "color" => "red"}
      }

      assert {:ok, variant} = ProductVariant.create(attrs, tenant: tenant)
      assert variant.name == "Large / Red"
      assert variant.sku == "VAR-FULL-#{unique_id}"
      assert variant.price == Money.new(2499, :USD)
      assert variant.quantity_on_hand == 50
      assert variant.option_values == %{"size" => "large", "color" => "red"}
    end

    test "requires name", %{tenant: tenant} do
      product = create_product(tenant)
      unique_id = System.unique_integer([:positive])

      attrs = %{
        sku: "VAR-NO-NAME-#{unique_id}",
        product_id: product.id
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               ProductVariant.create(attrs, tenant: tenant)

      assert Enum.any?(errors, fn e -> e.field == :name end)
    end

    test "requires sku", %{tenant: tenant} do
      product = create_product(tenant)

      attrs = %{
        name: "No SKU Variant",
        product_id: product.id
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               ProductVariant.create(attrs, tenant: tenant)

      assert Enum.any?(errors, fn e -> e.field == :sku end)
    end

    test "requires valid product reference", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])
      fake_product_id = Ecto.UUID.generate()

      attrs = %{
        name: "Orphan Variant",
        sku: "VAR-ORPHAN-#{unique_id}",
        product_id: fake_product_id
      }

      assert {:error, _error} = ProductVariant.create(attrs, tenant: tenant)
    end

    test "enforces unique sku within tenant", %{tenant: tenant} do
      product = create_product(tenant)
      unique_id = System.unique_integer([:positive])

      attrs = %{
        name: "First Variant",
        sku: "UNIQUE-VAR-#{unique_id}",
        product_id: product.id
      }

      assert {:ok, _variant1} = ProductVariant.create(attrs, tenant: tenant)

      attrs2 = %{
        name: "Second Variant",
        sku: "UNIQUE-VAR-#{unique_id}",
        product_id: product.id
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               ProductVariant.create(attrs2, tenant: tenant)

      assert Enum.any?(errors, fn e -> e.field == :sku end)
    end
  end

  describe "by_product action" do
    test "returns variants for specific product", %{tenant: tenant} do
      product1 = create_product(tenant)
      product2 = create_product(tenant)
      unique_id = System.unique_integer([:positive])

      # Create variants for product1
      {:ok, variant1} =
        ProductVariant.create(
          %{
            name: "Product1 Variant A",
            sku: "P1-VAR-A-#{unique_id}",
            product_id: product1.id
          },
          tenant: tenant
        )

      {:ok, variant2} =
        ProductVariant.create(
          %{
            name: "Product1 Variant B",
            sku: "P1-VAR-B-#{unique_id}",
            product_id: product1.id
          },
          tenant: tenant
        )

      # Create variant for product2
      {:ok, _variant3} =
        ProductVariant.create(
          %{
            name: "Product2 Variant",
            sku: "P2-VAR-#{unique_id}",
            product_id: product2.id
          },
          tenant: tenant
        )

      # Query variants for product1
      assert {:ok, variants} = ProductVariant.by_product(product1.id, tenant: tenant)
      assert length(variants) == 2

      variant_ids = Enum.map(variants, & &1.id)
      assert variant1.id in variant_ids
      assert variant2.id in variant_ids
    end

    test "returns empty list when product has no variants", %{tenant: tenant} do
      product = create_product(tenant)

      assert {:ok, variants} = ProductVariant.by_product(product.id, tenant: tenant)
      assert variants == []
    end
  end

  describe "variant update" do
    test "updates variant attributes", %{tenant: tenant} do
      product = create_product(tenant)
      unique_id = System.unique_integer([:positive])

      {:ok, variant} =
        ProductVariant.create(
          %{
            name: "Original Name",
            sku: "VAR-UPDATE-#{unique_id}",
            product_id: product.id,
            quantity_on_hand: 10
          },
          tenant: tenant
        )

      {:ok, updated} =
        ProductVariant.update(
          variant,
          %{
            name: "Updated Name",
            quantity_on_hand: 25,
            option_values: %{"size" => "medium"}
          }
        )

      assert updated.name == "Updated Name"
      assert updated.quantity_on_hand == 25
      assert updated.option_values == %{"size" => "medium"}
    end
  end

  describe "by_id action" do
    test "retrieves variant by id", %{tenant: tenant} do
      product = create_product(tenant)
      unique_id = System.unique_integer([:positive])

      {:ok, created} =
        ProductVariant.create(
          %{
            name: "Findable Variant",
            sku: "VAR-FIND-#{unique_id}",
            product_id: product.id
          },
          tenant: tenant
        )

      assert {:ok, found} = ProductVariant.by_id(created.id, tenant: tenant)
      assert found.id == created.id
      assert found.name == "Findable Variant"
    end
  end
end
