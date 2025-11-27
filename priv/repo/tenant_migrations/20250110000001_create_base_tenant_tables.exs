defmodule Mcp.Repo.TenantMigrations.CreateBaseTenantTables do
  use Ecto.Migration

  def up do
    create table(:merchants, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :slug, :text, null: false
      add :business_name, :text
      add :subdomain, :text
      add :status, :text
      add :plan, :text
      add :settings, :map, default: %{}
      add :branding, :map, default: %{}
      add :risk_profile, :map, default: %{}
      add :verification_status, :text
      add :operating_hours, :map, default: %{}
      add :country, :text
      add :kyc_documents, :map, default: %{}
      add :risk_level, :text
      add :kyc_status, :text
      add :default_currency, :text
      add :processing_limits, :map, default: %{}
      add :max_stores, :integer
      add :timezone, :text
      
      # Additional columns inferred from logs/errors
      add :tax_id_type, :text
      add :support_email, :text
      add :risk_score, :float
      add :kyc_verified_at, :utc_datetime
      add :phone, :text
      add :max_products, :integer
      add :state, :text
      add :website_url, :text
      add :custom_domain, :text
      add :address_line2, :text
      add :description, :text
      add :postal_code, :text
      add :dba_name, :text
      add :max_monthly_volume, :decimal
      add :city, :text
      add :ein, :text
      add :business_type, :text
      add :mcc, :text
      add :reseller_id, :uuid
      add :address_line1, :text

      timestamps()
    end

    create unique_index(:merchants, [:slug])

    create table(:stores, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text
      add :slug, :text
      add :merchant_id, references(:merchants, type: :uuid, on_delete: :delete_all)
      add :status, :text
      add :routing_type, :text
      add :subdomain, :text
      add :custom_domain, :text
      add :settings, :map, default: %{}
      add :branding, :map, default: %{}
      add :fallback_mid_ids, {:array, :uuid}
      add :geo_location, :map
      add :tax_nexus, {:array, :text}
      add :store_type, :text
      add :store_manager_name, :text
      add :store_phone, :text
      add :store_email, :text
      add :primary_mid_id, :uuid
      
      timestamps()
    end

    create unique_index(:stores, [:slug])

    create table(:resellers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :slug, :text, null: false
      add :company_name, :text, null: false
      add :subdomain, :text, null: false
      add :custom_domain, :text
      add :contact_name, :text, null: false
      add :contact_email, :text, null: false
      add :contact_phone, :text
      add :commission_rate, :decimal, default: 0.00
      add :revenue_share_model, :map, default: %{}
      add :banking_info, :map, default: %{}
      add :tax_id, :text
      add :contract_start_date, :date
      add :contract_end_date, :date
      add :support_tier, :text, default: "standard"
      add :branding, :map, default: %{}
      add :settings, :map, default: %{}
      add :max_merchants, :integer, default: 50
      add :status, :text, default: "active"
      
      add :user_id, :uuid
      add :developer_id, :uuid

      timestamps()
    end

    create unique_index(:resellers, [:slug])

    create table(:developers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :company_name, :text, null: false
      add :contact_name, :text, null: false
      add :contact_email, :text, null: false
      add :contact_phone, :text
      add :technical_contact_email, :text
      add :admin_contact_email, :text
      add :support_phone, :text
      add :webhook_url, :text
      add :webhook_secret, :text
      add :webhook_events, {:array, :text}, default: []
      add :webhook_signing_secret, :text
      add :app_type, :text, default: "public"
      add :revenue_share_percentage, :decimal, default: 0.00
      add :payout_settings, :map, default: %{}
      add :api_quota_daily, :integer, default: 1000
      add :api_quota_monthly, :integer, default: 10000
      add :status, :text, default: "active"
      
      add :user_id, :uuid

      timestamps()
    end

    create table(:mids, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :mid_number, :text, null: false
      add :gateway_id, :uuid, null: false
      add :gateway_credentials, :map, null: false
      add :routing_rules, :map, default: %{}
      add :status, :text, default: "active"
      add :is_primary, :boolean, default: false
      add :processor_name, :text
      add :acquirer_name, :text
      add :batch_time, :time
      add :supported_card_brands, {:array, :text}
      add :currencies, {:array, :text}
      add :fraud_settings, :map, default: %{}
      add :daily_limit, :decimal
      add :monthly_limit, :decimal
      add :total_volume, :decimal, default: 0
      add :total_transactions, :integer, default: 0
      
      add :merchant_id, references(:merchants, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    create table(:customers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :text, null: false
      add :first_name, :text
      add :last_name, :text
      add :phone, :text
      add :shipping_address, :map
      add :billing_address, :map
      add :saved_payment_methods, {:array, :map}, default: []
      add :total_orders, :integer, default: 0
      add :total_spent, :decimal, default: 0
      add :status, :text, default: "active"
      add :marketing_preferences, :map, default: %{}
      add :loyalty_tier, :text
      add :loyalty_points, :integer, default: 0
      add :tags, {:array, :text}
      add :last_active_at, :utc_datetime
      add :source, :text
      add :gdpr_consent, :boolean, default: false
      add :gdpr_consent_at, :utc_datetime
      
      add :merchant_id, references(:merchants, type: :uuid, on_delete: :delete_all), primary_key: true
      add :user_id, :uuid

      timestamps()
    end
  end

  def down do
    drop table(:stores)
    drop table(:merchants)
  end
end
