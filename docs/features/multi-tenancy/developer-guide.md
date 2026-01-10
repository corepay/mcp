# Multi-Tenancy Framework - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP multi-tenancy system. Includes tenant management, schema isolation, context switching, and multi-tenant application development patterns.

## Architecture Overview

The multi-tenancy framework follows a schema-based isolation approach:

-   **Tenant Management Layer**: `Mcp.Platform.TenantSettingsManager` handles tenant configuration and settings.
-   **Context Routing Layer**: `McpWeb.TenantRouting` manages connection-based context switching via `conn.assigns`.
-   **Provisioning Layer**: `Mcp.Platform.SchemaProvisioner` orchestrates schema creation and migration.
-   **Schema Isolation Layer**: PostgreSQL schema-based data separation and security.

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

## Tenant Provisioning

We use an **Ash Change** to orchestrate tenant creation. This ensures that the database schema is created and seeded transactionally when a `Tenant` resource is created.

```elixir
# lib/mcp/platform/tenants/changes/provision_tenant.ex
defmodule Mcp.Platform.Tenants.Changes.ProvisionTenant do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, tenant ->
      case Mcp.Infrastructure.TenantManager.create_tenant_schema(tenant.schema_name) do
        {:ok, _} -> {:ok, tenant}
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end
```

## Tenant Management System

## Tenant Settings Management

