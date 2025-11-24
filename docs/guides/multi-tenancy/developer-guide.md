# Multi-Tenancy Framework - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP multi-tenancy system. Includes tenant management, schema isolation, context switching, and multi-tenant application development patterns.

## Architecture Overview

The multi-tenancy framework follows a schema-based isolation approach:

- **Tenant Management Layer**: Tenant provisioning, configuration, and lifecycle management
- **Schema Isolation Layer**: PostgreSQL schema-based data separation and security
- **Context Routing Layer**: Automatic tenant context detection and switching
- **Resource Allocation Layer**: Dynamic resource management per tenant
- **Security Boundary Layer**: Tenant isolation enforcement and access controls
- **Migration Management Layer**: Schema migrations and tenant-specific updates

## Database Schema Design

```elixir
defmodule Mcp.MultiTenancy.Migrations.CreateTenancyTables do
  use Ecto.Migration

  def change do
    # Tenants table - master tenant records
    create table(:tenants) do
      add :name, :string, null: false
      add :slug, :string, null: false, unique: true
      add :domain, :string, unique: true
      add :schema_name, :string, null: false, unique: true
      add :status, :string, default: "pending"  # pending, active, suspended, archived
      add :plan, :string, default: "basic"  # basic, professional, enterprise
      add :settings, :map, default: %{}
      add :limits, :map, default: %{
        users: 100,
        storage_gb: 10,
        api_calls_per_month: 10000
      }
      add :usage, :map, default: %{
        users: 0,
        storage_gb: 0,
        api_calls_per_month: 0
      }
      add :billing_customer_id, :string
      add :subscription_id, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:tenants, [:slug])
    create unique_index(:tenants, [:schema_name])
    create index(:tenants, [:status])

    # Tenant domains for multi-domain support
    create table(:tenant_domains) do
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :domain, :string, null: false, unique: true
      add :primary, :boolean, default: false
      add :verified_at, :utc_datetime
      add :ssl_enabled, :boolean, default: false
      add :custom_ssl_certificate, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:tenant_domains, [:domain])
    create index(:tenant_domains, [:tenant_id, :primary])

    # Tenant users and roles
    create table(:tenant_users) do
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, default: "member"  # owner, admin, member, viewer
      add :status, :string, default: "active"  # active, inactive, suspended
      add :permissions, :map, default: %{}
      add :invited_by, references(:users, type: :binary_id)
      add :invited_at, :utc_datetime
      add :accepted_at, :utc_datetime
      add :last_active_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:tenant_users, [:tenant_id, :user_id])
    create index(:tenant_users, [:user_id, :status])

    # Tenant settings and configuration
    create table(:tenant_settings) do
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :category, :string, null: false  # general, security, billing, notifications
      add :key, :string, null: false
      add :value, :text
      add :type, :string, default: "string"  # string, integer, boolean, json
      add :encrypted, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:tenant_settings, [:tenant_id, :category, :key])

    # Tenant usage tracking
    create table(:tenant_usage_logs) do
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :metric, :string, null: false  # api_calls, storage, users, bandwidth
      add :value, :integer, null: false
      add :period, :string, null: false  # hourly, daily, monthly
      add :timestamp, :utc_datetime, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:tenant_usage_logs, [:tenant_id, :metric, :period, :timestamp])
  end
end
```

## Tenant Management System

