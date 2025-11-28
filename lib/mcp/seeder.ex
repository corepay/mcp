defmodule Mcp.Seeder do
  @moduledoc """
  Handles seeding of the database with realistic development data.
  """

  require Ash.Query
  alias Mcp.Accounts.User
  alias Mcp.Platform.{Tenant, Merchant, Store}
  alias Mcp.Platform.TenantUserManager

  @password "Password123!"

  def run do
    IO.puts("🌱 Starting Seeding...")

    # 1. Create Platform Admin
    _admin = ensure_user("admin@platform.local", @password)
    IO.puts("  - Platform Admin: admin@platform.local / #{@password}")

    # 2. Create Tenants
    seed_tenant("Acme Corp", "acme", "acme")
    seed_tenant("Globex Corp", "globex", "globex")

    IO.puts("✅ Seeding Complete!")
  end

  defp seed_tenant(name, slug, subdomain) do
    tenant = ensure_tenant(name, slug, subdomain)
    
    # Create Tenant Admin
    admin_email = "admin@#{slug}.local"
    user = ensure_user(admin_email, @password)
    ensure_tenant_user(tenant, user, :owner)
    IO.puts("  - Tenant Admin (#{name}): #{admin_email} / #{@password}")

    # Create Merchants & Stores
    case slug do
      "acme" ->
        m1 = ensure_merchant(tenant, "Acme Retail", "acme-retail")
        ensure_store(tenant, m1, "Acme Downtown", "downtown")
        ensure_store(tenant, m1, "Acme Mall", "mall")

        m2 = ensure_merchant(tenant, "Acme Online", "acme-online")
        ensure_store(tenant, m2, "Acme Web Store", "web")

      "globex" ->
        m1 = ensure_merchant(tenant, "Globex Supplies", "globex-supplies")
        ensure_store(tenant, m1, "Globex HQ", "hq")

      _ -> :ok
    end
  end

  defp ensure_user(email, password) do
    case User.by_email(email) do
      {:ok, user} ->
        user

      {:error, _} ->
        User.register!(email, password, password)
    end
  end

  defp ensure_tenant(name, slug, subdomain) do
    case Tenant.by_subdomain(subdomain) do
      {:ok, tenant} ->
        tenant

      {:error, _} ->
        tenant = Tenant.create!(%{
          name: name,
          slug: slug,
          subdomain: subdomain,
          plan: :enterprise
        })
        
        IO.puts("  - Running migrations for #{tenant.company_schema}...")
        Ecto.Migrator.run(Mcp.Repo, "priv/repo/tenant_migrations", :up, all: true, prefix: tenant.company_schema)
        
        tenant
    end
  end

  defp ensure_tenant_user(tenant, user, role) do
    # Check if already linked
    users = TenantUserManager.get_tenant_users(tenant.id) |> elem(1)
    
    unless Enum.any?(users, fn u -> u["user_id"] == user.id end) do
      # Simulate adding user to tenant settings
      current_settings = tenant.settings || %{}
      _current_users = Map.get(current_settings, "users", [])
      
      _new_user_entry = %{
        "user_id" => user.id,
        "email" => user.email,
        "role" => to_string(role),
        "joined_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      # updated_users = [new_user_entry | current_users]
      # updated_settings = Map.put(current_settings, "users", updated_users)
      
      # Tenant.update!(tenant, %{settings: updated_settings})
    end
  end

  defp ensure_merchant(tenant, name, slug) do
    require Ash.Query
    
    exists = 
      Merchant
      |> Ash.Query.filter(slug == ^slug)
      |> Ash.Query.set_tenant(tenant.company_schema)
      |> Ash.read_one()
      
    IO.inspect(exists, label: "Merchant Search Result (#{slug})")

    case exists do
      {:ok, nil} ->
        IO.puts("Merchant search returned {:ok, nil}, creating...")
        create_merchant(tenant, name, slug)
      {:ok, merchant} -> 
        IO.inspect(merchant, label: "Found Merchant")
        merchant
      {:error, _} -> 
        IO.puts("Merchant not found (error), creating...")
        create_merchant(tenant, name, slug)
      nil -> 
        IO.puts("Merchant search returned nil, creating...")
        create_merchant(tenant, name, slug)
    end
  end

  defp create_merchant(tenant, name, slug) do
    Merchant.create!(%{
      business_name: name,
      slug: slug,
      subdomain: "#{slug}-#{tenant.slug}",
      status: :active
    }, tenant: tenant.company_schema)
  end

  defp ensure_store(tenant, merchant, name, slug) do
    require Ash.Query
    
    exists =
      Store
      |> Ash.Query.filter(slug == ^slug and merchant_id == ^merchant.id)
      |> Ash.Query.set_tenant(tenant.company_schema)
      |> Ash.read_one()
      
    case exists do
      {:ok, store} -> store
      {:error, _} -> create_store(tenant, merchant, name, slug)
      nil -> create_store(tenant, merchant, name, slug)
    end
  end

  defp create_store(tenant, merchant, name, slug) do
    Store.create!(%{
      name: name,
      slug: slug,
      merchant_id: merchant.id,
      status: :active
    }, tenant: tenant.company_schema)
  end
end
