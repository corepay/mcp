defmodule Mcp.Repo.TenantMigrations.UnderwritingRemediationV1 do
  @moduledoc """
  Cleanly creates underwriting tables in tenant schemas.
  """
  use Ecto.Migration

  def up do
    # Drop existing to ensure fresh state for remediation
    execute "DROP TABLE IF EXISTS #{prefix()}.underwriting_vendor_settings CASCADE"
    execute "DROP TABLE IF EXISTS #{prefix()}.document_analyses CASCADE"
    execute "DROP TABLE IF EXISTS #{prefix()}.agent_blueprints CASCADE"
    execute "DROP TABLE IF EXISTS #{prefix()}.instruction_sets CASCADE"

    # 1. Vendor Settings
    create table(:underwriting_vendor_settings, primary_key: false, prefix: prefix()) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :preferred_vendor, :text, null: false, default: "comply_cube"
      add :circuit_breaker_enabled, :boolean, null: false, default: true
      add :webhook_token, :text, null: false, default: fragment("gen_random_uuid()")
      add :auto_approve_threshold, :bigint, null: false, default: 90
      add :auto_reject_threshold, :bigint, null: false, default: 50
      add :sla_hours, :bigint, null: false, default: 4
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
    end

    # 2. Documents cleanup
    # (Assuming underwriting_documents exists since it passed before)

    # 3. Document Analysis
    create table(:document_analyses, primary_key: false, prefix: prefix()) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :status, :text, null: false, default: "pending"
      add :markdown_content, :text
      add :structured_data, :map
      add :provider, :text, null: false
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :merchant_id, references(:merchants, column: :id, type: :uuid, prefix: prefix()), null: false
    end

    # 4. Agentic Resources
    create table(:agent_blueprints, primary_key: false, prefix: prefix()) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :description, :text
      add :base_prompt, :text, null: false
      add :tools, {:array, :text}, default: []
      add :routing_config, :map
      add :knowledge_base_ids, {:array, :uuid}, default: []
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:instruction_sets, primary_key: false, prefix: prefix()) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :instructions, :text, null: false
      add :hash, :text
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')")
      add :blueprint_id, references(:agent_blueprints, column: :id, type: :uuid, prefix: prefix())
    end
  end

  def down do
    drop table(:instruction_sets, prefix: prefix())
    drop table(:agent_blueprints, prefix: prefix())
    drop table(:document_analyses, prefix: prefix())
    drop table(:underwriting_vendor_settings, prefix: prefix())
  end
end
