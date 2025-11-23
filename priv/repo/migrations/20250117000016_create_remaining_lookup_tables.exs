defmodule Mcp.Repo.Migrations.CreateRemainingLookupTables do
  use Ecto.Migration

  def up do
    # Create lookup tables only if they don't already exist
    # This handles the case where platform schema was created outside of migrations

    # Address Types - create only if not exists
    create_if_not_exists table(:address_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :description, :text
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
            INSERT INTO platform.address_types (value, label, description, sort_order)
            SELECT 'home', 'Home Address', 'Personal home address', 1
            WHERE NOT EXISTS (SELECT 1 FROM platform.address_types WHERE value = 'home')
            """,
            nil

    execute """
            INSERT INTO platform.address_types (value, label, description, sort_order)
            SELECT 'business', 'Business Address', 'Business/office address', 2
            WHERE NOT EXISTS (SELECT 1 FROM platform.address_types WHERE value = 'business')
            """,
            nil

    execute """
            INSERT INTO platform.address_types (value, label, description, sort_order)
            SELECT 'shipping', 'Shipping Address', 'Shipping/delivery address', 3
            WHERE NOT EXISTS (SELECT 1 FROM platform.address_types WHERE value = 'shipping')
            """,
            nil

    execute """
            INSERT INTO platform.address_types (value, label, description, sort_order)
            SELECT 'billing', 'Billing Address', 'Billing address for invoices', 4
            WHERE NOT EXISTS (SELECT 1 FROM platform.address_types WHERE value = 'billing')
            """,
            nil

    execute """
            INSERT INTO platform.address_types (value, label, description, sort_order)
            SELECT 'legal', 'Legal Address', 'Legal/registered address', 5
            WHERE NOT EXISTS (SELECT 1 FROM platform.address_types WHERE value = 'legal')
            """,
            nil

    # Email Types
    create_if_not_exists table(:email_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
            INSERT INTO platform.email_types (value, label, sort_order)
            SELECT 'personal', 'Personal', 1
            WHERE NOT EXISTS (SELECT 1 FROM platform.email_types WHERE value = 'personal')
            """,
            nil

    execute """
            INSERT INTO platform.email_types (value, label, sort_order)
            SELECT 'work', 'Work', 2
            WHERE NOT EXISTS (SELECT 1 FROM platform.email_types WHERE value = 'work')
            """,
            nil

    execute """
            INSERT INTO platform.email_types (value, label, sort_order)
            SELECT 'support', 'Support', 3
            WHERE NOT EXISTS (SELECT 1 FROM platform.email_types WHERE value = 'support')
            """,
            nil

    execute """
            INSERT INTO platform.email_types (value, label, sort_order)
            SELECT 'billing', 'Billing', 4
            WHERE NOT EXISTS (SELECT 1 FROM platform.email_types WHERE value = 'billing')
            """,
            nil

    # Phone Types
    create_if_not_exists table(:phone_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :is_active, :boolean, default: true
      add :supports_sms, :boolean, default: false
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
            INSERT INTO platform.phone_types (value, label, supports_sms, sort_order)
            SELECT 'mobile', 'Mobile', true, 1
            WHERE NOT EXISTS (SELECT 1 FROM platform.phone_types WHERE value = 'mobile')
            """,
            nil

    execute """
            INSERT INTO platform.phone_types (value, label, supports_sms, sort_order)
            SELECT 'work', 'Work', false, 3
            WHERE NOT EXISTS (SELECT 1 FROM platform.phone_types WHERE value = 'work')
            """,
            nil
  end

  def down do
    drop table(:phone_types, prefix: "platform")
    drop table(:email_types, prefix: "platform")
    drop table(:address_types, prefix: "platform")
  end
end
