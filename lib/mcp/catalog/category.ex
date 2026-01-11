defmodule Mcp.Catalog.Category do
  @moduledoc """
  Category resource for organizing products.

  Supports nested categories via parent_id for hierarchical organization.
  """

  use Ash.Resource,
    domain: Mcp.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "categories"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :description, :parent_id]

      change fn changeset, _context ->
        if Ash.Changeset.get_attribute(changeset, :slug) do
          changeset
        else
          name = Ash.Changeset.get_attribute(changeset, :name) || ""

          slug =
            name
            |> String.downcase()
            |> String.replace(~r/[^a-z0-9\s-]/, "")
            |> String.replace(~r/\s+/, "-")
            |> String.trim("-")

          # Add unique suffix to prevent collisions
          slug = "#{slug}-#{System.unique_integer([:positive])}"

          Ash.Changeset.change_attribute(changeset, :slug, slug)
        end
      end
    end

    update :update do
      primary? true
      accept [:name, :slug, :description, :parent_id]
    end

    read :list do
      primary? true
      pagination offset?: true, default_limit: 25
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :slug, :string

    attribute :description, :string

    attribute :parent_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :parent, Mcp.Catalog.Category do
      source_attribute :parent_id
      destination_attribute :id
      allow_nil? true
    end

    has_many :subcategories, Mcp.Catalog.Category do
      source_attribute :id
      destination_attribute :parent_id
    end

    has_many :products, Mcp.Catalog.Product
  end

  code_interface do
    define :list, action: :list
    define :create
    define :update
    define :destroy
    define :by_id, action: :by_id, args: [:id]
  end
end
