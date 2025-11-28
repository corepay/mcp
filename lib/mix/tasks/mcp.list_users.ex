defmodule Mix.Tasks.Mcp.ListUsers do
  @moduledoc """
  Lists all seeded users and their credentials.
  """
  use Mix.Task

  alias Mcp.Platform.Tenant
  alias Mcp.Platform.TenantUserManager

  @shortdoc "Lists seeded users and credentials"

  def run(_args) do
    # Ensure the application is fully started
    {:ok, _} = Application.ensure_all_started(:telemetry)
    {:ok, _} = Application.ensure_all_started(:mcp)

    IO.puts("\n🔐 MCP Platform Credentials")
    IO.puts("==========================\n")

    IO.puts("👑 Platform Admin")
    IO.puts("  Email:    admin@platform.local")
    IO.puts("  Password: Password123!")
    IO.puts("")

    IO.puts("🏢 Tenants")

    # List all tenants
    require Ash.Query

    tenants = Tenant.read!()

    Enum.each(tenants, fn tenant ->
      IO.puts("  #{tenant.name} (#{tenant.slug})")
      IO.puts("  URL: http://#{tenant.subdomain}")

      # Get tenant users
      {:ok, users} = TenantUserManager.get_tenant_users(tenant.id)

      if Enum.empty?(users) do
        IO.puts("    (No users)")
      else
        Enum.each(users, fn u ->
          IO.puts("    - #{u["email"]} (#{u["role"]})")
          IO.puts("      Password: Password123!")
        end)
      end

      IO.puts("")
    end)

    IO.puts("==========================\n")
  end
end
