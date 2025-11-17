defmodule Mcp.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def up do
    create table(:tenants, primary_key: false, prefix: "platform") do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Identity
      add :slug, :text, null: false
      add :company_name, :text, null: false
      add :company_schema, :text, null: false

      # Subdomain
      add :subdomain, :text, null: false
      add :custom_domain, :text

      # Subscription & Billing
      add :plan, :text, null: false, default: "starter"
      add :status, :text, null: false, default: "active"
      add :trial_ends_at, :utc_datetime
      add :subscription_id, :text

      # Configuration
      add :settings, :jsonb, default: "{}"
      add :branding, :jsonb, default: "{}"

      # Payment Gateways
      add :assigned_gateway_ids, {:array, :uuid}, default: []

      # Limits
      add :max_developers, :integer, default: 5
      add :max_resellers, :integer, default: 10
      add :max_merchants, :integer, default: 100

      # Onboarding
      add :onboarding_completed_at, :utc_datetime
      add :onboarding_step, :text

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:tenants, [:slug], prefix: "platform")
    create unique_index(:tenants, [:subdomain], prefix: "platform")
    create unique_index(:tenants, [:custom_domain], where: "custom_domain IS NOT NULL", prefix: "platform")
    create unique_index(:tenants, [:company_schema], prefix: "platform")
    create index(:tenants, [:status], prefix: "platform")
    create index(:tenants, [:plan], prefix: "platform")

    # Add constraints
    execute """
    ALTER TABLE platform.tenants
    ADD CONSTRAINT tenants_slug_check
    CHECK (slug ~ '^[a-z0-9-]+$')
    """

    execute """
    ALTER TABLE platform.tenants
    ADD CONSTRAINT tenants_subdomain_check
    CHECK (subdomain ~ '^[a-z0-9-]+$')
    """

    execute """
    ALTER TABLE platform.tenants
    ADD CONSTRAINT tenants_plan_check
    CHECK (plan IN ('starter', 'professional', 'enterprise'))
    """

    execute """
    ALTER TABLE platform.tenants
    ADD CONSTRAINT tenants_status_check
    CHECK (status IN ('active', 'trial', 'suspended', 'canceled'))
    """
  end

  def down do
    drop table(:tenants, prefix: "platform")
  end
end
