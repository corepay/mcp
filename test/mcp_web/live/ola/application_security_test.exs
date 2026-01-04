defmodule McpWeb.Ola.ApplicationSecurityTest do
  use McpWeb.ConnCase
  import Phoenix.LiveViewTest

  @moduletag :integration

  require Ash.Query

  alias Mcp.Accounts.{Auth, User}
  alias Mcp.Platform.{Merchant, Tenant}
  alias Mcp.Repo
  alias Mcp.Underwriting.Application

  setup do
    # 1. Create Tenant
    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Security Test Tenant",
        slug: "security-test-tenant",
        subdomain: "security-test-tenant"
      })
      |> Ash.create!()

    # WORKAROUND: Setup dynamic tenant tables manually
    schema = tenant.company_schema

    # Ensure platform.users has merchant_id (Workaround for Sandbox migration visibility)
    Repo.query!("ALTER TABLE platform.users ADD COLUMN IF NOT EXISTS merchant_id uuid")

    Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    Repo.query!("""
      CREATE TABLE IF NOT EXISTS \"#{schema}\".merchants (
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
        country text DEFAULT 'US',
        phone text,
        support_email text,
        plan text DEFAULT 'starter',
        status text DEFAULT 'active',
        settings jsonb DEFAULT '{}',
        branding jsonb DEFAULT '{}',
        max_stores integer DEFAULT 0,
        max_products integer,
        max_monthly_volume numeric,
        risk_level text DEFAULT 'low',
        kyc_verified_at timestamp(6),
        verification_status text DEFAULT 'pending',
        mcc text,
        tax_id_type text,
        kyc_status text DEFAULT 'pending',
        kyc_documents jsonb DEFAULT '{}',
        timezone text DEFAULT 'UTC',
        default_currency text DEFAULT 'USD',
        operating_hours jsonb DEFAULT '{}',
        risk_score integer,
        risk_profile text DEFAULT 'low',
        processing_limits jsonb DEFAULT '{}',
        reseller_id uuid,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    Repo.query!("DROP TABLE IF EXISTS \"#{schema}\".executions")

    Repo.query!("""
      CREATE TABLE IF NOT EXISTS \"#{schema}\".executions (
        id uuid PRIMARY KEY,
        pipeline_id uuid,
        subject_id uuid,
        subject_type text,
        context jsonb,
        results jsonb,
        status text,
        trigger text,
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    Repo.query!("""
      CREATE TABLE IF NOT EXISTS \"#{schema}\".underwriting_applications (
        id uuid PRIMARY KEY,
        subject_id uuid,
        subject_type text,
        status text,
        application_data jsonb,
        risk_score integer,
        submitted_at timestamp(6),
        sla_due_at timestamp(6),
        inserted_at timestamp(6),
        updated_at timestamp(6)
      )
    """)

    Repo.query!(
      "ALTER TABLE \"#{schema}\".underwriting_applications ADD COLUMN IF NOT EXISTS sla_due_at timestamp(6)"
    )

    # 2. Create Merchants (Decoy First, Target Second)
    # The current "Hack" implementation uses List.first(), which typically returns the first created record.
    decoy_merchant =
      Merchant
      |> Ash.Changeset.for_create(:create, %{
        business_name: "Decoy Merchant",
        slug: "decoy-merchant",
        subdomain: "decoy-merchant",
        status: :active
      })
      |> Ash.create!(tenant: tenant.company_schema)

    target_merchant =
      Merchant
      |> Ash.Changeset.for_create(:create, %{
        business_name: "Target Merchant",
        slug: "target-merchant",
        subdomain: "target-merchant",
        status: :active
      })
      |> Ash.create!(tenant: tenant.company_schema)

    # 3. Create User assigned to Target Merchant
    user =
      User
      |> Ash.Changeset.for_create(:register, %{
        email: "security_user_#{System.unique_integer()}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.Changeset.force_change_attribute(:tenant_id, tenant.id)
      |> Ash.Changeset.force_change_attribute(:merchant_id, target_merchant.id)
      |> Ash.create!()

    {:ok,
     tenant: tenant, user: user, target_merchant: target_merchant, decoy_merchant: decoy_merchant}
  end

  test "application is associated with the user's merchant, not the first available one", %{
    conn: conn,
    tenant: tenant,
    user: user,
    target_merchant: target_merchant,
    decoy_merchant: decoy_merchant
  } do
    # 1. Login
    {:ok, session_data} = Auth.create_user_session(user, "127.0.0.1")

    conn =
      conn
      |> Map.put(:host, "localhost")
      |> init_test_session(%{
        "tenant_id" => tenant.id,
        "_mcp_access_token" => session_data.access_token
      })
      |> put_req_cookie("_mcp_access_token", session_data.access_token)

    # 2. Mount LiveView
    {:ok, view, _html} = live(conn, "/online-application/application")

    # 2b. Switch to Form Mode
    view
    |> element("div[phx-value-mode='form']")
    |> render_click()

    IO.puts("DEBUG HTML: #{render(view)}")

    # 3. Step 1: Business Info
    view
    |> form("form[phx-submit='save']", %{
      "application" => %{
        "business_name" => "My Secure Business",
        "business_type" => "LLC",
        "ein" => "12-3456789"
      }
    })
    |> render_change()

    view |> element("button", "Next") |> render_click()

    # 4. Step 2: Contact Info
    view
    |> form("form[phx-submit='save']", %{
      "application" => %{
        "email" => user.email,
        "phone" => "555-555-5555",
        "address_line1" => "123 Secure St",
        "city" => "Testville",
        "state" => "NY",
        "zip" => "10001"
      }
    })
    |> render_change()

    view |> element("button", "Next") |> render_click()

    # 5. Step 3: Business Details
    view
    |> form("form[phx-submit='save']", %{
      "application" => %{
        "monthly_volume" => "50000",
        "average_ticket" => "150",
        "description" => "Security Testing Services"
      }
    })
    |> render_change()

    view |> element("button", "Next") |> render_click()

    # 6. Step 4: Review and Submit (Signature)
    view
    |> form("form[phx-submit='save']", %{
      "application" => %{
        "signature" => ""
      }
    })
    |> render_submit()

    # 4. Verify Application Created
    application =
      Application
      |> Ash.Query.filter(application_data["email"] == ^user.email)
      |> Ash.read_one!(tenant: tenant.company_schema)

    assert application

    # 5. SECURITY ASSERTION
    # It must equal the Target Merchant ID (assigned to User)
    # It must NOT equal the Decoy Merchant ID (which was created first)
    assert application.subject_id == target_merchant.id,
           "Security Failure: Application attached to wrong merchant! Got #{application.subject_id}, expected #{target_merchant.id}"

    assert application.subject_id != decoy_merchant.id
  end

  test "chat interaction creates an execution record for audit", %{
    conn: conn,
    tenant: tenant
  } do
    conn =
      conn
      |> Map.put(:host, "localhost")
      |> init_test_session(%{
        "tenant_id" => tenant.id
      })

    {:ok, view, _html} = live(conn, "/online-application/application")

    # Switch to Chat Mode
    view
    |> element("div[phx-value-mode='chat']")
    |> render_click()

    # Send a message
    view
    |> form("form[phx-submit='send_chat']", %{
      "message" => "Help me apply"
    })
    |> render_submit()

    # Verify Execution Created
    execution =
      Mcp.Underwriting.Execution
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read_one!(tenant: tenant.company_schema)

    assert execution
    assert execution.status == :processing
    assert execution.trigger == "ola_chat"
  end
end
