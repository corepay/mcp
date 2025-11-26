defmodule Mcp.Repo.Migrations.CreateGlobalDeveloperResellerTables do
  use Ecto.Migration

  def change do
    # Developers Table (Global)
    create table(:developers, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all, prefix: "platform")

      add :company_name, :text, null: false
      add :contact_name, :text, null: false
      add :contact_email, :text, null: false
      add :contact_phone, :text

      # Operational Contacts
      add :technical_contact_email, :text
      add :admin_contact_email, :text
      add :support_phone, :text

      # Integration Settings
      add :webhook_url, :text
      add :webhook_secret, :text
      add :webhook_events, {:array, :text}, default: []
      add :webhook_signing_secret, :text # Encrypted
      add :app_type, :text, default: "public" # public, private

      # Business Settings
      add :revenue_share_percentage, :numeric, precision: 5, scale: 2, default: 0.00
      add :payout_settings, :map, default: "{}" # Encrypted

      add :api_quota_daily, :integer, default: 1000
      add :api_quota_monthly, :integer, default: 10000

      add :status, :text, default: "active"

      timestamps()
    end

    create index(:developers, [:status], prefix: "platform")
    create index(:developers, [:contact_email], prefix: "platform")
    create index(:developers, [:user_id], prefix: "platform")

    # Resellers Table (Global)
    create table(:resellers, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all, prefix: "platform")

      add :slug, :text, null: false
      add :company_name, :text, null: false
      add :subdomain, :text, null: false
      add :custom_domain, :text

      add :contact_name, :text, null: false
      add :contact_email, :text, null: false
      add :contact_phone, :text

      add :developer_id, references(:developers, type: :uuid, on_delete: :nilify_all, prefix: "platform")

      # Business & Contract
      add :commission_rate, :numeric, precision: 5, scale: 2, default: 0.00
      add :revenue_share_model, :map, default: "{}"
      add :banking_info, :map, default: "{}" # Encrypted
      add :tax_id, :text
      
      add :contract_start_date, :date
      add :contract_end_date, :date
      add :support_tier, :text, default: "standard" # standard, priority

      # White Label & Branding
      add :branding, :map, default: "{}" # Enhanced: logo_url, colors, favicon, help_center
      add :settings, :map, default: "{}"

      add :max_merchants, :integer, default: 50

      add :status, :text, default: "active"

      timestamps()
    end

    create unique_index(:resellers, [:slug], prefix: "platform")
    create unique_index(:resellers, [:subdomain], prefix: "platform")
    create unique_index(:resellers, [:custom_domain], where: "custom_domain IS NOT NULL", prefix: "platform")
    create index(:resellers, [:status], prefix: "platform")
    create index(:resellers, [:developer_id], prefix: "platform")
    create index(:resellers, [:user_id], prefix: "platform")

    # Developer <-> Tenant Association (Many-to-Many)
    create table(:developer_tenants, primary_key: false, prefix: "platform") do
      add :developer_id, references(:developers, type: :uuid, on_delete: :delete_all, prefix: "platform"), primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all, prefix: "platform"), primary_key: true
      
      add :status, :text, default: "active"
      add :permissions, :map, default: "{}"
      
      timestamps()
    end

    create index(:developer_tenants, [:developer_id], prefix: "platform")
    create index(:developer_tenants, [:tenant_id], prefix: "platform")

    # Reseller <-> Tenant Association (Many-to-Many)
    create table(:reseller_tenants, primary_key: false, prefix: "platform") do
      add :reseller_id, references(:resellers, type: :uuid, on_delete: :delete_all, prefix: "platform"), primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all, prefix: "platform"), primary_key: true
      
      add :status, :text, default: "active"
      add :contract_details, :map, default: "{}"
      
      timestamps()
    end

    create index(:reseller_tenants, [:reseller_id], prefix: "platform")
    create index(:reseller_tenants, [:tenant_id], prefix: "platform")
  end
end
