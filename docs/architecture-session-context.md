# Architecture Session Context - Portal & Multi-Tenancy Scope

**Session Date:** 2025-11-16 (Updated 2025-11-17)
**Purpose:** Full architecture workflow for AI-Powered MSP Platform with 8-portal design
**Status:** ✅ All architectural decisions finalized - Ready for implementation

---

## ARCHITECTURAL DECISIONS FINALIZED

### Decision 1: Hybrid Authentication Model ✅
**Chosen:** Option B - Direct subdomains + discovery portal (`app.base.do`)

### Decision 2: Customer/Vendor Portal Routing ✅
**Chosen:** Subdomain-based authentication
- Customer: `customer.merchant-a.base.do/signin`
- Vendor: `vendor.merchant-a.base.do/signin`

### Decision 3: Store Portal Strategy ✅
**Chosen:** Always subdomain
- Pattern: `store-a.merchant-a.base.do`

### Decision 4: Reactor Integration ✅
**Chosen:** Use Reactor for all multi-step workflow orchestration (auth, onboarding, invitations, custom domains)

### Decision 5: Custom Domain Support ✅
**Chosen:** Full white-labeling with Let's Encrypt SSL automation

---

## Critical Architectural Requirements

### 1. Complete Portal & Subdomain Architecture (FINALIZED)

#### Portal Routing Table

| Portal | Subdomain Pattern | Auth Resource | Self-Registration | Notes |
|--------|------------------|---------------|-------------------|-------|
| **Platform** | `platform.base.do` | PlatformUser | ❌ Admin-created only | Platform operations |
| **Discovery** | `app.base.do` | Universal | N/A | Shows all user contexts |
| **Tenant** | `{tenant_slug}.base.do` | TenantUser | ❌ Platform invites | Main tenant portal |
| **Developer** | `{tenant_slug}.base.do/developer` | Developer | ❌ Tenant invites (24hr) | Path-based under tenant |
| **Reseller** | `{tenant_slug}.base.do/reseller` | Reseller | ❌ Tenant creates | Path-based under tenant |
| **Merchant** | `{merchant_slug}.base.do` | MerchantUser | ❌ Tenant creates | **Merchant gets own subdomain** |
| **Customer** | `customer.{merchant_slug}.base.do` | Customer | ✅ **ONLY self-reg** | Subdomain under merchant |
| **Vendor** | `vendor.{merchant_slug}.base.do` | Vendor | ❌ Merchant creates | Subdomain under merchant |
| **Store** | `{store_slug}.{merchant_slug}.base.do` | StoreUser | ❌ Merchant assigns | Subdomain under merchant |

#### Subdomain Structure Examples

**Standard Base.do Routing:**
```
platform.base.do                           → Platform admin portal
app.base.do                                → Discovery portal (multi-context users)

acme.base.do                               → Acme Corp tenant portal
acme.base.do/developer                     → Acme developers (path-based)
acme.base.do/reseller                      → Acme resellers (path-based)

bobs-burgers.base.do                       → Bob's Burgers merchant portal
customer.bobs-burgers.base.do              → Customer portal (subdomain)
vendor.bobs-burgers.base.do                → Vendor portal (subdomain)
north-store.bobs-burgers.base.do           → North Store portal (subdomain)
south-store.bobs-burgers.base.do           → South Store portal (subdomain)
```

**Custom Domain Routing (White-Label):**
```
portal.acmecorp.com                        → Acme tenant (custom domain)
portal.acmecorp.com/developer              → Acme developers (same branding)

shop.bobsburgers.com                       → Bob's merchant (custom domain)
customer.shop.bobsburgers.com              → Customers (merchant branding)
vendor.shop.bobsburgers.com                → Vendors (merchant branding)
downtown.shop.bobsburgers.com              → Downtown store (merchant branding)
```

#### Marketplace Implications

Merchants having their own subdomains (`{merchant_slug}.base.do`) enables:
- **Merchant discovery:** Browse merchants at `marketplace.base.do`
- **Direct merchant access:** Customers bookmark `bobs-burgers.base.do`
- **Store subdomains:** Each store can be independently marketed
- **SEO benefits:** Merchant-specific domains for search indexing

---

### 2. Hybrid Authentication Architecture (FINALIZED)

#### Model: Direct Subdomains + Discovery Portal

**Core Principle:** Subdomain = Context

**Authentication Flow:**

**Scenario A: User Knows Their Context**
```
1. User visits acme.base.do/developer
2. Sees Acme branding immediately
3. Signs in (email/password + 2FA)
4. Authenticated into Acme developer context
5. Session cookie domain: .base.do
```

**Scenario B: Multi-Context User (Discovery Portal)**
```
1. User visits app.base.do
2. Generic platform branding shown
3. Signs in (email/password + 2FA)
4. System queries: "What contexts does this user belong to?"
5. Shows list:
   - Acme Corp (Developer)
   - Widget Co (Reseller)
   - Merchant-A (Admin)
6. User selects "Acme Corp (Developer)"
7. Redirects to acme.base.do/developer
8. Ash policies validate user has Developer access to Acme
9. Session established with Acme context
```

**Scenario C: Context Switching**
```
1. User authenticated at acme.base.do/developer
2. Navigation shows "Switch Organization" dropdown (if multi-context)
3. Dropdown lists: Widget Co, Merchant-A
4. User clicks "Widget Co"
5. Redirects to widgetco.base.do/reseller
6. Ash policies validate user has Reseller access to Widget Co
7. Same SSO session (shared .base.do cookie)
8. No re-authentication needed
```

#### Session & Cookie Strategy

