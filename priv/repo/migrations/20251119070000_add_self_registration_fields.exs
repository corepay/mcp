defmodule Mcp.Repo.Migrations.AddSelfRegistrationFields do
  use Ecto.Migration

  def change do
    # Create registration_settings table if it doesn't exist
    create table(:registration_settings, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :tenant_id, :uuid, null: false
      add :customer_registration_enabled, :boolean, default: false, null: false
      add :vendor_registration_enabled, :boolean, default: false, null: false
      add :customer_approval_required, :boolean, default: false, null: false
      add :vendor_approval_required, :boolean, default: true, null: false
      add :email_verification_required, :boolean, default: true, null: false
      add :business_verification_required, :boolean, default: false, null: false
      add :phone_verification_required, :boolean, default: false, null: false
      add :auto_approve_customers, :boolean, default: true, null: false
      add :auto_approve_vendors, :boolean, default: false, null: false
      add :registration_rate_limit, :integer, default: 5, null: false
      add :approval_timeout_hours, :integer, default: 72, null: false
      add :email_verification_timeout_hours, :integer, default: 24, null: false
      add :password_min_length, :integer, default: 8, null: false
      add :password_require_uppercase, :boolean, default: true, null: false
      add :password_require_lowercase, :boolean, default: true, null: false
      add :password_require_numbers, :boolean, default: true, null: false
      add :password_require_symbols, :boolean, default: true, null: false
      add :allowed_email_domains, {:array, :string}, default: [], null: false
      add :blocked_email_domains, {:array, :string}, default: [], null: false
      add :allowed_countries, {:array, :string}, default: [], null: false
      add :blocked_countries, {:array, :string}, default: [], null: false
      add :welcome_email_template, :string, default: "welcome_customer", null: false
      add :verification_email_template, :string, default: "email_verification", null: false
      add :approval_email_template, :string, default: "registration_approved", null: false
      add :rejection_email_template, :string, default: "registration_rejected", null: false
      add :custom_welcome_message, :text
      add :terms_of_service_url, :string
      add :privacy_policy_url, :string
      add :gdpr_compliance_enabled, :boolean, default: true, null: false
      add :require_consent_for_marketing, :boolean, default: true, null: false
      add :require_consent_for_analytics, :boolean, default: false, null: false
      add :data_retention_days, :integer, default: 365, null: false
      add :fraud_detection_enabled, :boolean, default: true, null: false
      add :fraud_score_threshold, :integer, default: 50, null: false
      add :max_registrations_per_domain, :integer, default: 10, null: false
      add :require_captcha, :boolean, default: true, null: false
      add :captcha_provider, :string, default: "recaptcha", null: false
      add :notification_webhook_url, :string
      add :webhook_secret, :string
      add :custom_fields, :map, default: %{}, null: false
      add :metadata, :map, default: %{}, null: false

      timestamps()
    end

    # Create unique index for tenant_id
    create unique_index(:registration_settings, [:tenant_id])

    # Create registration_requests table if it doesn't exist
    create table(:registration_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :tenant_id, :uuid, null: false
      add :request_type, :string, null: false
      add :status, :string, default: "draft", null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :email, :citext, null: false
      add :phone, :string
      add :password, :string, null: false
      add :hashed_password, :string
      add :company_name, :string
      add :business_type, :string
      add :tax_id, :string
      add :website, :string
      add :industry, :string
      add :description, :string
      add :address_line_1, :string
      add :address_line_2, :string
      add :city, :string
      add :state_province, :string
      add :postal_code, :string
      add :country, :string
      add :ip_address, :string
      add :user_agent, :string
      add :referral_source, :string
      add :marketing_consent, :boolean, default: false, null: false
      add :analytics_consent, :boolean, default: false, null: false
      add :terms_accepted, :boolean, default: false, null: false
      add :terms_accepted_at, :utc_datetime
      add :privacy_policy_accepted, :boolean, default: false, null: false
      add :privacy_policy_accepted_at, :utc_datetime
      add :email_verification_token, :string
      add :email_verification_sent_at, :utc_datetime
      add :email_verified_at, :utc_datetime
      add :phone_verification_token, :string
      add :phone_verification_sent_at, :utc_datetime
      add :phone_verified_at, :utc_datetime
      add :business_documents, {:array, :map}, default: [], null: false
      add :business_verified_at, :utc_datetime
      add :fraud_score, :integer, default: 0, null: false
      add :fraud_flags, {:array, :string}, default: [], null: false
      add :risk_assessment, :map, default: %{}, null: false
      add :admin_notes, :string
      add :rejection_reason, :string
      add :approved_by_admin_id, :uuid
      add :rejected_by_admin_id, :uuid
      add :processed_at, :utc_datetime
      add :user_id, :uuid
      add :custom_fields, :map, default: %{}, null: false
      add :metadata, :map, default: %{}, null: false

      timestamps()
    end

    # Create indexes for registration_requests
    create index(:registration_requests, [:tenant_id])
    create index(:registration_requests, [:email])
    create index(:registration_requests, [:status])
    create index(:registration_requests, [:request_type])
    create index(:registration_requests, [:inserted_at])
    create unique_index(:registration_requests, [:email_verification_token])
  end
end
