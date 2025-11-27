defmodule Mcp.Seeder do
  @moduledoc """
  Handles seeding of the database with realistic development data.
  """

  require Ash.Query

  def run do
    IO.puts("🌱 Starting Seeding...")

    # 1. Create Super Admin
    _admin = ensure_admin()

    # 2. Create Tenants
    _tenant = ensure_tenant("Acme Corp", "acme", "acme.localhost")
    _tenant2 = ensure_tenant("Globex Corp", "globex", "globex.localhost")

    IO.puts("✅ Seeding Complete!")
  end

  defp ensure_admin do
    email = "admin@example.com"
    password = "password123"

    case Mcp.Accounts.User.get_by_email(email) do
      {:ok, user} ->
        IO.puts("  - Admin already exists: #{email}")
        user

      {:error, _} ->
        IO.puts("  - Creating Admin: #{email}")
        Mcp.Accounts.User.register!(email, password, password)
    end
  end

  defp ensure_tenant(name, slug, subdomain) do
    case Mcp.Platform.Tenant.by_subdomain(subdomain) do
      {:ok, tenant} ->
        IO.puts("  - Tenant already exists: #{name}")
        tenant

      {:error, _} ->
        IO.puts("  - Creating Tenant: #{name}")
        
        Mcp.Platform.Tenant.create!(%{
          name: name,
          slug: slug,
          subdomain: subdomain,
          plan: :enterprise
        })
    end
  end
end
