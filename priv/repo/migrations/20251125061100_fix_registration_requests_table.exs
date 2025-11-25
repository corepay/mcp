defmodule Mcp.Repo.Migrations.FixRegistrationRequestsTable do
  use Ecto.Migration

  def up do
    # Drop the partially created table
    drop_if_exists table(:registration_requests)

    # Recreate with correct defaults
    create table(:registration_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :type, :string, null: false, default: "customer"
      add :email, :citext, null: false
      add :first_name, :string
      add :last_name, :string
      add :phone, :string
      add :company_name, :string
      add :registration_data, :jsonb
      add :status, :string, null: false, default: "pending"
      add :submitted_at, :utc_datetime_usec
      add :approved_at, :utc_datetime_usec
      add :rejected_at, :utc_datetime_usec
      add :approved_by_id, :binary_id
      add :rejection_reason, :string
      add :context, :jsonb

      timestamps()
    end

    # Create indexes for efficient querying
    create index(:registration_requests, [:tenant_id, :status])
    create index(:registration_requests, [:email])
    create index(:registration_requests, [:status, :inserted_at])

    # Add foreign key constraints
    alter table(:registration_requests) do
      modify :tenant_id, references(:tenants, type: :binary_id, column: :id), null: false
    end

    create index(:registration_requests, [:approved_by_id])
  end

  def down do
    drop table(:registration_requests)
  end
end