defmodule Mcp.Platform.Tenant do
  @moduledoc """
  Tenant resource for managing multi-tenancy.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "tenants"
    schema("platform")
    repo(Mcp.Repo)

    custom_indexes do
      index([:slug], unique: true)
      index([:subdomain], unique: true)
      index([:custom_domain], unique: true, where: "custom_domain IS NOT NULL")
      index([:company_schema], unique: true)
    end
  end

  json_api do
    type "tenant"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :subdomain, :custom_domain, :plan]

      change fn changeset, _ ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :company_schema,
          "acq_#{Ecto.UUID.generate()}"
        )
      end
    end

    update :update do
      primary? true
      accept [:name, :slug, :subdomain, :custom_domain, :plan, :status]
    end

    read :by_subdomain do
      argument :subdomain, :string, allow_nil?: false
      filter expr(subdomain == ^arg(:subdomain))
    end

    read :by_custom_domain do
      argument :domain, :string, allow_nil?: false
      filter expr(custom_domain == ^arg(:domain))
    end

    read :get_by_schema do
      argument :schema, :string, allow_nil?: false
      filter expr(company_schema == ^arg(:schema))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      source :company_name
    end

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :company_schema, :string do
      allow_nil? false
      writable? false
    end

    attribute :subdomain, :string do
      allow_nil? false
    end

    attribute :custom_domain, :string

    attribute :plan, :atom do
      constraints one_of: [:starter, :professional, :enterprise]
      default :starter
      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:active, :trial, :suspended, :canceled, :deleted]
      default :active
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    has_one :account, Mcp.Finance.Account
    has_one :settings, Mcp.Platform.TenantSettings
    has_one :branding, Mcp.Platform.TenantBranding
  end

  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :get_by_id, action: :read, get_by: [:id]
    define :by_subdomain, action: :by_subdomain, args: [:subdomain]
    define :by_custom_domain, action: :by_custom_domain, args: [:domain]
    define :get_by_schema, action: :get_by_schema, args: [:schema], get?: true
  end

  # Compatibility wrappers for existing code
  def get(id), do: get_by_id(id)
  def delete(tenant), do: destroy(tenant)
  def by_subdomain!(subdomain), do: by_subdomain(subdomain) |> handle_bang()
  def by_custom_domain!(domain), do: by_custom_domain(domain) |> handle_bang()
  def by_id!(id), do: get_by_id!(id)

  # Helper for bang methods
  defp handle_bang({:ok, result}), do: result
  defp handle_bang({:error, error}), do: raise(Ash.Error.to_error_class(error))
  defp handle_bang(result), do: result
end
