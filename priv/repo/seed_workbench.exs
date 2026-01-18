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

# 2. Sample Applications with Forensic/KYB Data
apps_data = [
  %{
    "business_name" => "STITCHED CLOTHING CO.",
    "business_info" => %{
      "website_url" => "https://stitched.shop",
      "registration_number" => "BC1234567",
      "tax_id" => "88-2910293",
      "incorporation_date" => "2018-05-12",
      "type" => "Corporation"
    },
    "business_type" => "RETAIL",
    "annual_volume" => "$1.2M",
    "avg_ticket" => "$85",
    "high_ticket" => "$450",
    "contact_name" => "Sarah Weaver",
    "contact_title" => "CEO",
    "contact_email" => "sarah@stitched.shop",
    "contact_phone" => "+1 212-555-0198",
    "business_address" => "123 Fashion Ave, New York, NY 10001",
    "bank_name" => "JP Morgan Chase",
    "bank_account_last_4" => "4421",
    "kyb_status" => "Verified",
    "kyc_status" => "Passed"
  },
  %{
    "business_name" => "TECHNOVA SOLUTIONS",
    "business_info" => %{
      "website_url" => "https://technova.io",
      "registration_number" => "DE-992831",
      "tax_id" => "92-1102931",
      "incorporation_date" => "2022-11-20",
      "type" => "LLC"
    },
    "business_type" => "SAAS",
    "annual_volume" => "$5.8M",
    "avg_ticket" => "$450",
    "high_ticket" => "$2,500",
    "contact_name" => "Mark Dongle",
    "contact_title" => "Founder",
    "contact_email" => "mark@technova.io",
    "contact_phone" => "+1 415-555-0442",
    "business_address" => "442 Silicon Valley Blvd, San Jose, CA 95110",
    "bank_name" => "Silicon Valley Bank",
    "bank_account_last_4" => "2291",
    "kyb_status" => "Caution",
    "kyc_status" => "Passed"
  },
  %{
    "business_name" => "RUSTY ANCHOR PUB",
    "business_info" => %{
      "website_url" => "https://rustyanchor.pub",
      "registration_number" => "MA-88271",
      "tax_id" => "10-2293812",
      "incorporation_date" => "1994-03-01",
      "type" => "Partnership"
    },
    "business_type" => "HOSPITALITY",
    "annual_volume" => "$450K",
    "avg_ticket" => "$22",
    "high_ticket" => "$150",
    "contact_name" => "James Hook",
    "contact_title" => "Proprietor",
    "contact_email" => "captain@rustyanchor.pub",
    "contact_phone" => "+1 617-555-0812",
    "business_address" => "812 Seaport Blvd, Boston, MA 02210",
    "bank_name" => "Bank of America",
    "bank_account_last_4" => "0012",
    "kyb_status" => "Verified",
    "kyc_status" => "Passed"
  },
  %{
    "business_name" => "CRYPTOKINGZ LTD",
    "business_info" => %{
      "website_url" => "https://cryptokingz.fake",
      "registration_number" => "KY-77281",
      "tax_id" => "00-0000000",
      "incorporation_date" => "2024-01-01",
      "type" => "Limited"
    },
    "business_type" => "CRYPTO",
    "annual_volume" => "$12M",
    "avg_ticket" => "$1,200",
    "high_ticket" => "$50,000",
    "contact_name" => "Anon King",
    "contact_title" => "Admin",
    "contact_email" => "admin@cryptokingz.fake",
    "contact_phone" => "+1 000-000-0000",
    "business_address" => "1240 Market Street, San Francisco, CA 94102",
    "bank_name" => "Offshore Bank",
    "bank_account_last_4" => "9999",
    "kyb_status" => "Failed",
    "kyc_status" => "Manual Review"
  }
]

for data <- apps_data do
  # Check if application exists
  exists =
    UWApplication
    |> Ash.read!(tenant: schema)
    |> Enum.find(fn app -> app.application_data["business_name"] == data["business_name"] end)

  if is_nil(exists) do
    IO.puts "  + Creating application for #{data["business_name"]}..."
    app = Ash.create!(UWApplication, %{
      status: :submitted,
      application_data: data,
      subject_id: Ecto.UUID.generate(),
      subject_type: :merchant,
      healed_data: %{
        "business_name" => data["business_name"],
        "verification_status" => data["kyb_status"],
        "signals" => ["initial_payload_captured"]
      }
    }, tenant: schema)

    # Attach a mock document
    Ash.create!(Document, %{
      application_id: app.id,
      file_name: "Corporate_Articles.pdf",
      file_path: "uploads/docs/corp_articles.pdf",
      mime_type: "application/pdf",
      document_type: :incorporation,
      status: :pending
    }, tenant: schema)
  else
    IO.puts "  . Application for #{data["business_name"]} already exists."
  end
end

IO.puts "✅ Workbench Forensic Seeding Complete!"
