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
    schema "platform"
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

      change Mcp.Platform.Tenants.Changes.ProvisionTenant
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
    update :suspend do
      accept []
      change set_attribute(:status, :suspended)
    end

    update :activate do
      accept []
      change set_attribute(:status, :active)
    end

    update :cancel do
      accept []
      change set_attribute(:status, :canceled)
    end

    update :update_plan do
      accept [:plan]
    end

    update :complete_onboarding do
      accept []
      # Logic for onboarding completion could go here
    end

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug))
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end

    read :by_plan do
      argument :plan, :atom, allow_nil?: false
      filter expr(plan == ^arg(:plan))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :slug, :string do
      allow_nil? false
      constraints [match: ~r/^[a-z0-9-]+$/]
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
      constraints one_of: [:active, :trial, :suspended, :canceled]
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
    define :by_subdomain, action: :by_subdomain, args: [:subdomain], get?: true
    define :by_custom_domain, action: :by_custom_domain, args: [:domain], get?: true
    define :get_by_schema, action: :get_by_schema, args: [:schema], get?: true
    
    define :suspend
    define :activate
    define :cancel
    define :update_plan
    define :complete_onboarding
    define :by_slug, action: :by_slug, args: [:slug], get?: true
    define :by_status, action: :by_status, args: [:status]
    define :by_plan, action: :by_plan, args: [:plan]
  end

  # Compatibility wrappers for existing code
  def get(id), do: get_by_id(id)
  def delete(tenant, _opts \\ []), do: destroy(tenant)
  def by_subdomain!(subdomain), do: by_subdomain(subdomain) |> handle_bang()
  def by_custom_domain!(domain), do: by_custom_domain(domain) |> handle_bang()
  def by_id!(id), do: get_by_id!(id)

  # Helper for bang methods
  defp handle_bang({:ok, result}), do: result
  defp handle_bang({:error, error}), do: raise(Ash.Error.to_error_class(error))
  defp handle_bang(result), do: result
end
