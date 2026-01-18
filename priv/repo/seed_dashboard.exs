# priv/repo/seed_dashboard.exs

Application.ensure_all_started(:mcp)

alias Mcp.Platform.{Tenant, Merchant, Reseller}
alias Mcp.Underwriting.{Application, Activity}

tenant_slug = "acme"
tenant = Tenant.by_slug!(tenant_slug)
schema = tenant.company_schema

IO.puts "🌱 Seeding Executive Insight Plane for #{tenant.name} (#{schema})..."

# Ensure we have at least one application
apps = Application.read!(tenant: schema)
app = if Enum.empty?(apps) do
  IO.puts "  + Creating pivot application..."
  Ash.create!(Application, %{
    status: :submitted,
    application_data: %{"business_name" => "PIVOT CORP"},
    subject_id: Ecto.UUID.generate(),
    subject_type: :merchant
  }, tenant: schema)
else
  List.first(apps)
end

# 1. Activities (Signals)
IO.puts "  - Seeding activity signals..."
activities = [
  %{type: :risk_assessment, metadata: %{"score" => 12}},
  %{type: :kyc_success, metadata: %{}},
  %{type: :alert, metadata: %{"severity" => "high"}},
  %{type: :status_change, metadata: %{"from" => "submitted", "to" => "in_review"}},
  %{type: :comment, metadata: %{"note" => "Merchant has strong financial backing"}}
]

for act <- activities do
  Ash.create!(Activity, %{
    type: act.type,
    metadata: act.metadata,
    application_id: app.id
  }, tenant: schema)
end

# 2. Resellers (Global Resource - No Tenant Context)
IO.puts "  - Seeding resellers (Global)..."
resellers = [
  %{company_name: "Atlas Capital Partners", slug: "atlas", contact_name: "John Atlas", contact_email: "john@atlas.com"},
  %{company_name: "Velocity Acquisition Grp", slug: "velocity", contact_name: "Jane Speed", contact_email: "jane@velocity.com"}
]

for r <- resellers do
  exists = Reseller.read!() |> Enum.find(& &1.slug == r.slug)
  if is_nil(exists) do
    Ash.create!(Reseller, Map.put(r, :subdomain, r.slug))
  end
end

# 3. Merchants
IO.puts "  - Seeding merchant portfolio..."
current_merchants = Merchant.read!(tenant: schema)
if length(current_merchants) < 5 do
  merchants = [
    %{business_name: "Global Trade Inc", slug: "global-trade", subdomain: "global", city: "New York", state: "NY", plan: :enterprise, status: :active, risk_level: :low},
    %{business_name: "Nexus Electronics", slug: "nexus-elec", subdomain: "nexus", city: "Austin", state: "TX", plan: :professional, status: :active, risk_level: :medium},
    %{business_name: "Prime Logistics", slug: "prime-log", subdomain: "prime", city: "Chicago", state: "IL", plan: :starter, status: :pending_verification, risk_level: :low}
  ]
  for m <- merchants do
     Ash.create!(Merchant, m, tenant: schema)
  end
end

IO.puts "✅ Dashboard Seeding Complete!"