```elixir
defmodule Mcp.Platform.TenantSettingsManager do
  @moduledoc """
  Manages tenant settings, features, and branding configuration.
  """

  alias Mcp.Platform.{Tenant, TenantSettings}
  alias Mcp.Core.Repo
  import Ecto.Query

  def get_all_tenant_settings(tenant_id) do
    settings =
      TenantSettings
      |> where([s], s.tenant_id == ^tenant_id)
      |> Repo.all()

    # Group by category
    grouped = Enum.group_by(settings, & &1.category, fn s -> {s.key, s.value} end)
    
    # Convert to map
    result = Map.new(grouped, fn {k, v} -> {k, Map.new(v)} end)
    
    {:ok, result}
  end

  def get_tenant_branding(tenant_id) do
    # Implementation for fetching branding settings
    # ...
  end

  def update_tenant_setting(tenant_id, category, key, value) do
    # Implementation for updating a specific setting
    # ...
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



## Phoenix Plug for Tenant Resolution

```elixir
defmodule McpWeb.TenantRouting do
  @moduledoc """
  Plug for tenant identification and routing based on subdomain or custom domain.

  This plug extracts tenant information from the HTTP host and sets up the proper
  tenant context for the request, enabling multi-tenancy via subdomain routing.
  """

  import Plug.Conn

  alias Mcp.Platform.Tenant
  require Logger

  @doc """
  Initialize the plug with configuration options.
  """
  def init(opts \\ []) do
    Keyword.merge(
      [
        base_domain: get_base_domain(),
        fallback_tenant: nil,
        skip_subdomain_extraction: false
      ],
      opts
    )
  end

  @doc """
  Call the plug to handle tenant routing.
  """
  def call(conn, opts) do
    if Keyword.get(opts, :skip_subdomain_extraction, false) do
      conn
    else
      case extract_tenant_from_host(conn, opts) do
        {:ok, tenant} ->
          setup_tenant_context(conn, tenant)

        {:error, :tenant_not_found} ->
          handle_tenant_not_found(conn, opts)

        {:error, :invalid_host} ->
          handle_invalid_host(conn, opts)
      end
    end
  end

  @doc """
  Extract tenant information from the current connection.
  """
  def get_current_tenant(conn) do
    conn.assigns[:current_tenant]
  end

  @doc """
  Check if the current request is in a tenant context.
  """
  def tenant_context?(conn) do
    not is_nil(conn.assigns[:current_tenant])
  end

  @doc """
  Get the base domain for tenant routing.
  """
  def get_base_domain do
    Application.get_env(:mcp, :base_domain, "localhost")
  end

  # Private functions

  defp extract_tenant_from_host(conn, _opts) do
    host = get_host(conn)

    if is_nil(host) or host == "" do
      {:error, :invalid_host}
    else
      case identify_tenant_from_host(host) do
        {:ok, tenant} -> {:ok, tenant}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp get_host(conn) do
    # Try various headers to get the actual host
    case get_req_header(conn, "x-forwarded-host") do
      [host | _] ->
        String.downcase(host)

      [] ->
        case get_req_header(conn, "host") do
          [host | _] -> String.downcase(host)
          [] -> nil
        end
    end
  end

  defp identify_tenant_from_host(host) do
    # Remove port if present
    host_without_port = String.split(host, ":") |> List.first()

    cond do
      # Check for custom domain first
      tenant_by_custom_domain =
          Tenant.by_custom_domain!(host_without_port)
          |> Enum.at(0) ->
        {:ok, tenant_by_custom_domain}

      # Check for subdomain pattern
      matches_subdomain_pattern?(host_without_port) ->
        subdomain = extract_subdomain_from_host(host_without_port)

        case Tenant.by_subdomain!(subdomain) |> Enum.at(0) do
          nil -> {:error, :tenant_not_found}
          tenant -> {:ok, tenant}
        end

      # Base domain - no tenant context
      base_domain?(host_without_port) ->
        {:error, :tenant_not_found}

      # Unknown pattern
      true ->
        {:error, :tenant_not_found}
    end
  rescue
    Ash.Error.Invalid.NoSuchResource -> {:error, :tenant_not_found}
    Ash.Error.Query.NotFound -> {:error, :tenant_not_found}
    _ -> {:error, :tenant_not_found}
  end

  defp matches_subdomain_pattern?(host) do
    base_domain = get_base_domain()
    String.ends_with?(host, ".#{base_domain}") and String.contains?(host, ".")
  end

  defp base_domain?(host) do
    base_domain = get_base_domain()
    host == base_domain or host == "www.#{base_domain}"
  end

  defp extract_subdomain_from_host(host) do
    base_domain = get_base_domain()
    subdomain_part = String.replace_prefix(host, ".#{base_domain}", "")

    # Handle potential www prefix for base domain
    case String.split(subdomain_part, ".") do
      [subdomain] -> subdomain
      [subdomain | _] -> subdomain
      [] -> host
    end
  end

  defp setup_tenant_context(conn, tenant) do
    conn
    |> assign(:current_tenant, tenant)
    |> assign(:tenant_schema, tenant.company_schema)
    |> assign(:tenant_id, tenant.id)
    |> put_private(:tenant_id, tenant.id)
    |> put_private(:tenant_schema, tenant.company_schema)
  end

  defp handle_tenant_not_found(conn, opts) do
    fallback_tenant = Keyword.get(opts, :fallback_tenant)

    if fallback_tenant do
      # In development, you might want to fall back to a default tenant
      conn
      |> assign(:current_tenant, nil)
      |> assign(:tenant_schema, nil)
      |> assign(:tenant_id, nil)
    else
      # In production, return 404 for unknown tenants
      if Application.get_env(:mcp, :env) == :prod do
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(:not_found, render_tenant_not_found_page())
        |> halt()
      else
        # In development, continue without tenant context for debugging
        conn
        |> assign(:current_tenant, nil)
        |> assign(:tenant_schema, nil)
        |> assign(:tenant_id, nil)
      end
    end
  end

  defp handle_invalid_host(conn, _opts) do
    if Mix.env() == :test do
      conn
    else
      host = get_host(conn)
      Logger.warning("Invalid host access attempt: #{host}")

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(:bad_request, "Invalid host header")
      |> halt()
    end
  end

  defp render_tenant_not_found_page do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Tenant Not Found</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #e53e3e; }
        p { color: #4a5568; }
      </style>
    </head>
    <body>
      <h1>Tenant Not Found</h1>
      <p>The requested tenant could not be found or may have been deactivated.</p>
      <p>Please check the URL and try again.</p>
    </body>
    </html>
    """
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