```elixir
defmodule Mcp.MultiTenancy.TenantManager do
  @moduledoc """
  Manages tenant lifecycle operations including creation, configuration, and deletion
  """

  alias Mcp.MultiTenancy.{Tenant, TenantDomain, SchemaManager}
  alias Mcp.Core.Repo

  def create_tenant(tenant_params) do
    Multi.new()
    |> Multi.insert(:tenant, Tenant.changeset(%Tenant{}, tenant_params))
    |> Multi.run(:create_schema, fn %{tenant: tenant} ->
      SchemaManager.create_tenant_schema(tenant.schema_name)
    end)
    |> Multi.run(:run_migrations, fn %{tenant: tenant} ->
      SchemaManager.run_tenant_migrations(tenant.schema_name)
    end)
    |> Multi.run(:setup_default_settings, fn %{tenant: tenant} ->
      setup_tenant_settings(tenant)
    end)
    |> Multi.run(:create_default_domain, fn %{tenant: tenant} ->
      create_default_domain(tenant)
    end)
    |> Repo.transaction()
  end

  def update_tenant(tenant, updates) do
    Multi.new()
    |> Multi.update(:tenant, Tenant.changeset(tenant, updates))
    |> Multi.run(:handle_schema_rename, fn %{tenant: updated_tenant} ->
      if updated_tenant.schema_name != tenant.schema_name do
        SchemaManager.rename_schema(tenant.schema_name, updated_tenant.schema_name)
      else
        {:ok, :no_rename_needed}
      end
    end)
    |> Repo.transaction()
  end

  def archive_tenant(tenant) do
    Multi.new()
    |> Multi.update(:tenant, Tenant.changeset(tenant, %{status: "archived"}))
    |> Multi.run(:backup_schema, fn %{tenant: tenant} ->
      SchemaManager.backup_schema(tenant.schema_name)
    end)
    |> Multi.run(:archive_schema, fn %{tenant: tenant} ->
      SchemaManager.archive_schema(tenant.schema_name)
    end)
    |> Repo.transaction()
  end

  def delete_tenant(tenant) do
    Multi.new()
    |> Multi.delete(:tenant, tenant)
    |> Multi.run(:drop_schema, fn _changes ->
      SchemaManager.drop_schema(tenant.schema_name)
    end)
    |> Repo.transaction()
  end

  def get_tenant_by_domain(domain) do
    query = from t in Tenant,
      join: td in TenantDomain,
      on: td.tenant_id == t.id,
      where: td.domain == ^domain,
      where: t.status == "active",
      limit: 1

    Repo.one(query)
  end

  def get_tenant_by_slug(slug) do
    query = from t in Tenant,
      where: t.slug == ^slug,
      where: t.status == "active"

    Repo.one(query)
  end

  defp setup_tenant_settings(tenant) do
    default_settings = [
      %{category: "general", key: "timezone", value: "UTC", type: "string"},
      %{category: "general", key: "locale", value: "en", type: "string"},
      %{category: "security", key: "session_timeout_minutes", value: "30", type: "integer"},
      %{category: "security", key: "require_2fa", value: "false", type: "boolean"},
      %{category: "notifications", key: "email_enabled", value: "true", type: "boolean"},
      %{category: "notifications", key: "slack_enabled", value: "false", type: "boolean"},
      %{category: "billing", key: "invoice_day", value: "1", type: "integer"}
    ]

    Enum.each(default_settings, fn setting ->
      %{
        tenant_id: tenant.id,
        category: setting.category,
        key: setting.key,
        value: setting.value,
        type: setting.type
      }
      |> Mcp.MultiTenancy.TenantSettings.changeset(%Mcp.MultiTenancy.TenantSettings{})
      |> Repo.insert()
    end)

    {:ok, :settings_created}
  end

  defp create_default_domain(tenant) do
    default_domain = %{
      tenant_id: tenant.id,
      domain: "#{tenant.slug}.mcp-platform.com",
      primary: true,
      verified_at: DateTime.utc_now()
    }

    %TenantDomain{}
    |> TenantDomain.changeset(default_domain)
    |> Repo.insert()
  end
end
```

## Schema Management System