**Session Cookie Configuration:**
```elixir
# Shared cookie across all *.base.do subdomains
cookie_options = [
  domain: ".base.do",           # Works for all subdomains
  secure: true,                  # HTTPS only
  http_only: true,               # Prevent XSS
  same_site: "Lax",              # CSRF protection
  max_age: 86400                 # 24 hours
]
```

**JWT Claims Structure:**
```elixir
%{
  user_id: "uuid",
  email: "dev@example.com",

  # Current active context
  current_context: %{
    type: :tenant,               # :platform | :tenant | :merchant
    tenant_id: "acme-uuid",
    tenant_slug: "acme",
    role: :developer             # :admin | :developer | :reseller | etc.
  },

  # All authorized contexts for this user
  authorized_contexts: [
    %{type: :tenant, id: "acme-uuid", slug: "acme", role: :developer},
    %{type: :tenant, id: "widget-uuid", slug: "widget", role: :reseller},
    %{type: :merchant, id: "merchant-a-uuid", slug: "merchant-a", role: :admin}
  ],

  # Standard claims
  iat: 1700000000,
  exp: 1700086400,
  iss: "base.do"
}
```

**Context Resolution (McpWeb.ContextPlug):**
```elixir
defmodule McpWeb.ContextPlug do
  @moduledoc """
  Resolves current context from subdomain and validates user access.
  Runs on every request to ensure context isolation.
  """

  def call(conn, _opts) do
    host = conn.host
    user = conn.assigns[:current_user]

    # Check if custom domain first
    case Mcp.CustomDomains.lookup(host) do
      {:ok, custom_domain} ->
        resolve_custom_domain_context(conn, custom_domain, user)

      :not_found ->
        resolve_standard_subdomain_context(conn, host, user)
    end
  end

  defp resolve_standard_subdomain_context(conn, host, user) do
    cond do
      host == "platform.base.do" ->
        # Platform admin context
        validate_platform_admin(conn, user)

      host == "app.base.do" ->
        # Discovery portal - no specific context
        assign(conn, :context_type, :discovery)

      String.ends_with?(host, ".base.do") ->
        # Extract subdomain parts
        parts = String.split(host, ".")

        case length(parts) do
          3 ->
            # {entity}.base.do (tenant or merchant)
            resolve_single_subdomain(conn, List.first(parts), user)

          4 ->
            # {sub}.{merchant}.base.do (customer, vendor, store)
            [sub_entity, merchant_slug | _] = parts
            resolve_nested_subdomain(conn, sub_entity, merchant_slug, user)

          _ ->
            send_resp(conn, 400, "Invalid subdomain structure")
        end

      true ->
        send_resp(conn, 400, "Unknown domain")
    end
  end

  defp resolve_single_subdomain(conn, slug, user) do
    # Could be tenant or merchant - check both
    cond do
      tenant = Mcp.Tenants.get_by_slug(slug) ->
        validate_user_tenant_access(conn, tenant, user)

      merchant = Mcp.Merchants.get_by_slug(slug) ->
        validate_user_merchant_access(conn, merchant, user)

      true ->
        send_resp(conn, 404, "Entity not found")
    end
  end

  defp resolve_nested_subdomain(conn, sub_entity, merchant_slug, user) do
    merchant = Mcp.Merchants.get_by_slug(merchant_slug)

    case sub_entity do
      "customer" ->
        assign(conn, :context, %{type: :customer, merchant: merchant})

      "vendor" ->
        validate_vendor_access(conn, merchant, user)

      _store_slug ->
        # Assume it's a store subdomain
        store = Mcp.Stores.get_by_slug(sub_entity, merchant.id)
        validate_store_access(conn, store, user)
    end
  end
end
```

#### Context Switching UI Pattern

**Navigation Component:**
```elixir
defmodule McpWeb.Components.ContextSwitcher do
  use Phoenix.Component

  def context_switcher(assigns) do
    ~H"""
    <div :if={length(@user.authorized_contexts) > 1} class="dropdown">
      <button class="btn btn-ghost">
        <%= @current_context.name %>
        <.icon name="hero-chevron-down" />
      </button>

      <ul class="dropdown-content menu">
        <%= for context <- @user.authorized_contexts do %>
          <li>
            <a href={context_url(context)} class="flex items-center gap-2">
              <.icon name={context_icon(context.type)} />
              <div>
                <div class="font-semibold"><%= context.name %></div>
                <div class="text-xs opacity-70"><%= context.role %></div>
              </div>
            </a>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp context_url(%{type: :tenant, slug: slug}), do: "https://#{slug}.base.do"
  defp context_url(%{type: :merchant, slug: slug}), do: "https://#{slug}.base.do"
end
```

---

### 3. Reactor Integration for State Orchestration (NEW)

