# priv/repo/seed_workbench.exs

# Ensure mcp is started
Application.ensure_all_started(:mcp)

alias Mcp.Platform.Tenant
alias Mcp.Underwriting.Application, as: UWApplication
alias Mcp.Underwriting.Document
require Ash.Query

# 1. Target Tenant
tenant_slug = "acme"
tenant = Tenant.by_slug!(tenant_slug)
schema = tenant.company_schema

IO.puts "🌱 Seeding Forensic Workbench for #{tenant.name} (#{schema})..."

# Ensure migrations are up to date for this tenant
IO.puts "  - Ensuring tenant migrations are UP for #{schema}..."
Ecto.Migrator.run(Mcp.Repo, "priv/repo/tenant_migrations", :up,
  all: true,
  prefix: schema
)

# 2. Run Comprehensive Demo Seeder
Mcp.Underwriting.DemoSeeder.run(tenant_slug)

IO.puts "✅ Workbench Forensic Seeding Complete!"