```elixir
defmodule Mcp.MultiTenancy.SchemaManager do
  @moduledoc """
  Manages PostgreSQL schema operations for tenant isolation
  """

  alias Mcp.Core.Repo

  def create_tenant_schema(schema_name) do
    # Validate schema name format
    if valid_schema_name?(schema_name) do
      with :ok <- create_schema(schema_name),
           :ok <- create_schema_extensions(schema_name),
           :ok <- grant_schema_permissions(schema_name) do
        {:ok, schema_name}
      else
        error -> error
      end
    else
      {:error, :invalid_schema_name}
    end
  end

  def run_tenant_migrations(schema_name) do
    # Get all tenant migration modules
    migrations = get_tenant_migrations()

    Enum.each(migrations, fn migration_module ->
      run_migration_in_schema(schema_name, migration_module)
    end)

    {:ok, :migrations_completed}
  end

  def drop_schema(schema_name) do
    sql = "DROP SCHEMA IF EXISTS #{schema_name} CASCADE;"
    Ecto.Adapters.SQL.query!(Repo, sql)
    :ok
  end

  def rename_schema(old_name, new_name) do
    if valid_schema_name?(new_name) do
      sql = "ALTER SCHEMA #{old_name} RENAME TO #{new_name};"
      Ecto.Adapters.SQL.query!(Repo, sql)
      :ok
    else
      {:error, :invalid_new_schema_name}
    end
  end

  def backup_schema(schema_name) do
    backup_timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    backup_name = "#{schema_name}_backup_#{backup_timestamp}"

    sql = "CREATE SCHEMA #{backup_name};"
    Ecto.Adapters.SQL.query!(Repo, sql)

    # Copy all tables from original schema to backup
    tables = list_schema_tables(schema_name)
    Enum.each(tables, fn table ->
      copy_table_to_schema(schema_name, backup_name, table)
    end)

    {:ok, backup_name}
  end

  def archive_schema(schema_name) do
    archive_timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    archive_name = "archive_#{schema_name}_#{archive_timestamp}"

    sql = "ALTER SCHEMA #{schema_name} RENAME TO #{archive_name};"
    Ecto.Adapters.SQL.query!(Repo, sql)

    {:ok, archive_name}
  end

  defp create_schema(schema_name) do
    sql = "CREATE SCHEMA #{schema_name};"
    Ecto.Adapters.SQL.query!(Repo, sql)
    :ok
  end

  defp create_schema_extensions(schema_name) do
    # Enable extensions in tenant schema
    extensions = [
      "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"",
      "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\"",
      "CREATE EXTENSION IF NOT EXISTS \"btree_gin\""
    ]

    Enum.each(extensions, fn extension_sql ->
      full_sql = "SET search_path TO #{schema_name}; #{extension_sql};"
      Ecto.Adapters.SQL.query!(Repo, full_sql)
    end)

    :ok
  end

  defp grant_schema_permissions(schema_name) do
    # Grant permissions to the application user
    sql = """
    GRANT USAGE ON SCHEMA #{schema_name} TO mcp_app;
    GRANT CREATE ON SCHEMA #{schema_name} TO mcp_app;
    GRANT ALL ON ALL TABLES IN SCHEMA #{schema_name} TO mcp_app;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA #{schema_name} TO mcp_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema_name} GRANT ALL ON TABLES TO mcp_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema_name} GRANT ALL ON SEQUENCES TO mcp_app;
    """

    Ecto.Adapters.SQL.query!(Repo, sql)
    :ok
  end

  defp list_schema_tables(schema_name) do
    sql = """
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = '#{schema_name}'
    """

    %Postgrex.Result{rows: rows} = Ecto.Adapters.SQL.query!(Repo, sql)
    Enum.map(rows, fn [table_name] -> table_name end)
  end

  defp copy_table_to_schema(source_schema, target_schema, table_name) do
    # Create table structure copy
    create_sql = """
    CREATE TABLE #{target_schema}.#{table_name}
    (LIKE #{source_schema}.#{table_name} INCLUDING ALL);
    """

    Ecto.Adapters.SQL.query!(Repo, create_sql)

    # Copy data
    copy_sql = """
    INSERT INTO #{target_schema}.#{table_name}
    SELECT * FROM #{source_schema}.#{table_name};
    """

    Ecto.Adapters.SQL.query!(Repo, copy_sql)
  end

  defp get_tenant_migrations do
    [
      Mcp.MultiTenancy.Migrations.Tenant.CreateUsers,
      Mcp.MultiTenancy.Migrations.Tenant.CreateSessions,
      Mcp.MultiTenancy.Migrations.Tenant.CreateAuditLogs
    ]
  end

  defp run_migration_in_schema(schema_name, migration_module) do
    # Set search path to tenant schema
    set_search_path_sql = "SET search_path TO #{schema_name}, public;"
    Ecto.Adapters.SQL.query!(Repo, set_search_path_sql)

    # Run migration
    migration_module.up()

    # Reset search path
    reset_search_path_sql = "SET search_path TO public;"
    Ecto.Adapters.SQL.query!(Repo, reset_search_path_sql)
  end

  defp valid_schema_name?(schema_name) do
    # Schema name must start with a letter and contain only letters, numbers, and underscores
    Regex.match?(~r/^[a-z][a-z0-9_]*$/, schema_name) and String.length(schema_name) <= 63
  end
end
```

