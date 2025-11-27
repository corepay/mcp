defmodule Mcp.Repo.TenantMigrations.CreateTenantUserTables do
  @moduledoc """
  Migration to create tenant user management tables.

  Creates tables for tenant users, invitations, and role permissions
  to support multi-tenant user management with role-based access control.
  """

  use Ecto.Migration

  def up do
    # Create tenant_users table
    create table(:tenant_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :first_name, :string, null: false, size: 100
      add :last_name, :string, null: false, size: 100
      add :role, :string, null: false, default: "viewer"
      add :status, :string, null: false, default: "pending"
      add :invitation_token, :binary_id
      add :invitation_sent_at, :utc_datetime_usec
      add :invitation_accepted_at, :utc_datetime_usec
      add :invitation_expires_at, :utc_datetime_usec
      add :last_sign_in_at, :utc_datetime_usec
      add :last_sign_in_ip, :string
      add :sign_in_count, :integer, null: false, default: 0
      add :permissions, {:array, :string}, default: []
      add :settings, :jsonb, default: "{}"
      add :is_tenant_owner, :boolean, null: false, default: false
      add :password_change_required, :boolean, null: false, default: false
      add :phone_number, :string
      add :department, :string, size: 100
      add :job_title, :string, size: 150
      add :notes, :string, size: 1000

      timestamps()
    end

    # Create unique index for email within tenant
    create unique_index(:tenant_users, [:email])

    # Create indexes for performance
    create index(:tenant_users, [:role])
    create index(:tenant_users, [:status])
    create index(:tenant_users, [:invitation_token])
    create index(:tenant_users, [:is_tenant_owner])
    create index(:tenant_users, [:inserted_at])
    create index(:tenant_users, [:last_sign_in_at])

    # Create composite indexes for common queries
    create index(:tenant_users, [:status, :role])
    create index(:tenant_users, [:status, :invitation_expires_at])

    # Create tenant_invitations table
    create table(:tenant_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_user_id, references(:tenant_users, type: :binary_id, on_delete: :delete_all), null: false
      add :email, :citext, null: false
      add :invitation_token, :binary_id, null: false
      add :status, :string, null: false, default: "pending"
      add :sent_at, :utc_datetime_usec
      add :delivered_at, :utc_datetime_usec
      add :accepted_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      add :revoked_by_id, :binary_id
      add :invitation_message, :string, size: 2000
      add :invited_by_id, :binary_id, null: false
      add :invited_by_name, :string, null: false, size: 255
      add :delivery_attempts, :integer, null: false, default: 0
      add :last_delivery_attempt_at, :utc_datetime_usec
      add :delivery_error, :string, size: 1000
      add :email_service_id, :string, size: 200
      add :acceptance_ip, :string
      add :acceptance_user_agent, :string, size: 500
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    # Create foreign key constraint to tenant_users
    # (Replaced by references in table definition)

    # Create unique index for invitation token
    create unique_index(:tenant_invitations, [:invitation_token])

    # Create unique index for active invitations by email
    create unique_index(:tenant_invitations, [:email],
      where: "status IN ('pending', 'sent', 'delivered')"
    )

    # Create indexes for performance
    create index(:tenant_invitations, [:tenant_user_id])
    # create index(:tenant_invitations, [:email]) # Duplicate of unique index above
    create index(:tenant_invitations, [:status])
    create index(:tenant_invitations, [:invited_by_id])
    create index(:tenant_invitations, [:expires_at])
    create index(:tenant_invitations, [:inserted_at])

    # Create composite indexes for common queries
    create index(:tenant_invitations, [:status, :expires_at])
    create index(:tenant_invitations, [:status, :email])

    # Create role_permissions table
    create table(:role_permissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false
      add :permission, :string, null: false
      add :category, :string, null: false
      add :description, :string, null: false, size: 500
      add :is_granted, :boolean, null: false, default: true
      add :is_required, :boolean, null: false, default: false
      add :level, :integer, null: false
      add :granted_by_id, :binary_id
      add :granted_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
      add :conditions, :jsonb, default: "{}"

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end

    # Create unique index for role-permission combination
    create unique_index(:role_permissions, [:role, :permission])

    # Create indexes for performance
    create index(:role_permissions, [:role])
    create index(:role_permissions, [:permission])
    create index(:role_permissions, [:category])
    create index(:role_permissions, [:is_granted])
    create index(:role_permissions, [:expires_at])
    create index(:role_permissions, [:level])

    # Create composite indexes for common queries
    create index(:role_permissions, [:role, :is_granted])
    create index(:role_permissions, [:category, :is_granted])

    # Create audit extensions for user activity tracking
    # execute """
    #   CREATE OR REPLACE FUNCTION update_tenant_user_modified_column()
    #   RETURNS TRIGGER AS $$
    #   BEGIN
    #     NEW.updated_at = NOW();
    #     RETURN NEW;
    #   END;
    #   $$ language 'plpgsql';
    # """

    # execute """
    #   CREATE TRIGGER tenant_users_updated_at
    #     BEFORE UPDATE ON tenant_users
    #     FOR EACH ROW
    #     EXECUTE FUNCTION update_tenant_user_modified_column();
    # """

    # execute """
    #   CREATE TRIGGER tenant_invitations_updated_at
    #     BEFORE UPDATE ON tenant_invitations
    #     FOR EACH ROW
    #     EXECUTE FUNCTION update_tenant_user_modified_column();
    # """

    # execute """
    #   CREATE TRIGGER role_permissions_updated_at
    #     BEFORE UPDATE ON role_permissions
    #     FOR EACH ROW
    #     EXECUTE FUNCTION update_tenant_user_modified_column();
    # """

    # Create user activity log table
    create table(:user_activity_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_user_id, :binary_id, null: false
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary_id
      add :ip_address, :string
      add :user_agent, :string, size: 500
      add :metadata, :jsonb, default: "{}"
      add :timestamp, :utc_datetime_usec, null: false, default: fragment("NOW()")

      timestamps()
    end

    # Create indexes for user activity logs
    create index(:user_activity_logs, [:tenant_user_id])
    create index(:user_activity_logs, [:action])
    create index(:user_activity_logs, [:resource_type])
    create index(:user_activity_logs, [:timestamp])
    create index(:user_activity_logs, [:resource_type, :resource_id])

    # Insert default role permissions
    execute """
      INSERT INTO role_permissions (id, role, permission, category, description, is_granted, is_required, level) VALUES
      -- Admin permissions
      (gen_random_uuid(), 'admin', 'all', 'special', 'Full administrative access to all system features', true, true, 5),

      -- Customer management
      (gen_random_uuid(), 'admin', 'view_customers', 'customers', 'View customer information and details', true, true, 3),
      (gen_random_uuid(), 'admin', 'create_customers', 'customers', 'Create new customer accounts', true, false, 4),
      (gen_random_uuid(), 'admin', 'update_customers', 'customers', 'Update customer information', true, false, 4),
      (gen_random_uuid(), 'admin', 'delete_customers', 'customers', 'Delete customer accounts', true, false, 5),
      (gen_random_uuid(), 'admin', 'manage_customer_status', 'customers', 'Activate/deactivate customer accounts', true, false, 4),

      -- Billing permissions
      (gen_random_uuid(), 'admin', 'view_billing', 'billing', 'View billing information and reports', true, true, 3),
      (gen_random_uuid(), 'admin', 'manage_invoices', 'billing', 'Create and manage invoices', true, false, 4),
      (gen_random_uuid(), 'admin', 'manage_payments', 'billing', 'Process payments and refunds', true, false, 5),
      (gen_random_uuid(), 'admin', 'tenant_billing', 'special', 'Manage tenant billing and subscriptions', true, false, 5),

      -- User management
      (gen_random_uuid(), 'admin', 'view_users', 'users', 'View user accounts and permissions', true, true, 3),
      (gen_random_uuid(), 'admin', 'create_users', 'users', 'Invite and create new user accounts', true, false, 4),
      (gen_random_uuid(), 'admin', 'update_users', 'users', 'Update user information and roles', true, false, 4),
      (gen_random_uuid(), 'admin', 'delete_users', 'users', 'Delete or deactivate user accounts', true, false, 5),
      (gen_random_uuid(), 'admin', 'manage_user_roles', 'users', 'Assign and manage user roles and permissions', true, false, 5),

      -- System permissions
      (gen_random_uuid(), 'admin', 'view_system_settings', 'system', 'View system configuration and settings', true, true, 4),
      (gen_random_uuid(), 'admin', 'manage_system_settings', 'system', 'Modify system configuration and settings', true, false, 5),

      -- Billing admin permissions
      (gen_random_uuid(), 'billing_admin', 'view_customers', 'customers', 'View customer information for billing purposes', true, true, 3),
      (gen_random_uuid(), 'billing_admin', 'view_customer_details', 'customers', 'View detailed customer information', true, false, 3),
      (gen_random_uuid(), 'billing_admin', 'view_billing', 'billing', 'View billing information and reports', true, true, 3),
      (gen_random_uuid(), 'billing_admin', 'manage_invoices', 'billing', 'Create and manage invoices', true, false, 4),
      (gen_random_uuid(), 'billing_admin', 'manage_payments', 'billing', 'Process payments and refunds', true, false, 4),
      (gen_random_uuid(), 'billing_admin', 'view_payment_history', 'billing', 'View payment history and transactions', true, false, 3),
      (gen_random_uuid(), 'billing_admin', 'manage_billing_settings', 'billing', 'Configure billing system settings', true, false, 4),
      (gen_random_uuid(), 'billing_admin', 'export_billing_data', 'billing', 'Export billing data and reports', true, false, 3),

      -- Support admin permissions
      (gen_random_uuid(), 'support_admin', 'view_customers', 'customers', 'View customer information for support purposes', true, true, 3),
      (gen_random_uuid(), 'support_admin', 'view_customer_details', 'customers', 'View detailed customer information', true, false, 3),
      (gen_random_uuid(), 'support_admin', 'view_support_tickets', 'support', 'View support tickets and requests', true, true, 3),
      (gen_random_uuid(), 'support_admin', 'create_support_tickets', 'support', 'Create support tickets on behalf of customers', true, false, 3),
      (gen_random_uuid(), 'support_admin', 'update_support_tickets', 'support', 'Update and manage support tickets', true, false, 4),
      (gen_random_uuid(), 'support_admin', 'close_tickets', 'support', 'Close resolved support tickets', true, false, 3),
      (gen_random_uuid(), 'support_admin', 'assign_tickets', 'support', 'Assign tickets to support agents', true, false, 4),
      (gen_random_uuid(), 'support_admin', 'view_support_reports', 'support', 'View support analytics and reports', true, false, 3),

      -- Operator permissions
      (gen_random_uuid(), 'operator', 'view_customers', 'customers', 'View customer information', true, true, 3),
      (gen_random_uuid(), 'operator', 'view_customer_details', 'customers', 'View detailed customer information', true, false, 3),
      (gen_random_uuid(), 'operator', 'view_services', 'services', 'View service information and status', true, true, 3),
      (gen_random_uuid(), 'operator', 'activate_services', 'services', 'Activate customer services', true, false, 4),
      (gen_random_uuid(), 'operator', 'deactivate_services', 'services', 'Deactivate customer services', true, false, 4),
      (gen_random_uuid(), 'operator', 'view_service_usage', 'services', 'View service usage statistics', true, false, 3),
      (gen_random_uuid(), 'operator', 'view_billing', 'billing', 'View basic billing information', true, false, 2),
      (gen_random_uuid(), 'operator', 'view_support_tickets', 'support', 'View support tickets', true, false, 3),
      (gen_random_uuid(), 'operator', 'create_support_tickets', 'support', 'Create support tickets', true, false, 3),
      (gen_random_uuid(), 'operator', 'update_support_tickets', 'support', 'Update support tickets', true, false, 3),

      -- Viewer permissions
      (gen_random_uuid(), 'viewer', 'view_customers', 'customers', 'View customer information', true, true, 1),
      (gen_random_uuid(), 'viewer', 'view_customer_details', 'customers', 'View detailed customer information', true, false, 2),
      (gen_random_uuid(), 'viewer', 'view_services', 'services', 'View service information', true, false, 1),
      (gen_random_uuid(), 'viewer', 'view_service_usage', 'services', 'View service usage statistics', true, false, 1),
      (gen_random_uuid(), 'viewer', 'view_billing', 'billing', 'View billing information', true, false, 1),
      (gen_random_uuid(), 'viewer', 'view_support_tickets', 'support', 'View support tickets', true, false, 1),
      (gen_random_uuid(), 'viewer', 'view_reports', 'reports', 'View reports and analytics', true, false, 1)
      ON CONFLICT (role, permission) DO NOTHING;
    """
  end

  def down do
    # Drop triggers
    execute "DROP TRIGGER IF EXISTS role_permissions_updated_at ON role_permissions;"
    execute "DROP TRIGGER IF EXISTS tenant_invitations_updated_at ON tenant_invitations;"
    execute "DROP TRIGGER IF EXISTS tenant_users_updated_at ON tenant_users;"

    # Drop function
    execute "DROP FUNCTION IF EXISTS update_tenant_user_modified_column();"

    # Drop tables
    drop table(:user_activity_logs)
    drop table(:role_permissions)
    drop table(:tenant_invitations)
    drop table(:tenant_users)
  end
end