defmodule Mcp.Seeder do
  @moduledoc """
  Handles seeding of the database with realistic development data.
  """

  require Ash.Query
  alias Mcp.Accounts.User
  alias Mcp.Platform.{Tenant, Merchant, Store}
  alias Mcp.Platform.TenantUserManager
  alias Mcp.Underwriting.AgentBlueprint

  @password "Password123!"

  def run do
    IO.puts("🌱 Starting Seeding...")

    # 1. Create Platform Admin
    _admin = ensure_user("admin@platform.local", @password)
    IO.puts("  - Platform Admin: admin@platform.local / #{@password}")

    # 2. Create Tenants
    seed_tenant("Acme Corp", "acme", "acme")
    seed_tenant("Globex Corp", "globex", "globex")

    # 3. Create Agent Blueprints
    seed_agent_blueprints()

    IO.puts("✅ Seeding Complete!")
  end

  defp seed_tenant(name, slug, subdomain) do
    tenant = ensure_tenant(name, slug, subdomain)

    # Create Tenant Admin
    admin_email = "admin@#{slug}.local"
    user = ensure_user(admin_email, @password)
    ensure_tenant_user(tenant, user, :owner)
    IO.puts("  - Tenant Admin (#{name}): #{admin_email} / #{@password}")

    # Create Merchants & Stores
    case slug do
      "acme" ->
        m1 = ensure_merchant(tenant, "Acme Retail", "acme-retail")
        ensure_store(tenant, m1, "Acme Downtown", "downtown")
        ensure_store(tenant, m1, "Acme Mall", "mall")

        m2 = ensure_merchant(tenant, "Acme Online", "acme-online")
        ensure_store(tenant, m2, "Acme Web Store", "web")

      "globex" ->
        m1 = ensure_merchant(tenant, "Globex Supplies", "globex-supplies")
        ensure_store(tenant, m1, "Globex HQ", "hq")

      _ ->
        :ok
    end
  end

  defp ensure_user(email, password) do
    case User.by_email(email) do
      {:ok, user} ->
        # Reset password to ensure it matches
        hashed = Bcrypt.hash_pwd_salt(password)
        
        user
        |> Ash.Changeset.for_update(:update)
        |> Ash.Changeset.force_change_attribute(:hashed_password, hashed)
        |> Ash.update!()

      {:error, _} ->
        User.register!(email, password, password)
    end
  end

  defp ensure_tenant(name, slug, subdomain) do
    tenant =
      case Tenant.by_subdomain(subdomain) do
        {:ok, tenant} ->
          features = tenant.features || %{}
          if features["underwriting"] != true do
            IO.puts("  - Enabling underwriting for #{name}...")
            Mcp.Platform.Tenant.update!(tenant, %{features: Map.put(features, "underwriting", true)})
          else
            tenant
          end

        {:error, _} ->
          Tenant.create!(%{
            name: name,
            slug: slug,
            subdomain: subdomain,
            plan: :enterprise,
            features: %{"underwriting" => true}
          })
      end

    IO.puts("  - Running migrations for #{tenant.company_schema}...")

    Ecto.Migrator.run(Mcp.Repo, "priv/repo/tenant_migrations", :up,
      all: true,
      prefix: tenant.company_schema
    )

    populate_tenant_permissions(tenant)

    tenant
  end

  defp populate_tenant_permissions(tenant) do
    IO.puts("  - Populating permissions for #{tenant.company_schema}...")

    permissions = [
      # Admin permissions
      {"admin", "all", "special", "Full administrative access to all system features", true, true, 5},

      # Customer management
      {"admin", "view_customers", "customers", "View customer information and details", true, true, 3},
      {"admin", "create_customers", "customers", "Create new customer accounts", true, false, 4},
      {"admin", "update_customers", "customers", "Update customer information", true, false, 4},
      {"admin", "delete_customers", "customers", "Delete customer accounts", true, false, 5},
      {"admin", "manage_customer_status", "customers", "Activate/deactivate customer accounts", true, false, 4},

      # Billing permissions
      {"admin", "view_billing", "billing", "View billing information and reports", true, true, 3},
      {"admin", "manage_invoices", "billing", "Create and manage invoices", true, false, 4},
      {"admin", "manage_payments", "billing", "Process payments and refunds", true, false, 5},
      {"admin", "tenant_billing", "special", "Manage tenant billing and subscriptions", true, false, 5},

      # User management
      {"admin", "view_users", "users", "View user accounts and permissions", true, true, 3},
      {"admin", "create_users", "users", "Invite and create new user accounts", true, false, 4},
      {"admin", "update_users", "users", "Update user information and roles", true, false, 4},
      {"admin", "delete_users", "users", "Delete or deactivate user accounts", true, false, 5},
      {"admin", "manage_user_roles", "users", "Assign and manage user roles and permissions", true, false, 5},

      # System permissions
      {"admin", "view_system_settings", "system", "View system configuration and settings", true, true, 4},
      {"admin", "manage_system_settings", "system", "Modify system configuration and settings", true, false, 5},

      # Billing admin permissions
      {"billing_admin", "view_customers", "customers", "View customer information for billing purposes", true, true, 3},
      {"billing_admin", "view_customer_details", "customers", "View detailed customer information", true, false, 3},
      {"billing_admin", "view_billing", "billing", "View billing information and reports", true, true, 3},
      {"billing_admin", "manage_invoices", "billing", "Create and manage invoices", true, false, 4},
      {"billing_admin", "manage_payments", "billing", "Process payments and refunds", true, false, 4},
      {"billing_admin", "view_payment_history", "billing", "View payment history and transactions", true, false, 3},
      {"billing_admin", "manage_billing_settings", "billing", "Configure billing system settings", true, false, 4},
      {"billing_admin", "export_billing_data", "billing", "Export billing data and reports", true, false, 3},

      # Support admin permissions
      {"support_admin", "view_customers", "customers", "View customer information for support purposes", true, true, 3},
      {"support_admin", "view_customer_details", "customers", "View detailed customer information", true, false, 3},
      {"support_admin", "view_support_tickets", "support", "View support tickets and requests", true, true, 3},
      {"support_admin", "create_support_tickets", "support", "Create support tickets on behalf of customers", true, false, 3},
      {"support_admin", "update_support_tickets", "support", "Update and manage support tickets", true, false, 4},
      {"support_admin", "close_tickets", "support", "Close resolved support tickets", true, false, 3},
      {"support_admin", "assign_tickets", "support", "Assign tickets to support agents", true, false, 4},
      {"support_admin", "view_support_reports", "support", "View support analytics and reports", true, false, 3},

      # Operator permissions
      {"operator", "view_customers", "customers", "View customer information", true, true, 3},
      {"operator", "view_customer_details", "customers", "View detailed customer information", true, false, 3},
      {"operator", "view_services", "services", "View service information and status", true, true, 3},
      {"operator", "activate_services", "services", "Activate customer services", true, false, 4},
      {"operator", "deactivate_services", "services", "Deactivate customer services", true, false, 4},
      {"operator", "view_service_usage", "services", "View service usage statistics", true, false, 3},
      {"operator", "view_billing", "billing", "View basic billing information", true, false, 2},
      {"operator", "view_support_tickets", "support", "View support tickets", true, false, 3},
      {"operator", "create_support_tickets", "support", "Create support tickets", true, false, 3},
      {"operator", "update_support_tickets", "support", "Update support tickets", true, false, 3},

      # Viewer permissions
      {"viewer", "view_customers", "customers", "View customer information", true, true, 1},
      {"viewer", "view_customer_details", "customers", "View detailed customer information", true, false, 2},
      {"viewer", "view_services", "services", "View service information", true, false, 1},
      {"viewer", "view_service_usage", "services", "View service usage statistics", true, false, 1},
      {"viewer", "view_billing", "billing", "View billing information", true, false, 1},
      {"viewer", "view_support_tickets", "support", "View support tickets", true, false, 1},
      {"viewer", "view_reports", "reports", "View reports and analytics", true, false, 1}
    ]

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries = Enum.map(permissions, fn {role, permission, category, description, is_granted, is_required, level} ->
      %{
        id: Ecto.UUID.dump!(Ecto.UUID.generate()),
        role: role,
        permission: permission,
        category: category,
        description: description,
        is_granted: is_granted,
        is_required: is_required,
        level: level,
        inserted_at: now,
        updated_at: now
      }
    end)

    Mcp.Repo.insert_all("role_permissions", entries,
      prefix: tenant.company_schema,
      on_conflict: :nothing,
      conflict_target: [:role, :permission]
    )
  end

  defp ensure_tenant_user(tenant, user, role) do
    # Check if already linked
    users = TenantUserManager.get_tenant_users(tenant.id) |> elem(1)

    unless Enum.any?(users, fn u -> u["user_id"] == user.id end) do
      # Simulate adding user to tenant settings
      current_settings = tenant.settings || %{}
      current_users = Map.get(current_settings, "users", [])

      new_user_entry = %{
        "user_id" => user.id,
        "email" => user.email,
        "role" => to_string(role),
        "joined_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      updated_users = [new_user_entry | current_users]
      updated_settings = Map.put(current_settings, "users", updated_users)

      Tenant.update!(tenant, %{settings: updated_settings})
    end
  end

  defp ensure_merchant(tenant, name, slug) do
    require Ash.Query

    exists =
      Merchant
      |> Ash.Query.filter(slug == ^slug)
      |> Ash.Query.set_tenant(tenant.company_schema)
      |> Ash.read_one()

    IO.inspect(exists, label: "Merchant Search Result (#{slug})")

    case exists do
      {:ok, nil} ->
        IO.puts("Merchant search returned {:ok, nil}, creating...")
        create_merchant(tenant, name, slug)

      {:ok, merchant} ->
        IO.inspect(merchant, label: "Found Merchant")
        merchant

      {:error, _} ->
        IO.puts("Merchant not found (error), creating...")
        create_merchant(tenant, name, slug)

      nil ->
        IO.puts("Merchant search returned nil, creating...")
        create_merchant(tenant, name, slug)
    end
  end

  defp create_merchant(tenant, name, slug) do
    Merchant.create!(
      %{
        business_name: name,
        slug: slug,
        subdomain: "#{slug}-#{tenant.slug}",
        status: :active
      },
      tenant: tenant.company_schema
    )
  end

  defp ensure_store(tenant, merchant, name, slug) do
    require Ash.Query

    exists =
      Store
      |> Ash.Query.filter(slug == ^slug and merchant_id == ^merchant.id)
      |> Ash.Query.set_tenant(tenant.company_schema)
      |> Ash.read_one()

    case exists do
      {:ok, store} -> store
      {:error, _} -> create_store(tenant, merchant, name, slug)
      nil -> create_store(tenant, merchant, name, slug)
    end
  end

  defp create_store(tenant, merchant, name, slug) do
    Store.create!(
      %{
        name: name,
        slug: slug,
        merchant_id: merchant.id,
        status: :active
      },
      tenant: tenant.company_schema
    )
  end


  defp seed_agent_blueprints do
    IO.puts("  - Seeding Agent Blueprints...")

    agents = [
      %{
        name: "MerchantUnderwriter",
        description: "The core decision maker for merchant applications.",
        base_prompt: "You are a senior commercial underwriter. Your goal is to assess the legitimacy and creditworthiness of a business. Analyze the provided application data, financial statements, and risk signals to make a funding decision.",
        tools: [:verify_ein, :check_ofac, :google_search, :analyze_cash_flow]
      },
      %{
        name: "The Eye",
        description: "The document extraction & analysis specialist.",
        base_prompt: "You are The Eye, an advanced OCR and document analysis engine. Your goal is to extract structured data from financial documents (PDFs, images) with 100% accuracy. Identify document types, extract key fields, and flag any signs of tampering.",
        tools: [:ocr_document, :extract_key_values, :detect_tampering]
      },
      %{
        name: "FraudDetective",
        description: "The risk anomaly hunter.",
        base_prompt: "You are a forensic investigator specializing in fraud detection. Analyze the application context for inconsistencies, synthetic identity patterns, and network anomalies. Look for mismatched data, high-risk IP addresses, and known fraud patterns.",
        tools: [:reverse_image_search, :check_ip_reputation, :analyze_behavioral_biometrics]
      },
      %{
        name: "AgentArchitect",
        description: "The expert system for designing other AI agents.",
        base_prompt: "You are the Agent Architect, an expert AI systems designer specializing in the MCP platform. Your goal is to help users design and configure new AI agents.
        
        You have deep knowledge of the following resources:
        1. AgentBlueprint: Defines the persona (name, base_prompt, tools, routing_config).
        2. InstructionSet: Defines specific policies (instructions).
        
        When a user asks for a new agent:
        1. Interview them to understand the role and requirements.
        2. Suggest a persona (Name, Base Prompt).
        3. Suggest necessary tools.
        4. Suggest a routing configuration (Ollama vs OpenRouter) based on complexity.
        5. Output the configuration in JSON format or Elixir seed format.",
        tools: [],
        routing_config: %{mode: :single, primary_provider: :openrouter} # Use the smartest model for architecture
      },
      %{
        name: "ResponseReviewer",
        description: "The guardrails agent that reviews all outputs.",
        base_prompt: "You are a Response Reviewer and Compliance Officer.
        Your goal is to review the output of other AI agents before it is sent to the user.
        
        Check for:
        1. PII (Personally Identifiable Information) that should be redacted.
        2. Professional tone.
        3. Accuracy and relevance to the original request.
        4. Safety and policy compliance.
        
        If the response is safe and good, return it as is (or slightly polished).
        If the response contains PII, redact it (replace with [REDACTED]).
        If the response is unsafe or hallucinates, rewrite it to be safe.",
        tools: [],
        routing_config: %{mode: :single, primary_provider: :ollama} # Fast local review is usually sufficient
      },
      %{
        name: "MortgageUnderwriter",
        description: "Specialist in residential mortgage underwriting.",
        base_prompt: "You are a Mortgage Underwriter. Your goal is to assess borrower risk for residential property loans.
        
        Focus on:
        1. Debt-to-Income (DTI) Ratio (Front-end and Back-end).
        2. Loan-to-Value (LTV) Ratio.
        3. Credit History and Derogatory Marks.
        4. Employment Stability (2-year history).
        5. Source of Funds for Down Payment.
        
        Analyze the provided application and credit report data to recommend approval or denial.",
        tools: [:calculator, :verify_employment],
        routing_config: %{mode: :fallback, primary_provider: :ollama, fallback_provider: :openrouter, min_confidence: 0.9}
      },
      %{
        name: "AutoLoanUnderwriter",
        description: "Specialist in vehicle financing and risk.",
        base_prompt: "You are an Auto Loan Underwriter. Your goal is to assess risk for vehicle financing.
        
        Focus on:
        1. Payment-to-Income (PTI) Ratio.
        2. Loan-to-Value (LTV) based on vehicle book value.
        3. Credit Score and Auto-specific credit history (past repos).
        4. Employment verification.
        
        Ensure the loan terms match the vehicle depreciation curve.",
        tools: [:vehicle_valuation, :verify_income],
        routing_config: %{mode: :single, primary_provider: :ollama}
      },
      %{
        name: "RentalScreener",
        description: "Specialist in tenant screening for residential leases.",
        base_prompt: "You are a Rental Screening Agent. Your goal is to assess a tenant's eligibility for a lease.
        
        Focus on:
        1. Rent-to-Income Ratio (Standard: 30%).
        2. Eviction History.
        3. Criminal Background (relevant to property safety).
        4. Landlord References.
        
        Provide a 'Pass', 'Conditional', or 'Fail' recommendation.",
        tools: [:background_check, :verify_income],
        routing_config: %{mode: :single, primary_provider: :ollama}
      }
    ]

    Enum.each(agents, fn agent_attrs ->
      case Ash.Query.filter(AgentBlueprint, name == ^agent_attrs.name) |> Ash.read_one() do
        {:ok, nil} ->
          Ash.create!(AgentBlueprint, agent_attrs)
          IO.puts("    + Created #{agent_attrs.name}")
        {:ok, _existing} ->
          IO.puts("    . #{agent_attrs.name} already exists")
        _ ->
          IO.puts("    ! Failed to check #{agent_attrs.name}")
      end
    end)
  end
end