**Technology:** [Reactor](https://hexdocs.pm/reactor/) - Dynamic, concurrent, dependency-resolving saga orchestrator

**Why Reactor:**
- ✅ **Saga pattern:** Multi-step workflows with automatic rollbacks
- ✅ **Dependency resolution:** Steps execute in correct order
- ✅ **Concurrent execution:** Parallel step execution when possible
- ✅ **Ash integration:** Native Ash.Reactor extension
- ✅ **Compensating transactions:** Automatic cleanup on failure

**Installation Required:**
```elixir
# mix.exs (add to deps if not present)
{:reactor, "~> 0.17"},
{:ash_reactor, "~> 0.1"}  # Ash.Reactor extension
```

#### Reactor Use Cases

**1. Authentication Saga (Multi-Step Sign-In)**
```elixir
defmodule Mcp.Auth.SignInReactor do
  use Reactor, extensions: [Ash.Reactor]

  input :email
  input :password
  input :subdomain  # Context from request

  # Step 1: Validate credentials
  ash do
    action :validate_credentials, Mcp.Accounts.User, :sign_in do
      inputs %{email: input(:email), password: input(:password)}
    end
  end

  # Step 2: Check 2FA requirement
  step :check_2fa do
    argument :user, result(:validate_credentials)

    run fn %{user: user}, _ ->
      if user.two_factor_enabled? do
        {:ok, :required}
      else
        {:ok, :skip}
      end
    end
  end

  # Step 3: Send 2FA code (conditional)
  step :send_2fa_code, async?: true do
    argument :user, result(:validate_credentials)
    argument :2fa_status, result(:check_2fa)

    run fn args, _ ->
      if args.:"2fa_status" == :required do
        Mcp.Communication.send_2fa_code(args.user)
      else
        {:ok, :skipped}
      end
    end
  end

  # Step 4: Load authorized contexts (parallel with 2FA)
  ash do
    action :load_contexts, Mcp.Accounts.UserContext, :list_for_user do
      inputs %{user_id: result(:validate_credentials, [:id])}
    end
  end

  # Step 5: Resolve current context from subdomain
  step :resolve_context do
    argument :contexts, result(:load_contexts)
    argument :subdomain, input(:subdomain)

    run fn args, _ ->
      # Match subdomain to user's authorized contexts
      Mcp.Auth.ContextResolver.resolve(args.subdomain, args.contexts)
    end
  end

  # Step 6: Create session token
  step :create_session do
    argument :user, result(:validate_credentials)
    argument :current_context, result(:resolve_context)
    argument :all_contexts, result(:load_contexts)

    run fn args, _ ->
      Mcp.Auth.SessionManager.create_token(
        args.user,
        args.current_context,
        args.all_contexts
      )
    end
  end
end
```

**2. Tenant Onboarding Saga**
```elixir
defmodule Mcp.Tenants.OnboardingReactor do
  use Reactor, extensions: [Ash.Reactor]

  input :tenant_params   # %{name, slug, email, etc.}
  input :gateway_ids     # Payment gateways to assign
  input :admin_user      # Platform admin creating tenant

  # Step 1: Validate slug availability
  step :validate_slug do
    argument :slug, input(:tenant_params, [:slug])

    run fn %{slug: slug}, _ ->
      if Mcp.Tenants.slug_available?(slug) do
        {:ok, slug}
      else
        {:error, "Slug already taken"}
      end
    end
  end

  # Step 2: Create tenant record
  ash do
    action :create_tenant, Mcp.Tenants.Tenant, :create do
      inputs input(:tenant_params)
      actor input(:admin_user)
    end
  end

  # Step 3: Create database schema
  step :create_schema do
    argument :tenant, result(:create_tenant)

    run fn %{tenant: tenant}, _ ->
      Mcp.MultiTenant.create_tenant_schema(tenant.slug)
    end

    # Compensate: Drop schema if later steps fail
    compensate fn %{tenant: tenant}, _ ->
      Mcp.MultiTenant.drop_tenant_schema(tenant.slug)
    end
  end

  # Step 4: Run tenant-specific migrations
  step :run_migrations do
    argument :tenant, result(:create_tenant)
    wait_for [:create_schema]

    run fn %{tenant: tenant}, _ ->
      Mcp.MultiTenant.run_tenant_migrations(tenant.slug)
    end
  end

  # Step 5: Assign payment gateways (async, parallel)
  step :assign_gateways, async?: true do
    argument :tenant, result(:create_tenant)
    argument :gateway_ids, input(:gateway_ids)

    run fn args, _ ->
      Mcp.PaymentGateways.assign_to_tenant(args.tenant.id, args.gateway_ids)
    end
  end

  # Step 6: Provision subdomain DNS (async, parallel)
  step :provision_subdomain, async?: true do
    argument :tenant, result(:create_tenant)

    run fn %{tenant: tenant}, _ ->
      Mcp.DNS.create_subdomain("#{tenant.slug}.base.do")
    end

    # Compensate: Delete DNS if tenant creation fails
    compensate fn %{tenant: tenant}, _ ->
      Mcp.DNS.delete_subdomain("#{tenant.slug}.base.do")
    end
  end

  # Step 7: Create initial admin user for tenant
  ash do
    action :create_admin, Mcp.Accounts.TenantUser, :create_initial_admin do
      inputs %{
        tenant_id: result(:create_tenant, [:id]),
        email: input(:tenant_params, [:email]),
        full_permissions: true
      }
    end
  end

  # Step 8: Send welcome email (wait for all setup)
  step :send_welcome_email do
    argument :tenant, result(:create_tenant)
    argument :admin_user, result(:create_admin)

    wait_for [:run_migrations, :assign_gateways, :provision_subdomain]

    run fn args, _ ->
      Mcp.Communication.send_tenant_welcome_email(
        args.tenant,
        args.admin_user
      )
    end
  end

  # Step 9: Log audit trail
  step :audit_log, async?: true do
    argument :tenant, result(:create_tenant)
    argument :admin, input(:admin_user)

    run fn args, _ ->
      Mcp.AuditLog.log_tenant_creation(args.tenant, args.admin)
    end
  end
end
```

**3. Merchant Onboarding with Subdomain Provisioning**
```elixir
defmodule Mcp.Merchants.OnboardingReactor do
  use Reactor, extensions: [Ash.Reactor]

  input :merchant_params  # %{name, slug, tenant_id, etc.}
  input :gateway_ids      # Which tenant gateways to enable

  # Step 1: Create merchant record
  ash do
    action :create_merchant, Mcp.Merchants.Merchant, :create do
      inputs input(:merchant_params)
    end
  end

  # Step 2: Provision merchant subdomain
  step :provision_subdomain, async?: true do
    argument :merchant, result(:create_merchant)

    run fn %{merchant: merchant}, _ ->
      Mcp.DNS.create_subdomain("#{merchant.slug}.base.do")
    end

    compensate fn %{merchant: merchant}, _ ->
      Mcp.DNS.delete_subdomain("#{merchant.slug}.base.do")
    end
  end

  # Step 3: Enable payment gateways with merchant credentials
  step :enable_gateways do
    argument :merchant, result(:create_merchant)
    argument :gateway_ids, input(:gateway_ids)

    run fn args, _ ->
      Mcp.PaymentGateways.enable_for_merchant(
        args.merchant.id,
        args.gateway_ids
      )
    end
  end

  # Step 4: Create initial merchant admin user
  ash do
    action :create_admin, Mcp.Accounts.MerchantUser, :create_initial_admin do
      inputs %{
        merchant_id: result(:create_merchant, [:id]),
        email: input(:merchant_params, [:admin_email])
      }
    end
  end
end
```

**4. Developer Invitation Saga (24-Hour Expiry)**
```elixir
defmodule Mcp.Invitations.DeveloperInviteReactor do
  use Reactor, extensions: [Ash.Reactor]

  input :tenant_id
  input :email
  input :permissions
  input :invited_by_user

  # Step 1: Check if user already exists
  step :check_existing_user do
    argument :email, input(:email)

    run fn %{email: email}, _ ->
      case Mcp.Accounts.get_user_by_email(email) do
        nil -> {:ok, :new_user}
        user -> {:ok, {:existing_user, user}}
      end
    end
  end

  # Step 2: Create invitation record
  ash do
    action :create_invitation, Mcp.Invitations.Invitation, :create do
      inputs %{
        tenant_id: input(:tenant_id),
        email: input(:email),
        role: "developer",
        permissions: input(:permissions),
        invited_by: input(:invited_by_user, [:id]),
        expires_at: {:fragment, "NOW() + INTERVAL '24 hours'"}
      }
    end
  end

  # Step 3: Generate secure invitation token
  step :generate_token do
    argument :invitation, result(:create_invitation)

    run fn %{invitation: invitation}, _ ->
      token = Mcp.Auth.TokenGenerator.generate_invitation_token(invitation.id)
      {:ok, token}
    end
  end

  # Step 4: Send invitation email
  step :send_email, async?: true do
    argument :invitation, result(:create_invitation)
    argument :token, result(:generate_token)
    argument :user_status, result(:check_existing_user)

    run fn args, _ ->
      template = case args.user_status do
        :new_user -> :developer_invite_new
        {:existing_user, _} -> :developer_invite_existing
      end

      Mcp.Communication.send_developer_invitation(
        args.invitation.email,
        args.token,
        args.invitation,
        template
      )
    end
  end

  # Step 5: Schedule expiration cleanup job (Oban)
  step :schedule_cleanup, async?: true do
    argument :invitation, result(:create_invitation)

    run fn %{invitation: invitation}, _ ->
      # Schedule Oban job to clean up expired invitation
      %{invitation_id: invitation.id}
      |> Mcp.Workers.ExpiredInvitationCleaner.new(schedule_in: {24, :hours})
      |> Oban.insert()
    end
  end
end
```

**5. Context Switching Saga**
```elixir
defmodule Mcp.Auth.ContextSwitchReactor do
  use Reactor, extensions: [Ash.Reactor]

  input :user
  input :target_context  # %{type: :tenant, id: "uuid", slug: "acme"}
  input :current_session

  # Step 1: Validate user has access to target context
  step :validate_access do
    argument :user, input(:user)
    argument :context, input(:target_context)

    run fn args, _ ->
      if Mcp.Auth.user_has_context_access?(args.user, args.context) do
        {:ok, :authorized}
      else
        {:error, :unauthorized}
      end
    end
  end

  # Step 2: Load permissions for target context
  ash do
    action :load_permissions, Mcp.Permissions.UserPermission, :for_context do
      inputs %{
        user_id: input(:user, [:id]),
        context_type: input(:target_context, [:type]),
        context_id: input(:target_context, [:id])
      }
    end
  end

  # Step 3: Invalidate old session
  step :invalidate_session do
    argument :session, input(:current_session)

    run fn %{session: session}, _ ->
      Mcp.Auth.SessionManager.invalidate(session.id)
    end
  end

  # Step 4: Create new context-bound session
  step :create_new_session do
    argument :user, input(:user)
    argument :context, input(:target_context)
    argument :permissions, result(:load_permissions)

    wait_for [:validate_access, :invalidate_session]

    run fn args, _ ->
      Mcp.Auth.SessionManager.create_token(
        args.user,
        args.context,
        args.permissions
      )
    end
  end

  # Step 5: Audit log context switch
  step :audit_log, async?: true do
    argument :user, input(:user)
    argument :from_session, input(:current_session)
    argument :to_context, input(:target_context)

    run fn args, _ ->
      Mcp.AuditLog.log_context_switch(
        args.user.id,
        args.from_session.context,
        args.to_context
      )
    end
  end
end
```

#### Reactor Execution in Phoenix Controllers

```elixir
defmodule McpWeb.TenantController do
  use McpWeb, :controller

  def create(conn, %{"tenant" => tenant_params, "gateways" => gateway_ids}) do
    # Execute tenant onboarding saga
    case Reactor.run(Mcp.Tenants.OnboardingReactor, %{
      tenant_params: tenant_params,
      gateway_ids: gateway_ids,
      admin_user: conn.assigns.current_user
    }) do
      {:ok, result} ->
        tenant = result.create_tenant

        conn
        |> put_flash(:info, "Tenant created successfully")
        |> redirect(to: ~p"/platform/tenants/#{tenant.id}")

      {:error, step, reason, context} ->
        # Reactor automatically rolled back all completed steps
        conn
        |> put_flash(:error, "Tenant creation failed at step #{step}: #{reason}")
        |> render(:new, changeset: context.changeset)
    end
  end
end
```

---

### 4. Custom Domain Support (White-Labeling) (NEW)

**Feature:** Tenants and merchants can use their own domain instead of `*.base.do` subdomains.

**Examples:**
- Tenant "Acme Corp" uses `portal.acmecorp.com` instead of `acme.base.do`
- Merchant "Bob's Burgers" uses `shop.bobsburgers.com` instead of `bobs-burgers.base.do`

#### Custom Domain Architecture

**DNS Configuration:**
```
User's Domain:     portal.acmecorp.com
DNS Record Type:   CNAME
DNS Record Value:  acme.base.do
TTL:               300 (5 minutes)

Result: portal.acmecorp.com → acme.base.do → Platform routes to Acme tenant
```

**SSL/TLS Strategy:** Let's Encrypt with Automated Provisioning

**Reactor Saga: Custom Domain Provisioning**
```elixir
defmodule Mcp.CustomDomains.ProvisionReactor do
  use Reactor, extensions: [Ash.Reactor]

  input :entity_id     # tenant_id or merchant_id
  input :entity_type   # :tenant or :merchant
  input :custom_domain # "portal.acmecorp.com"
  input :requested_by  # User requesting custom domain

  # Step 1: Validate domain format
  step :validate_domain do
    argument :domain, input(:custom_domain)

    run fn %{domain: domain}, _ ->
      cond do
        not valid_domain_format?(domain) ->
          {:error, "Invalid domain format"}

        domain_already_claimed?(domain) ->
          {:error, "Domain already in use"}

        true ->
          {:ok, domain}
      end
    end
  end

  # Step 2: Generate DNS challenge (TXT record)
  step :create_dns_challenge do
    argument :domain, result(:validate_domain)
    argument :entity_id, input(:entity_id)

    run fn args, _ ->
      challenge_value = :crypto.strong_rand_bytes(32) |> Base.encode64()

      {:ok, %{
        record_type: "TXT",
        record_name: "_acme-challenge.#{args.domain}",
        record_value: challenge_value,
        instructions: """
        Add this DNS record to verify domain ownership:

        Type:  TXT
        Name:  _acme-challenge
        Value: #{challenge_value}
        TTL:   300

        After adding the record, click 'Verify DNS'.
        """
      }}
    end
  end

  # Step 3: Wait for DNS propagation (polling with retries)
  step :verify_dns do
    argument :domain, result(:validate_domain)
    argument :challenge, result(:create_dns_challenge)

    max_retries 20

    run fn args, _ ->
      case Mcp.DNS.check_txt_record(args.domain, args.challenge.record_value) do
        :found -> {:ok, :verified}
        :not_found -> {:error, :retry}  # Reactor will retry
      end
    end
  end

  # Step 4: Provision SSL certificate (Let's Encrypt)
  step :provision_ssl do
    argument :domain, result(:validate_domain)
    argument :dns_verified, result(:verify_dns)

    run fn %{domain: domain}, _ ->
      # Use ACME protocol (Let's Encrypt)
      case Mcp.SSL.LetsEncrypt.provision_certificate(domain) do
        {:ok, cert} ->
          {:ok, %{
            cert_id: cert.id,
            cert_path: cert.path,
            key_path: cert.key_path,
            expires_at: cert.expires_at
          }}

        {:error, reason} ->
          {:error, "SSL provisioning failed: #{reason}"}
      end
    end

    # Compensate: Revoke cert if later steps fail
    compensate fn %{domain: domain}, _ ->
      Mcp.SSL.LetsEncrypt.revoke_certificate(domain)
    end
  end

  # Step 5: Create custom domain mapping
  ash do
    action :create_mapping, Mcp.CustomDomains.Domain, :create do
      inputs %{
        domain: result(:validate_domain),
        entity_id: input(:entity_id),
        entity_type: input(:entity_type),
        ssl_cert_id: result(:provision_ssl, [:cert_id]),
        dns_challenge: result(:create_dns_challenge, [:record_value]),
        verified_at: {:fragment, "NOW()"},
        created_by: input(:requested_by, [:id])
      }
    end
  end

  # Step 6: Configure load balancer / reverse proxy
  step :configure_routing, async?: true do
    argument :mapping, result(:create_mapping)
    argument :ssl_cert, result(:provision_ssl)

    run fn args, _ ->
      # Update Nginx/HAProxy/CloudFlare configuration
      Mcp.Routing.add_custom_domain_route(
        args.mapping.domain,
        args.ssl_cert,
        target_subdomain: args.mapping.entity_slug
      )
    end
  end

  # Step 7: Schedule SSL renewal job (80 days, Let's Encrypt expires in 90)
  step :schedule_renewal, async?: true do
    argument :mapping, result(:create_mapping)

    run fn %{mapping: mapping}, _ ->
      %{domain_id: mapping.id}
      |> Mcp.Workers.SSLRenewalWorker.new(schedule_in: {80, :days})
      |> Oban.insert()
    end
  end

  # Step 8: Notify user of successful setup
  step :send_confirmation, async?: true do
    argument :mapping, result(:create_mapping)
    argument :user, input(:requested_by)

    run fn args, _ ->
      Mcp.Communication.send_custom_domain_confirmation(
        args.user.email,
        args.mapping.domain
      )
    end
  end
end
```

#### Custom Domain Routing Plug

```elixir
defmodule McpWeb.CustomDomainPlug do
  @moduledoc """
  Resolves custom domains to their entity context.
  Runs before ContextPlug to handle white-labeled domains.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    host = conn.host

    # Skip if already on base.do
    if String.ends_with?(host, ".base.do") do
      conn
    else
      # Check if this is a custom domain
      case Mcp.CustomDomains.lookup(host) do
        {:ok, mapping} ->
          # Custom domain found - set entity context
          conn
          |> assign(:custom_domain, mapping)
          |> assign(:entity_type, mapping.entity_type)
          |> assign(:entity_id, mapping.entity_id)
          |> assign(:entity_slug, mapping.entity_slug)
          |> assign(:branding_override, mapping.branding)

        :not_found ->
          # Unknown domain
          conn
          |> send_resp(404, "Domain not configured")
          |> halt()
      end
    end
  end
end
```

#### Custom Domain Session Strategy

**Challenge:** Session cookies for `.base.do` don't work on `portal.acmecorp.com`

**Solution:** Federated SSO (OAuth2/OIDC)

**Flow:**
```
1. User visits portal.acmecorp.com
2. Custom domain detected → redirect to auth.base.do/oauth/authorize
3. User authenticates at auth.base.do
4. auth.base.do redirects back to portal.acmecorp.com/oauth/callback?code=...
5. portal.acmecorp.com exchanges code for token
6. Token contains entity context (Acme tenant)
7. portal.acmecorp.com sets session cookie for .acmecorp.com domain
```

**Implementation:**
```elixir
# Custom domain redirects to central auth
defmodule McpWeb.CustomDomain.AuthController do
  use McpWeb, :controller

  def sign_in(conn, _params) do
    custom_domain = conn.assigns.custom_domain

    # Build OAuth2 authorize URL
    authorize_url =
      "https://auth.base.do/oauth/authorize?" <>
      URI.encode_query(%{
        client_id: "custom_domain",
        redirect_uri: "https://#{custom_domain.domain}/oauth/callback",
        response_type: "code",
        scope: "openid profile email",
        state: generate_state_token(conn)
      })

    redirect(conn, external: authorize_url)
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    # Verify state token (CSRF protection)
    verify_state_token(conn, state)

    # Exchange code for access token
    {:ok, token} = Mcp.OAuth.exchange_code(code)

    # Decode JWT to get user info and context
    {:ok, claims} = Mcp.Auth.JWT.verify(token.access_token)

    # Set session for custom domain
    conn
    |> put_session(:access_token, token.access_token)
    |> put_session(:user_id, claims.user_id)
    |> put_session(:entity_context, claims.current_context)
    |> redirect(to: "/dashboard")
  end
end
```

#### SSL Certificate Renewal (Automated via Oban)

```elixir
defmodule Mcp.Workers.SSLRenewalWorker do
  use Oban.Worker, queue: :ssl_management

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"domain_id" => domain_id}}) do
    domain = Mcp.CustomDomains.get!(domain_id)

    # Renew certificate via Let's Encrypt
    case Mcp.SSL.LetsEncrypt.renew_certificate(domain.domain) do
      {:ok, new_cert} ->
        # Update domain mapping with new cert
        Mcp.CustomDomains.update_ssl_cert(domain, new_cert)

        # Update routing configuration
        Mcp.Routing.update_ssl_cert(domain.domain, new_cert)

        # Schedule next renewal (80 days)
        %{domain_id: domain_id}
        |> __MODULE__.new(schedule_in: {80, :days})
        |> Oban.insert()

        :ok

      {:error, reason} ->
        # Alert administrators
        Mcp.Alerts.send_ssl_renewal_failed(domain, reason)
        {:error, reason}
    end
  end
end
```

#### Custom Domain Data Model (Ash Resource)

```elixir
defmodule Mcp.CustomDomains.Domain do
  use Ash.Resource,
    domain: Mcp.CustomDomains,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "custom_domains"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :domain, :string do
      allow_nil? false
      constraints [match: ~r/^[a-z0-9.-]+\.[a-z]{2,}$/]
    end

    attribute :entity_type, :atom do
      allow_nil? false
      constraints [one_of: [:tenant, :merchant]]
    end

    attribute :entity_id, :uuid, allow_nil?: false
    attribute :entity_slug, :string, allow_nil?: false

    attribute :ssl_cert_id, :string
    attribute :dns_challenge, :string
    attribute :verified_at, :utc_datetime

    attribute :branding, :map do
      default %{}
    end

    timestamps()
  end

  actions do
    defaults [:read]

    create :create do
      accept [:domain, :entity_type, :entity_id, :entity_slug,
              :ssl_cert_id, :dns_challenge, :verified_at, :branding]
    end

    update :update_ssl_cert do
      accept [:ssl_cert_id]
    end

    read :lookup_by_domain do
      argument :domain, :string, allow_nil?: false

      filter expr(domain == ^arg(:domain) and not is_nil(verified_at))
    end
  end

  relationships do
    belongs_to :tenant, Mcp.Tenants.Tenant do
      define_attribute? false
      source_attribute :entity_id
      destination_attribute :id
    end

    belongs_to :merchant, Mcp.Merchants.Merchant do
      define_attribute? false
      source_attribute :entity_id
      destination_attribute :id
    end
  end
end
```

#### Security Considerations

**1. DNS Hijacking Prevention:**
```elixir
# Continuous DNS validation (daily check)
defmodule Mcp.Workers.DNSValidationWorker do
  use Oban.Worker, queue: :security

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Check all active custom domains
    Mcp.CustomDomains.list_active()
    |> Enum.each(fn domain ->
      case Mcp.DNS.verify_ownership(domain) do
        :valid -> :ok
        :invalid ->
          # DNS record removed or changed - disable domain
          Mcp.CustomDomains.disable(domain.id, reason: "DNS validation failed")
          Mcp.Alerts.send_dns_hijacking_alert(domain)
      end
    end)

    :ok
  end
end

# Schedule daily
Oban.insert(%{worker: Mcp.Workers.DNSValidationWorker}, schedule: "0 2 * * *")
```

**2. Subdomain Takeover Prevention:**
```elixir
# Before provisioning, verify CNAME points to correct target
defp verify_cname_target(domain, expected_target) do
  case :inet_res.lookup('#{domain}', :in, :cname) do
    [^expected_target] -> :ok
    [] -> {:error, "CNAME not configured"}
    [other] -> {:error, "CNAME points to wrong target: #{other}"}
  end
end
```

**3. SSL Expiry Monitoring:**
```elixir
# Alert 14 days before expiry
defmodule Mcp.Workers.SSLExpiryCheckWorker do
  use Oban.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    expiring_soon =
      Mcp.CustomDomains.list_ssl_expiring_within(days: 14)

    Enum.each(expiring_soon, fn domain ->
      Mcp.Alerts.send_ssl_expiry_warning(domain)
    end)
  end
end
```

---

### 5. Branding & Theming Cascade (UPDATED)

**Tenant Branding Configuration:**
```elixir
# Stored in tenant record
%Mcp.Tenants.Tenant{
  id: "uuid",
  slug: "acme",
  name: "Acme Corp",
  branding: %{
    logo_url: "https://cdn.base.do/acme/logo.png",
    primary_color: "#FF6B35",
    secondary_color: "#004E89",
    font_family: "Inter",
    daisyui_theme: "corporate",  # or custom theme name
    custom_css: "...",
    favicon_url: "https://cdn.base.do/acme/favicon.ico"
  }
}
```

**Branding Inheritance Chain:**
```
Platform (platform.base.do)
└── Base platform branding (blue/white, "Base" logo)

Tenant (acme.base.do)
└── Acme branding (orange/navy, "Acme Corp" logo)
    ├── Developer Portal (acme.base.do/developer) → Inherits Acme branding
    ├── Reseller Portal (acme.base.do/reseller) → Inherits Acme branding
    └── Merchant Portal (acme.base.do/merchant) → Inherits Acme branding

Merchant (bobs-burgers.base.do)
└── Bob's Burgers branding (red/yellow, "Bob's" logo)
    ├── Customer Portal (customer.bobs-burgers.base.do) → Inherits Bob's branding
    ├── Vendor Portal (vendor.bobs-burgers.base.do) → Inherits Bob's branding
    └── Store Portal (north-store.bobs-burgers.base.do) → Inherits Bob's branding
```

**DaisyUI Theme Loading:**
```elixir
# In root layout
defmodule McpWeb.Layouts.Root do
  use McpWeb, :html

  def theme_config(assigns) do
    branding = get_current_branding(assigns)

    ~H"""
    <html lang="en" data-theme={@branding.daisyui_theme}>
      <head>
        <link rel="icon" href={@branding.favicon_url} />

        <style>
          :root {
            --primary-color: <%= @branding.primary_color %>;
            --secondary-color: <%= @branding.secondary_color %>;
            --font-family: <%= @branding.font_family %>;
          }

          <%= raw @branding.custom_css %>
        </style>
      </head>

      <body>
        <nav class="navbar">
          <img src={@branding.logo_url} alt={@branding.name} />
        </nav>

        <%= @inner_content %>
      </body>
    </html>
    """
  end

  defp get_current_branding(assigns) do
    cond do
      assigns[:custom_domain] ->
        # Custom domain branding override
        assigns.custom_domain.branding

      assigns[:merchant] ->
        # Merchant branding
        assigns.merchant.branding

      assigns[:tenant] ->
        # Tenant branding
        assigns.tenant.branding

      true ->
        # Platform default branding
        Mcp.Branding.platform_default()
    end
  end
end
```

---

### 6. Multi-Tenant Data Architecture (REFINED)

**Cross-Tenant User Storage Strategy:**

**Problem:** Developers and Resellers can belong to multiple tenants, but we use schema-based isolation (`acq_{tenant}`)

**Solution:** Hybrid storage model

**User Storage:**
```
platform.users                     → All platform users (email, password hash, 2FA)
platform.user_contexts             → Junction table for multi-tenant access
  ├── user_id (FK to platform.users)
  ├── entity_type (:tenant, :merchant, :store)
  ├── entity_id (polymorphic)
  ├── role (:admin, :developer, :reseller, etc.)
  └── permissions (JSONB array)

acq_acme.developers               → Tenant-specific developer metadata
acq_acme.resellers                → Tenant-specific reseller metadata
acq_acme.merchants                → Merchant records in tenant schema
```

**Authorization Query Pattern:**
```elixir
# Check if user can access Acme tenant as developer
defmodule Mcp.Auth.ContextAuthorizer do
  def authorize_context(user_id, context) do
    query = """
    SELECT uc.*
    FROM platform.user_contexts uc
    WHERE uc.user_id = $1
      AND uc.entity_type = $2
      AND uc.entity_id = $3
    """

    case Repo.query(query, [user_id, context.type, context.id]) do
      {:ok, %{rows: [row]}} -> {:ok, :authorized}
      {:ok, %{rows: []}} -> {:error, :unauthorized}
    end
  end
end
```

---

### 7. Technology Stack (UPDATED)

**Existing Dependencies (from mix.exs):**
- ✅ Phoenix 1.8.1
- ✅ Ash Framework 3.0 with 15+ extensions
- ✅ PostgreSQL with TimescaleDB, PostGIS, pgvector, Apache AGE
- ✅ Redis, MinIO, Vault, Oban

**NEW Dependencies to Add:**
```elixir
# mix.exs - Add to deps()
{:reactor, "~> 0.17"},              # Saga orchestration
{:ash_reactor, "~> 0.1"},            # Ash integration for Reactor
{:site_encrypt, "~> 0.6"},           # Let's Encrypt integration (optional)
{:certbot_elixir, "~> 0.1"}          # Alternative SSL automation
```

**Infrastructure Additions:**
- **DNS Management:** CloudFlare API or Route53 for automated subdomain provisioning
- **SSL Management:** Let's Encrypt ACME protocol
- **Load Balancer:** Nginx or HAProxy with dynamic SSL cert loading

---

### 8. Authorization - Teams & Permissions (ENHANCED)

**Ash Policies with Multi-Context Support:**

```elixir
defmodule Mcp.Merchants.Merchant do
  use Ash.Resource,
    domain: Mcp.Merchants,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  policies do
    # Platform admins can do anything
    policy action_type(:*) do
      authorize_if actor_attribute_equals(:role, :platform_admin)
    end

    # Tenant admins can manage their tenant's merchants
    policy action_type([:read, :update]) do
      authorize_if relates_to_actor_via(:tenant, :tenant_users)
    end

    # Merchant admins can manage their own merchant
    policy action_type([:read, :update]) do
      authorize_if expr(id == ^actor(:merchant_id))
    end

    # Resellers can READ merchants in their portfolio (payment data only)
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :reseller)

      # But filter to show only payment-related fields
      field_policies do
        field_policy :* do
          forbid_if always()
        end

        field_policy [:id, :name, :slug, :mids, :payment_volume] do
          authorize_if always()
        end
      end
    end

    # Developers have API access based on their assigned scope
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant, :developers)

      # Scope to merchants within their permissions
      authorize_if expr(
        id in ^actor(:permitted_merchant_ids)
      )
    end
  end
end
```

**Team-Based Permissions:**
```elixir
defmodule Mcp.Teams.Team do
  use Ash.Resource,
    domain: Mcp.Teams,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :permissions, {:array, :atom} do
      constraints items: [one_of: [:read, :write, :archive, :create_users, :create_teams, :manage_members]]
    end
  end

  relationships do
    belongs_to :tenant, Mcp.Tenants.Tenant

    many_to_many :users, Mcp.Accounts.User do
      through Mcp.Teams.TeamMembership
    end

    many_to_many :scoped_merchants, Mcp.Merchants.Merchant do
      through Mcp.Teams.TeamScope
    end
  end
end
```

---

## Architecture Session Goals (UPDATED)

**Primary Deliverables:**
1. ✅ **Portal Routing Architecture** - 8 portals with subdomain strategy finalized
2. ✅ **Hybrid Authentication Model** - Direct subdomains + app.base.do discovery
3. ✅ **Reactor Integration** - Sagas for auth, onboarding, invitations, custom domains
4. ✅ **Custom Domain Support** - White-labeling with Let's Encrypt SSL
5. ⏳ **Ash Resource Structure** - 7-level hierarchy + 8 auth resources (to be designed)
6. ⏳ **Authorization Design** - Ash policies for teams/permissions/scopes (to be designed)
7. ⏳ **Cross-Tenant User Management** - platform.users + user_contexts table (to be designed)
8. ⏳ **Complete Architecture Document** - Ready for implementation

**Secondary Considerations:**
- ✅ Context switching UI patterns
- ✅ Branding/theming cascade with DaisyUI
- ✅ SSL certificate automation
- ✅ DNS validation and security
- ⏳ Payment gateway cascade data model
- ⏳ API design (GraphQL vs REST per portal)

---

## Key Documents for Architecture Session

**Requirements:**
- `/Users/rp/Developer/Base/mcp/docs/domain-brief.md` - Core functional requirements
- `/Users/rp/Developer/Base/mcp/docs/agent-handoff-continue-prd.md` - Strategic vision
- `/Users/rp/Developer/Base/mcp/docs/architecture-session-context.md` - **This document (COMPLETE)**

**Existing Implementation:**
- `/Users/rp/Developer/Base/mcp/lib/mcp/multi_tenant.ex` - Multi-tenancy foundation
- `/Users/rp/Developer/Base/mcp/mix.exs` - Complete dependency list
- `/Users/rp/Developer/Base/mcp/lib/mcp/` - Domain structure

**Configuration:**
- `/Users/rp/Developer/Base/mcp/.bmad/bmm/config.yaml` - Project metadata
- `/Users/rp/Developer/Base/mcp/.env` - Infrastructure config

---

## Remaining Architecture Decisions

**To be designed in architecture workflow:**

1. **Ash Resource Hierarchy:**
   - Platform/Tenant/Developer/Reseller/Merchant/Store/Customer/Vendor resources
   - Relationships and belongs_to associations
   - Polymorphic associations for shared entities

2. **Payment Gateway Cascade:**
   - PlatformGateway, TenantGateway, MerchantGateway, MID resources
   - Gateway configuration inheritance model
   - MID routing rules data structure

3. **API Design:**
   - GraphQL vs REST per portal type
   - API key management for developers
   - Rate limiting strategy

4. **Data Models:**
   - Complete ERD for all resources
   - Migration strategy
   - Indexing and performance optimization

---

## Ready for Architecture Workflow

**Status:** ✅ **All foundational decisions finalized**

**Next Step:** Run `/bmad:bmm:workflows:architecture` with this complete context to design:
- Ash resource structure
- Database schema (ERD)
- API contracts
- Implementation patterns for AI agents

---

**Document Version:** 2.0 - All Decisions Finalized
**Last Updated:** 2025-11-17
