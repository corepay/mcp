defmodule Mcp.Catalog.CategoryTest do
  use Mcp.DataCase, async: false

  alias Mcp.Catalog.Category

  @moduletag :slow

  # Use the pre-configured test template schema
  @test_tenant "acq_test_template"

  setup do
    Mcp.Repo.query!("SET search_path TO public, platform")
    %{tenant: @test_tenant}
  end

  describe "category creation" do
    test "creates category with valid attributes", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      attrs = %{
        name: "Electronics #{unique_id}",
        description: "Electronic devices and accessories"
      }

      assert {:ok, category} = Category.create(attrs, tenant: tenant)
      assert category.name == "Electronics #{unique_id}"
      assert category.description == "Electronic devices and accessories"
      # Slug should be auto-generated from name
      assert category.slug != nil
    end

    test "requires name", %{tenant: tenant} do
      attrs = %{
        description: "Description without name"
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Category.create(attrs, tenant: tenant)
      assert Enum.any?(errors, fn e -> e.field == :name end)
    end

    test "creates nested category with parent_id", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      # Create parent category
      {:ok, parent} =
        Category.create(
          %{name: "Parent Category #{unique_id}"},
          tenant: tenant
        )

      # Create child category
      {:ok, child} =
        Category.create(
          %{
            name: "Child Category #{unique_id}",
            parent_id: parent.id
          },
          tenant: tenant
        )

      assert child.parent_id == parent.id
    end
  end

  describe "category queries" do
    test "lists categories", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      # Create multiple categories
      for i <- 1..5 do
        Category.create!(
          %{name: "Category #{unique_id}-#{i}"},
          tenant: tenant
        )
      end

      assert {:ok, page} = Category.list(tenant: tenant)
      assert length(page.results) >= 5
    end

    test "gets category by id", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      {:ok, created} =
        Category.create(
          %{name: "Findable Category #{unique_id}"},
          tenant: tenant
        )

      assert {:ok, found} = Category.by_id(created.id, tenant: tenant)
      assert found.id == created.id
      assert found.name == "Findable Category #{unique_id}"
    end
  end

  describe "category update" do
    test "updates category attributes", %{tenant: tenant} do
      unique_id = System.unique_integer([:positive])

      {:ok, category} =
        Category.create(
          %{name: "Original Name #{unique_id}"},
          tenant: tenant
        )

      {:ok, updated} =
        Category.update(
          category,
          %{name: "Updated Name #{unique_id}", description: "New description"}
        )

      assert updated.name == "Updated Name #{unique_id}"
      assert updated.description == "New description"
    end
  end
end