## Tenant Context Management

```elixir
defmodule Mcp.MultiTenancy.TenantContext do
  @moduledoc """
  Manages tenant context switching and retrieval throughout the request lifecycle
  """

  def get_tenant_from_domain(domain) do
    case Mcp.MultiTenancy.TenantManager.get_tenant_by_domain(domain) do
      nil -> {:error, :tenant_not_found}
      tenant -> {:ok, tenant}
    end
  end

  def get_tenant_from_slug(slug) do
    case Mcp.MultiTenancy.TenantManager.get_tenant_by_slug(slug) do
      nil -> {:error, :tenant_not_found}
      tenant -> {:ok, tenant}
    end
  end

  def set_tenant_context(tenant) do
    Process.put(:tenant_id, tenant.id)
    Process.put(:tenant_slug, tenant.slug)
    Process.put(:tenant_schema, tenant.schema_name)

    # Switch database schema
    set_tenant_schema(tenant.schema_name)

    {:ok, tenant}
  end

  def get_current_tenant do
    tenant_id = Process.get(:tenant_id)

    if tenant_id do
      case Mcp.MultiTenancy.get_tenant(tenant_id) do
        nil -> {:error, :tenant_not_in_context}
        tenant -> {:ok, tenant}
      end
    else
      {:error, :no_tenant_context}
    end
  end

  def with_tenant(tenant, fun) do
    old_context = get_current_context()

    try do
      case set_tenant_context(tenant) do
        {:ok, _} -> fun.()
        error -> error
      end
    after
      restore_context(old_context)
    end
  end

  def current_tenant_id do
    Process.get(:tenant_id)
  end

  def current_tenant_schema do
    Process.get(:tenant_schema)
  end

  def in_tenant_context? do
    !!Process.get(:tenant_id)
  end

  defp set_tenant_schema(schema_name) do
    sql = "SET search_path TO #{schema_name}, public, platform, shared, ag_catalog;"
    Ecto.Adapters.SQL.query!(Mcp.Core.Repo, sql)
  end

  defp get_current_context do
    %{
      tenant_id: Process.get(:tenant_id),
      tenant_slug: Process.get(:tenant_slug),
      tenant_schema: Process.get(:tenant_schema)
    }
  end

  defp restore_context(context) do
    if context.tenant_schema do
      set_tenant_schema(context.tenant_schema)
    else
      # Reset to default schema path
      sql = "SET search_path TO public, platform, shared, ag_catalog;"
      Ecto.Adapters.SQL.query!(Mcp.Core.Repo, sql)
    end

    Process.put(:tenant_id, context.tenant_id)
    Process.put(:tenant_slug, context.tenant_slug)
    Process.put(:tenant_schema, context.tenant_schema)
  end
end
```

## Multi-Tenant Database Repository

