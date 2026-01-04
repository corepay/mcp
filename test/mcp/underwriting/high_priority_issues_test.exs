defmodule Mcp.Underwriting.HighPriorityIssuesTest do
  @moduledoc """
  TDD Red Phase Tests for HIGH Priority Underwriting Issues.

  These tests are designed to FAIL initially, proving the issues exist.
  After fixing the code, they should all pass.

  Issues Tested:
  - HIGH-1: Client resource missing code_interface functions
  - HIGH-2: Check resource missing code_interface functions
  - HIGH-3: ComplyCube adapter missing @behaviour declaration
  - HIGH-4: ComplyCube adapter missing check_watchlist callback
  - HIGH-6: Missing multitenancy on 6 AI-related resources
  - HIGH-7: Timestamp macro inconsistency (informational)
  - HIGH-8: AgentRunner hardcoded ports
  - HIGH-9: OpenRouter model hardcoded
  """

  use Mcp.DataCase

  alias Mcp.Platform.Tenant

  alias Mcp.Underwriting.{
    AgentBlueprint,
    Application,
    Check,
    Client,
    InstructionSet,
    Pipeline
  }

  alias Mcp.Underwriting.Adapters.ComplyCube

  # =============================================================================
  # HIGH-1: Client Resource Missing code_interface Functions
  # =============================================================================
  #
  # The Client resource needs additional code_interface functions for:
  # - get_by_email/2 - lookup by email address
  # - get_by_external_id/2 - lookup by vendor ID (ComplyCube, Idenfy)
  # - list_by_application/2 - get all clients for an application
  # =============================================================================

  describe "HIGH-1: Client code_interface completeness" do
    setup do
      tenant = create_test_tenant("high1")
      merchant = create_test_merchant(tenant.company_schema)
      application = create_test_application(merchant, tenant.company_schema)

      {:ok, tenant: tenant.company_schema, application: application}
    end

    test "get_by_email returns client with matching email", %{tenant: tenant, application: app} do
      # Create a client with specific email
      email = "test-high1@example.com"

      {:ok, created_client} =
        Client
        |> Ash.Changeset.for_create(:create, %{
          type: :person,
          email: email,
          person_details: %{"first_name" => "Test", "last_name" => "User"},
          application_id: app.id
        })
        |> Ash.create(tenant: tenant)

      # This should work - get_by_email function should exist
      assert {:ok, found_client} = Client.get_by_email(email, tenant: tenant)
      assert found_client.id == created_client.id
    end

    test "get_by_external_id returns client with vendor ID", %{tenant: tenant, application: app} do
      # Create a client with external vendor ID
      external_id = "cc_vendor_123"

      {:ok, created_client} =
        Client
        |> Ash.Changeset.for_create(:create, %{
          type: :person,
          email: "vendor@example.com",
          external_id: external_id,
          person_details: %{"first_name" => "Vendor", "last_name" => "Client"},
          application_id: app.id
        })
        |> Ash.create(tenant: tenant)

      # This should work - get_by_external_id function should exist
      assert {:ok, found_client} = Client.get_by_external_id(external_id, tenant: tenant)
      assert found_client.id == created_client.id
    end

    test "list_by_application returns all clients for application", %{
      tenant: tenant,
      application: app
    } do
      # Create multiple clients for the application
      {:ok, _client1} =
        Client
        |> Ash.Changeset.for_create(:create, %{
          type: :person,
          email: "client1@example.com",
          person_details: %{"first_name" => "Client", "last_name" => "One"},
          application_id: app.id
        })
        |> Ash.create(tenant: tenant)

      {:ok, _client2} =
        Client
        |> Ash.Changeset.for_create(:create, %{
          type: :person,
          email: "client2@example.com",
          person_details: %{"first_name" => "Client", "last_name" => "Two"},
          application_id: app.id
        })
        |> Ash.create(tenant: tenant)

      # This should work - list_by_application function should exist
      {:ok, clients} = Client.list_by_application(app.id, tenant: tenant)
      assert length(clients) == 2
    end
  end

  # =============================================================================
  # HIGH-2: Check Resource Missing code_interface Functions
  # =============================================================================
  #
  # The Check resource needs additional code_interface functions for:
  # - list_by_client/2 - get all checks for a client
  # - get_latest_by_type/3 - get most recent check of a specific type
  # =============================================================================

  describe "HIGH-2: Check code_interface completeness" do
    setup do
      tenant = create_test_tenant("high2")
      merchant = create_test_merchant(tenant.company_schema)
      application = create_test_application(merchant, tenant.company_schema)
      client = create_test_client(application, tenant.company_schema)

      {:ok, tenant: tenant.company_schema, client: client}
    end

    test "list_by_client returns all checks for client", %{tenant: tenant, client: client} do
      # Create multiple checks for the client
      {:ok, _check1} =
        Check
        |> Ash.Changeset.for_create(:create, %{
          type: :identity_check,
          status: :complete,
          outcome: :clear,
          raw_result: %{},
          client_id: client.id
        })
        |> Ash.create(tenant: tenant)

      {:ok, _check2} =
        Check
        |> Ash.Changeset.for_create(:create, %{
          type: :document_check,
          status: :complete,
          outcome: :clear,
          raw_result: %{},
          client_id: client.id
        })
        |> Ash.create(tenant: tenant)

      # This should work - list_by_client function should exist
      {:ok, checks} = Check.list_by_client(client.id, tenant: tenant)
      assert length(checks) == 2
    end

    test "get_latest_by_type returns most recent check of type", %{tenant: tenant, client: client} do
      # Create older check
      {:ok, older_check} =
        Check
        |> Ash.Changeset.for_create(:create, %{
          type: :identity_check,
          status: :complete,
          outcome: :clear,
          raw_result: %{version: "old"},
          client_id: client.id
        })
        |> Ash.create(tenant: tenant)

      # Wait a moment to ensure different timestamps
      Process.sleep(10)

      # Create newer check of same type
      {:ok, newer_check} =
        Check
        |> Ash.Changeset.for_create(:create, %{
          type: :identity_check,
          status: :complete,
          outcome: :clear,
          raw_result: %{version: "new"},
          client_id: client.id
        })
        |> Ash.create(tenant: tenant)

      # This should work - get_latest_by_type function should exist
      {:ok, latest} = Check.get_latest_by_type(client.id, :identity_check, tenant: tenant)
      assert latest.id == newer_check.id
      assert latest.id != older_check.id
    end
  end

  # =============================================================================
  # HIGH-3: ComplyCube Adapter Missing @behaviour Declaration
  # =============================================================================
  #
  # ComplyCube adapter should declare @behaviour Mcp.Underwriting.Adapter
  # to ensure compile-time checking of callback implementations.
  # =============================================================================

  describe "HIGH-3: ComplyCube @behaviour declaration" do
    test "ComplyCube declares @behaviour Mcp.Underwriting.Adapter" do
      # Get the behaviours declared by ComplyCube module
      behaviours = ComplyCube.__info__(:attributes)[:behaviour] || []

      assert Mcp.Underwriting.Adapter in behaviours,
             "ComplyCube should declare @behaviour Mcp.Underwriting.Adapter"
    end

    test "ComplyCube implements all required callbacks" do
      # Verify all callback functions are exported
      assert function_exported?(ComplyCube, :verify_identity, 2),
             "ComplyCube must implement verify_identity/2"

      assert function_exported?(ComplyCube, :screen_business, 2),
             "ComplyCube must implement screen_business/2"

      assert function_exported?(ComplyCube, :check_watchlist, 2),
             "ComplyCube must implement check_watchlist/2"

      assert function_exported?(ComplyCube, :document_check, 3),
             "ComplyCube must implement document_check/3"
    end
  end

  # =============================================================================
  # HIGH-4: ComplyCube Adapter Missing check_watchlist Callback
  # =============================================================================
  #
  # The Adapter behaviour requires check_watchlist/2 but ComplyCube doesn't
  # implement it. This will cause runtime errors.
  # =============================================================================

  describe "HIGH-4: ComplyCube check_watchlist implementation" do
    test "check_watchlist returns structured result" do
      # This should return a proper result, not {:error, :not_implemented}
      result = ComplyCube.check_watchlist("John Doe", %{})

      # Should not be an error for not implemented
      refute match?({:error, :not_implemented}, result),
             "check_watchlist should be implemented, not return :not_implemented"

      # Should return proper structure
      assert match?({:ok, %{status: _, provider: _}}, result) or
               match?({:error, _reason}, result),
             "check_watchlist should return {:ok, %{status, provider}} or {:error, reason}"
    end

    test "check_watchlist handles context with client_id" do
      context = %{client_id: Ash.UUID.generate()}
      result = ComplyCube.check_watchlist("Jane Smith", context)

      # Should accept context and process it
      refute match?({:error, :not_implemented}, result),
             "check_watchlist should accept context parameter"
    end
  end

  # =============================================================================
  # HIGH-6: Missing Multitenancy on AI Resources
  # =============================================================================
  #
  # These resources are MISSING multitenancy configuration:
  # - AgentBlueprint
  # - InstructionSet
  # - Pipeline
  # - Execution
  # This is a COMPLIANCE issue - data from different tenants will mix.
  # =============================================================================

  describe "HIGH-6: Multitenancy isolation on AI resources" do
    setup do
      tenant_a = create_test_tenant("high6a")
      tenant_b = create_test_tenant("high6b")

      {:ok, tenant_a: tenant_a.company_schema, tenant_b: tenant_b.company_schema}
    end

    test "AgentBlueprint is tenant-isolated", %{tenant_a: tenant_a, tenant_b: tenant_b} do
      # Create blueprint in tenant A
      {:ok, blueprint} =
        AgentBlueprint
        |> Ash.Changeset.for_create(:create, %{
          name: "TenantABlueprint",
          base_prompt: "You are an agent for Tenant A only."
        })
        |> Ash.create(tenant: tenant_a)

      # Should NOT be visible in tenant B
      require Ash.Query

      blueprints_in_b =
        AgentBlueprint
        |> Ash.Query.filter(id == ^blueprint.id)
        |> Ash.read!(tenant: tenant_b)

      assert blueprints_in_b == [],
             "AgentBlueprint created in tenant A should NOT be visible in tenant B"
    end

    test "InstructionSet is tenant-isolated", %{tenant_a: tenant_a, tenant_b: tenant_b} do
      # First create a blueprint (required for InstructionSet)
      {:ok, blueprint} =
        AgentBlueprint
        |> Ash.Changeset.for_create(:create, %{
          name: "TenantABlueprintForInstr",
          base_prompt: "Prompt for Tenant A."
        })
        |> Ash.create(tenant: tenant_a)

      # Create instruction set in tenant A
      {:ok, instruction_set} =
        InstructionSet
        |> Ash.Changeset.for_create(:create, %{
          name: "TenantAInstructions",
          instructions: "Instructions for Tenant A only.",
          blueprint_id: blueprint.id
        })
        |> Ash.create(tenant: tenant_a)

      # Should NOT be visible in tenant B
      require Ash.Query

      sets_in_b =
        InstructionSet
        |> Ash.Query.filter(id == ^instruction_set.id)
        |> Ash.read!(tenant: tenant_b)

      assert sets_in_b == [],
             "InstructionSet created in tenant A should NOT be visible in tenant B"
    end

    test "Pipeline is tenant-isolated", %{tenant_a: tenant_a, tenant_b: tenant_b} do
      # Create pipeline in tenant A (uses stages, not steps)
      {:ok, pipeline} =
        Pipeline
        |> Ash.Changeset.for_create(:create, %{
          name: "TenantAPipeline",
          stages: []
        })
        |> Ash.create(tenant: tenant_a)

      # Should NOT be visible in tenant B
      require Ash.Query

      pipelines_in_b =
        Pipeline
        |> Ash.Query.filter(id == ^pipeline.id)
        |> Ash.read!(tenant: tenant_b)

      assert pipelines_in_b == [],
             "Pipeline created in tenant A should NOT be visible in tenant B"
    end
  end

  # =============================================================================
  # HIGH-8: AgentRunner Hardcoded Ports
  # =============================================================================
  #
  # AgentRunner uses hardcoded default ports instead of reading from config.
  # This violates the project's "NO HARDCODED PORTS" rule.
  # =============================================================================

  describe "HIGH-8: AgentRunner port configuration" do
    test "AgentRunner reads OLLAMA_PORT from Application config" do
      # Read the source file to verify port handling
      source_path = "lib/mcp/underwriting/engine/agent_runner.ex"
      {:ok, source} = File.read(source_path)

      # Should NOT have hardcoded port as the second argument to System.get_env
      # Fixed: Now uses Application.get_env(:mcp, :ollama) and System.get_env without hardcoded default
      refute source =~ ~r/System\.get_env\("OLLAMA_PORT",\s*"42736"\)/,
             "OLLAMA_PORT should not have hardcoded fallback in System.get_env"

      # Should use proper Application config lookup
      assert source =~ "Application.get_env(:mcp, :ollama",
             "Should read OLLAMA config from Application.get_env(:mcp, :ollama)"
    end
  end

  # =============================================================================
  # HIGH-9: OpenRouter Model Hardcoded
  # =============================================================================
  #
  # AgentRunner hardcodes the OpenRouter model to "openai/gpt-3.5-turbo"
  # instead of reading from configuration.
  # =============================================================================

  describe "HIGH-9: OpenRouter model configuration" do
    test "AgentRunner reads OpenRouter model from config" do
      # Read the source file to verify model handling
      source_path = "lib/mcp/underwriting/engine/agent_runner.ex"
      {:ok, source} = File.read(source_path)

      # Should NOT have hardcoded model as a direct assignment
      # Fixed: model = config[:openrouter_model] || "fallback"
      # The fallback is acceptable, but the primary source should be config

      # Verify the model is read from config first
      assert source =~ ~r/config\[:openrouter_model\]/,
             "OpenRouter model should be read from config[:openrouter_model]"

      # Verify it's not just a hardcoded string without config lookup
      refute source =~ ~r/\n\s*model\s*=\s*"openai\/gpt-3\.5-turbo"\s*$/m,
             "OpenRouter model should not be hardcoded without config lookup"
    end
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp create_test_tenant(prefix) do
    slug = "#{prefix}-#{:rand.uniform(999_999)}"

    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "#{prefix} Test Tenant",
        slug: slug,
        subdomain: slug
      })
      |> Ash.create!()

    # Create required tenant tables
    create_tenant_tables(tenant.company_schema)

    tenant
  end

  defp create_test_merchant(schema) do
    Mcp.Platform.Merchant
    |> Ash.Changeset.for_create(:create, %{
      business_name: "Test Merchant",
      slug: "test-merchant-#{:rand.uniform(999_999)}",
      subdomain: "test-#{:rand.uniform(999_999)}",
      status: :active
    })
    |> Ash.create!(tenant: schema)
  end

  defp create_test_application(merchant, schema) do
    Application
    |> Ash.Changeset.for_create(:create, %{
      subject_id: merchant.id,
      subject_type: :merchant,
      status: :submitted,
      application_data: %{"business_name" => "Test Corp"}
    })
    |> Ash.create!(tenant: schema)
  end

  defp create_test_client(application, schema) do
    Client
    |> Ash.Changeset.for_create(:create, %{
      type: :person,
      email: "test-client-#{:rand.uniform(999_999)}@example.com",
      person_details: %{"first_name" => "Test", "last_name" => "Client"},
      application_id: application.id
    })
    |> Ash.create!(tenant: schema)
  end

  defp create_tenant_tables(schema) do
    # Create merchants table
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".merchants (
        id uuid PRIMARY KEY,
        slug text,
        business_name text,
        dba_name text,
        subdomain text,
        custom_domain text,
        business_type text,
        ein text,
        website_url text,
        description text,
        address_line1 text,
        address_line2 text,
        city text,
        state text,
        postal_code text,
        country text,
        phone text,
        support_email text,
        plan text,
        status text,
        risk_level text,
        settings jsonb,
        branding jsonb,
        max_stores integer,
        max_products integer,
        max_monthly_volume decimal,
        kyc_verified_at timestamp(6),
        verification_status text,
        mcc text,
        tax_id_type text,
        kyc_status text,
        kyc_documents jsonb,
        timezone text,
        default_currency text,
        operating_hours jsonb,
        risk_score integer,
        risk_profile text,
        processing_limits jsonb,
        reseller_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # Create underwriting_applications table
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".underwriting_applications (
        id uuid PRIMARY KEY,
        status text,
        application_data jsonb,
        risk_score integer,
        subject_id uuid,
        subject_type text,
        submitted_at timestamp(6),
        sla_due_at timestamp(6),
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # Create underwriting_clients table
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".underwriting_clients (
        id uuid PRIMARY KEY,
        type text,
        email text,
        phone text,
        external_id text,
        person_details jsonb,
        company_details jsonb,
        application_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # Create underwriting_checks table
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".underwriting_checks (
        id uuid PRIMARY KEY,
        type text,
        status text,
        outcome text,
        external_id text,
        raw_result jsonb,
        client_id uuid,
        document_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # Create agent_blueprints table
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".agent_blueprints (
        id uuid PRIMARY KEY,
        name text,
        description text,
        base_prompt text,
        tools text[],
        knowledge_base_ids uuid[],
        routing_config jsonb,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # Create instruction_sets table
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".instruction_sets (
        id uuid PRIMARY KEY,
        name text,
        instructions text,
        blueprint_id uuid,
        tenant_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    # Create pipelines table
    Mcp.Repo.query!("""
      CREATE TABLE IF NOT EXISTS "#{schema}".pipelines (
        id uuid PRIMARY KEY,
        name text,
        description text,
        stages jsonb,
        review_required boolean DEFAULT false,
        tenant_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)
  end
end
