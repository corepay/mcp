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