```elixir
defmodule Mcp.MultiTenancy.TenantRepo do
  @moduledoc """
  Tenant-aware repository for database operations
  """

  alias Mcp.Core.Repo
  alias Mcp.MultiTenancy.TenantContext

  # Delegate all Ecto.Repo functions with tenant context
  def get(queryable, opts \\ []), do: with_tenant_context(&Repo.get/2, queryable, opts)
  def get!(queryable, id, opts \\ []), do: with_tenant_context(&Repo.get!/2, queryable, id, opts)
  def get_by(queryable, clauses, opts \\ []), do: with_tenant_context(&Repo.get_by/2, queryable, clauses, opts)
  def get_by!(queryable, clauses, opts \\ []), do: with_tenant_context(&Repo.get_by!/2, queryable, clauses, opts)

  def one(queryable, opts \\ []), do: with_tenant_context(&Repo.one/1, queryable, opts)
  def one!(queryable, opts \\ []), do: with_tenant_context(&Repo.one!/1, queryable, opts)
  def all(queryable, opts \\ []), do: with_tenant_context(&Repo.all/1, queryable, opts)

  def aggregate(queryable, agg, opts \\ []), do: with_tenant_context(&Repo.aggregate/3, queryable, agg, opts)
  def count(queryable, opts \\ []), do: with_tenant_context(&Repo.count/1, queryable, opts)

  def insert(changeset, opts \\ []), do: with_tenant_context(&Repo.insert/1, changeset, opts)
  def insert!(changeset, opts \\ []), do: with_tenant_context(&Repo.insert!/1, changeset, opts)
  def insert_all(schema_or_source, entries, opts \\ []), do: with_tenant_context(&Repo.insert_all/2, schema_or_source, entries, opts)

  def update(changeset, opts \\ []), do: with_tenant_context(&Repo.update/1, changeset, opts)
  def update!(changeset, opts \\ []), do: with_tenant_context(&Repo.update!/1, changeset, opts)
  def update_all(queryable, updates, opts \\ []), do: with_tenant_context(&Repo.update_all/2, queryable, updates, opts)

  def delete(struct_or_changeset, opts \\ []), do: with_tenant_context(&Repo.delete/1, struct_or_changeset, opts)
  def delete!(struct_or_changeset, opts \\ []), do: with_tenant_context(&Repo.delete!/1, struct_or_changeset, opts)
  def delete_all(queryable, opts \\ []), do: with_tenant_context(&Repo.delete_all/1, queryable, opts)

  def transaction(fun_or_multi, opts \\ []), do: with_tenant_context(&Repo.transaction/2, fun_or_multi, opts)

  # Custom tenant-specific functions
  def insert_with_tenant(changeset, tenant, opts \\ []) do
    TenantContext.with_tenant(tenant, fn ->
      Repo.insert(changeset, opts)
    end)
  end

  def update_with_tenant(changeset, tenant, opts \\ []) do
    TenantContext.with_tenant(tenant, fn ->
      Repo.update(changeset, opts)
    end)
  end

  def delete_with_tenant(struct_or_changeset, tenant, opts \\ []) do
    TenantContext.with_tenant(tenant, fn ->
      Repo.delete(struct_or_changeset, opts)
    end)
  end

  def query_with_tenant(query, tenant, opts \\ []) do
    TenantContext.with_tenant(tenant, fn ->
      Repo.all(query, opts)
    end)
  end

  defp with_tenant_context(fun, args) when is_function(fun, 1) do
    if TenantContext.in_tenant_context? do
      fun.(args)
    else
      {:error, :no_tenant_context}
    end
  end

  defp with_tenant_context(fun, arg1, arg2) when is_function(fun, 2) do
    if TenantContext.in_tenant_context? do
      fun.(arg1, arg2)
    else
      {:error, :no_tenant_context}
    end
  end

  defp with_tenant_context(fun, arg1, arg2, arg3) when is_function(fun, 3) do
    if TenantContext.in_tenant_context? do
      fun.(arg1, arg2, arg3)
    else
      {:error, :no_tenant_context}
    end
  end
end
```

## Phoenix Plug for Tenant Resolution

```elixir
defmodule McpWeb.Plugs.TenantResolver do
  @moduledoc """
  Phoenix plug for resolving tenant from domain and setting tenant context
  """

  import Plug.Conn
  alias Mcp.MultiTenancy.TenantContext

  def init(opts), do: opts

  def call(conn, _opts) do
    host = get_host(conn)

    case resolve_tenant_from_host(host) do
      {:ok, tenant} ->
        TenantContext.set_tenant_context(tenant)
        assign(conn, :current_tenant, tenant)

      {:error, :tenant_not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(McpWeb.ErrorView)
        |> render(:"404")
        |> halt()

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> put_view(McpWeb.ErrorView)
        |> render(:"500")
        |> halt()
    end
  end

  defp get_host(conn) do
    conn |> get_req_header("host") |> List.first()
  end

  defp resolve_tenant_from_host(nil), do: {:error, :no_host}

  defp resolve_tenant_from_host(host) do
    # Extract domain from host (remove port if present)
    domain = String.split(host, ":") |> List.first()

    # Try exact domain match first
    case TenantContext.get_tenant_from_domain(domain) do
      {:ok, tenant} -> {:ok, tenant}
      {:error, :tenant_not_found} ->
        # Try subdomain pattern (extract slug from subdomain)
        resolve_from_subdomain(domain)
    end
  end

  defp resolve_from_subdomain(domain) do
    case String.split(domain, ".") do
      [slug | _rest] when slug != "www" and slug != "app" ->
        TenantContext.get_tenant_from_slug(slug)
      _ ->
        {:error, :tenant_not_found}
    end
  end
end
```

## Multi-Tenant Ash Resources

```elixir
defmodule Mcp.MultiTenancy.Tenant do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshAdmin.Resource]

  postgres do
    table "tenants"
    repo Mcp.Core.Repo
  end

  json_api do
    type "tenant"
    routes [:create, :read, :update, :destroy]
  end

  admin do
    table_columns [:id, :name, :slug, :domain, :status, :plan, :inserted_at]
    actor [:system_admin]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :domain, :string
    attribute :schema_name, :string, allow_nil?: false
    attribute :status, :string, default: "pending"
    attribute :plan, :string, default: "basic"
    attribute :settings, :map, default: %{}
    attribute :limits, :map, default: %{}
    attribute :usage, :map, default: %{}
    attribute :billing_customer_id, :string
    attribute :subscription_id, :string
    attribute :metadata, :map, default: %{}

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :domains, Mcp.MultiTenancy.TenantDomain
    has_many :users, Mcp.MultiTenancy.TenantUser
    has_many :settings, Mcp.MultiTenancy.TenantSettings
    has_many :usage_logs, Mcp.MultiTenancy.TenantUsageLog
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :domain, :schema_name, :plan, :settings, :limits, :metadata]

      argument :domains, {:array, :map}
      change manage_relationship(:domains, type: :append)
    end

    read :read do
      primary? true
      filter [:status, :plan]
      sort [:inserted_at]
    end

    update :update do
      primary? true
      accept [:name, :status, :plan, :settings, :limits, :metadata]
    end

    destroy :destroy do
      primary? true
    end

    action :archive do
      argument :reason, :string
      change set_attribute(:status, "archived")
      change set_attribute(:metadata, fn tenant ->
        Map.merge(tenant.metadata, %{
          "archived_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "archive_reason" => tenant.metadata["archive_reason"]
        })
      end)
    end
  end

  calculations do
    calculate :storage_usage_percent, :float, expr(
      if usage.storage_gb > 0 and limits.storage_gb > 0 do
        (usage.storage_gb / limits.storage_gb) * 100
      else
        0.0
      end
    )

    calculate :user_usage_percent, :float, expr(
      if usage.users > 0 and limits.users > 0 do
        (usage.users / limits.users) * 100
      else
        0.0
      end
    )
  end

  validations do
    validate match(:slug, ~r/^[a-z][a-z0-9_-]*$/) do
      message "must start with a lowercase letter and contain only lowercase letters, numbers, hyphens, and underscores"
    end

    validate match(:schema_name, ~r/^[a-z][a-z0-9_]*$/) do
      message "must start with a lowercase letter and contain only lowercase letters, numbers, and underscores"
    end

    validate compare(:usage.storage_gb, less_than_or_equal_to: :limits.storage_gb) do
      message "storage usage cannot exceed limits"
    end

    validate compare(:usage.users, less_than_or_equal_to: :limits.users) do
      message "user count cannot exceed limits"
    end
  end
end
```

## Testing Multi-Tenancy

```elixir
defmodule Mcp.MultiTenancy.TenantTest do
  use ExUnit.Case, async: false

  alias Mcp.MultiTenancy.{TenantManager, TenantContext}

  setup do
    # Clean up after each test
    on_exit(fn ->
      cleanup_test_schemas()
    end)
  end

  describe "create_tenant/1" do
    test "creates tenant with schema" do
      tenant_params = %{
        name: "Test Tenant",
        slug: "test-tenant",
        schema_name: "test_tenant"
      }

      assert {:ok, tenant} = TenantManager.create_tenant(tenant_params)
      assert tenant.name == "Test Tenant"
      assert tenant.slug == "test-tenant"
      assert tenant.schema_name == "test_tenant"
      assert tenant.status == "pending"

      # Verify schema was created
      assert schema_exists?(tenant.schema_name)
    end

    test "validates schema name format" do
      invalid_params = %{
        name: "Test Tenant",
        slug: "test-tenant",
        schema_name: "Invalid-Schema"
      }

      assert {:error, _reason} = TenantManager.create_tenant(invalid_params)
    end
  end

  describe "tenant context switching" do
    test "sets and retrieves tenant context" do
      tenant = insert!(:tenant)

      {:ok, _} = TenantContext.set_tenant_context(tenant)

      assert {:ok, current_tenant} = TenantContext.get_current_tenant()
      assert current_tenant.id == tenant.id
      assert TenantContext.current_tenant_id() == tenant.id
      assert TenantContext.current_tenant_schema() == tenant.schema_name
    end

    test "with_tenant executes function in tenant context" do
      tenant = insert!(:tenant)

      result = TenantContext.with_tenant(tenant, fn ->
        assert TenantContext.current_tenant_id() == tenant.id
        :context_test_result
      end)

      assert result == :context_test_result
      refute TenantContext.in_tenant_context?()
    end
  end

  describe "tenant data isolation" do
    test "data is isolated between tenants" do
      tenant1 = insert!(:tenant, %{schema_name: "tenant1"})
      tenant2 = insert!(:tenant, %{schema_name: "tenant2"})

      # Create user in tenant1
      user1 = TenantContext.with_tenant(tenant1, fn ->
        %Mcp.Accounts.User{email: "user1@tenant1.com"} |> Repo.insert!()
      end)

      # Create user in tenant2
      user2 = TenantContext.with_tenant(tenant2, fn ->
        %Mcp.Accounts.User{email: "user2@tenant2.com"} |> Repo.insert!()
      end)

      # Verify data isolation
      assert TenantContext.with_tenant(tenant1, fn ->
        Repo.get(Mcp.Accounts.User, user1.id) != nil
      end)

      assert TenantContext.with_tenant(tenant1, fn ->
        Repo.get(Mcp.Accounts.User, user2.id) == nil
      end)

      assert TenantContext.with_tenant(tenant2, fn ->
        Repo.get(Mcp.Accounts.User, user2.id) != nil
      end)
    end
  end

  defp schema_exists?(schema_name) do
    sql = """
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name = $1
    """

    %Postgrex.Result{rows: rows} = Ecto.Adapters.SQL.query!(Repo, sql, [schema_name])
    length(rows) > 0
  end

  defp cleanup_test_schemas do
    # Clean up test schemas
    schemas_to_clean = ["test_tenant", "tenant1", "tenant2"]

    Enum.each(schemas_to_clean, fn schema ->
      if schema_exists?(schema) do
        Mcp.MultiTenancy.SchemaManager.drop_schema(schema)
      end
    end)
  end
end
```

This developer guide provides comprehensive technical implementation details for the multi-tenancy framework, including tenant management, schema isolation, context switching, and multi-tenant application development patterns for building scalable, secure multi-tenant applications on the MCP platform.