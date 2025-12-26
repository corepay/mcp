# Base MCP - Epic Breakdown

**Author:** BMad
**Date:** 2025-11-17
**Project Level:** Phase 1 - Foundation
**Target Scale:** Multi-tenant MSP Platform

---

## Overview

This document provides the complete epic and story breakdown for Base MCP Phase 1, decomposing the requirements from the Architecture document into implementable stories.

**Living Document Notice:** This is the Phase 1 version focused on foundational infrastructure: authentication, multi-tenancy, teams, and permissions. Future phases will add business features (payment processing, AI underwriting, etc.).

---

## Functional Requirements Inventory

### Core Platform Infrastructure
- **FR1**: PostgreSQL 17+ with extensions (TimescaleDB, PostGIS, pgvector, Apache AGE) configured and operational
- **FR2**: Schema organization (platform, shared, acq_{tenant}) with proper search path management
- **FR3**: All lookup tables populated (entity_types, status_types, address_types, email_types, phone_types, social_platforms, image_types, document_types, plan_types)
- **FR4**: Infrastructure services operational (Redis, MinIO, Vault, Meilisearch, Oban)
- **FR5**: OTP supervision tree complete (Infrastructure, Domains, Services, Jobs, Platform, Web supervisors)
- **FR6**: Docker Compose environment for all infrastructure services

### User Authentication & Security
- **FR7**: Users can register with email + password (bcrypt cost factor 12, min 8 chars, mixed types)
- **FR8**: Users can authenticate with email + password (rate limited: 5 attempts/15 min, lockout after 5 failures)
- **FR9**: Users can enable/use TOTP 2FA (optional per user, enforceable per entity)
- **FR10**: Users can authenticate via OAuth (Google and GitHub only)
- **FR11**: Platform enforces password change on first login (seed admin)
- **FR12**: Users are soft deleted (status: deleted, 90-day GDPR retention)
- **FR13**: Sessions use JWT with current_context + authorized_contexts
- **FR14**: Session cookies scoped to .base.do domain

### Multi-Tenancy
- **FR15**: Platform admins can create tenants (name, slug validation, uniqueness)
- **FR16**: System automatically creates tenant schema (acq_{tenant}) via OnboardingReactor saga
- **FR17**: System runs tenant-specific migrations automatically
- **FR18**: System provisions tenant subdomain ({tenant}.base.do) via CloudFlare API or stub
- **FR19**: System manages search path (acq_{tenant}, platform, shared, public)
- **FR20**: Tenant creation creates initial admin user

### Entity-Scoped User Profiles
- **FR21**: Users have separate profiles per entity (user_id + entity_type + entity_id unique)
- **FR22**: Each profile has independent identity (first_name, last_name, nickname, avatar_url, bio, title, contact_email, phone, timezone, preferences)
- **FR23**: Each profile has role flags (is_admin, is_developer)
- **FR24**: Each profile has status (active, suspended, invited, pending)
- **FR25**: JWT session contains current profile data
- **FR26**: Users can switch between their authorized contexts (context switching with session rotation)

### All Entity Types (8 Types)
- **FR27**: Platform admins exist (implicit, manage platform.users)
- **FR28**: Tenants exist (platform.tenants) with branding, settings, payment gateway assignments
- **FR29**: Developers exist (acq_{tenant}.developers) with tenant association, can belong to multiple tenants
- **FR30**: Resellers exist (acq_{tenant}.resellers) with portfolio, can belong to multiple tenants
- **FR31**: Merchants exist (acq_{tenant}.merchants) with own subdomain ({merchant}.base.do), single tenant only
- **FR32**: Stores exist (acq_{tenant}.stores) with merchant association, path-based or subdomain routing
- **FR33**: Customers exist (acq_{tenant}.customers) with merchant association, can self-register IF merchant enables customer_self_registration (default: invitation-only)
- **FR34**: Vendors exist (acq_{tenant}.vendors) with merchant association, can self-register IF merchant enables vendor_self_registration (default: invitation-only)

### Teams, Permissions & Authorization
- **FR35**: Admins can create teams with feature-based permissions (read, write, archive, create_users, create_teams, manage_members)
- **FR36**: Admins can assign teams to entity scopes (own entity + all child entities)
- **FR37**: Admins can add/remove team members
- **FR38**: System enforces hierarchical permission inheritance (entity admin inherits permissions over direct children)
- **FR39**: Ash policies enforce authorization at resource level
- **FR40**: Row-Level Security (RLS) policies enforce database-level access control
- **FR41**: Field-level policies restrict data visibility (e.g., resellers see only payment data, not PII)

### User Invitations
- **FR42**: Admins can invite users via email with role and permissions
- **FR43**: System generates secure invitation tokens via DeveloperInviteReactor saga
- **FR44**: Invitations expire after 24 hours
- **FR45**: Users can accept invitations and create profiles
- **FR46**: Admins can revoke pending invitations
- **FR47**: Admins can refresh expired invitations
- **FR48**: System cleans up expired invitations via Oban job
- **FR49**: System sends appropriate email templates (new user vs existing user)

### Portal Routing & Context Resolution
- **FR50**: System routes platform.base.do to Platform admin portal
- **FR51**: System routes app.base.do to Discovery portal (context switcher)
- **FR52**: System routes {tenant}.base.do to Tenant portal
- **FR53**: System routes {tenant}.base.do/developers to Developer portal (path-based)
- **FR54**: System routes {tenant}.base.do/resellers to Reseller portal (path-based)
- **FR55**: System routes {merchant}.base.do to Merchant portal (subdomain)
- **FR56**: System routes customer.{merchant}.base.do to Customer portal
- **FR57**: System routes vendor.{merchant}.base.do to Vendor portal
- **FR58**: System routes {store}.{merchant}.base.do to Store portal
- **FR59**: McpWeb.ContextPlug resolves entity from subdomain
- **FR60**: System shows appropriate branding per context (DaisyUI theme cascade)

### Polymorphic Shared Entities with RLS
- **FR61**: Users/entities can create addresses (platform.addresses) with PostGIS geocoding
- **FR62**: Users/entities can create emails (platform.emails) with type classification
- **FR63**: Users/entities can create phones (platform.phones) with type classification
- **FR64**: Users/entities can create social links (platform.socials)
- **FR65**: Users/entities can upload images (platform.images) with S3/MinIO storage
- **FR66**: Users/entities can upload documents (platform.documents) with encrypted S3/MinIO storage
- **FR67**: Users/entities can create todos (platform.todos)
- **FR68**: Users/entities can create notes (platform.notes) with full-text search
- **FR69**: All shared entities use polymorphic associations (owner_type FK to entity_types, owner_id)
- **FR70**: RLS policies enforce access control (users see own + entities they belong to)

### API Keys & Developer Access
- **FR71**: Admins can create API keys (admin-only or team permission: create_api_keys)
- **FR72**: System supports three-tier API key model (developer, merchant, reseller)
- **FR73**: Developer keys are tenant-scoped with tenant-defined permissions
- **FR74**: Merchant keys are auto-scoped to own merchant only (self-service)
- **FR75**: Reseller keys are auto-scoped to own reseller + assigned merchants
- **FR76**: API keys have type-specific prefixes (dev_ak_, merch_ak_, res_ak_)
- **FR77**: API keys expire after 90 days with rotation capability
- **FR78**: Non-admin developers can rotate their assigned keys (admin notified)
- **FR79**: System uses header-based API versioning (API-Version: YYYY-MM-DD, not path-based /v1/)

### Custom Domains & SSL Management
- **FR80**: Tenants/merchants can add custom domains (portal.tenantbrand.com, shop.merchantbrand.com)
- **FR81**: System validates domain format and uniqueness
- **FR82**: System generates DNS challenge (TXT record) for verification
- **FR83**: System polls DNS for verification via ProvisionReactor saga
- **FR84**: System provisions SSL certificate via Let's Encrypt (ACME protocol)
- **FR85**: System configures routing (Nginx/HAProxy/CloudFlare) for custom domain
- **FR86**: System schedules SSL renewal (80 days) via Oban
- **FR87**: System performs daily DNS validation to prevent hijacking
- **FR88**: McpWeb.CustomDomainPlug resolves custom domains to entity context
- **FR89**: Custom domains support federated SSO (OAuth2/OIDC) for session management

### Minimal Portal UIs
- **FR90**: Users see login page with email/password and OAuth buttons
- **FR91**: Users see 2FA setup/verification page
- **FR92**: Customers/vendors see registration page (self-registration)
- **FR93**: Users see forced password change page (seed admin)
- **FR94**: Multi-context users see context switcher at app.base.do (list all contexts with icons/roles)
- **FR95**: Users see simple dashboard per portal showing context and profile
- **FR96**: Users see navigation with context switch dropdown (if multi-context)
- **FR97**: Admins see team management UI (create team, add members, assign scopes, set permissions)
- **FR98**: Admins see invitation UI (send invitation, view pending, revoke/refresh)
- **FR99**: Users see profile per context (different name/avatar/title per entity)
- **FR100**: System applies branding cascade (DaisyUI theme, logo, colors per entity)

### Seed Data & Testing
- **FR101**: System seeds all lookup tables with complete data (30+ entity types, all status/address/email/phone/social/image/document types)
- **FR102**: System seeds platform admin (admin@platform.local, password_change_required: true)
- **FR103**: System seeds sample tenant "Acme Payment Solutions"
- **FR104**: System seeds sample merchant "Bob's Burgers" with subdomain
- **FR105**: System seeds sample developer, reseller, store, customer, vendor
- **FR106**: System seeds sample teams with various permissions and scopes
- **FR107**: System seeds sample pending invitations
- **FR108**: All authentication flows have test coverage (email/password, 2FA, OAuth)
- **FR109**: All multi-tenant operations have test coverage (schema isolation, search path)
- **FR110**: All Reactor sagas have test coverage (OnboardingReactor, DeveloperInviteReactor, ContextSwitchReactor, ProvisionReactor)
- **FR111**: All authorization policies have test coverage (Ash policies, RLS policies, field-level policies)
- **FR112**: All portal routing has test coverage (8 portals, custom domains, context resolution)

---

**Total: 112 Functional Requirements for Phase 1**

---

## Epic Summary

**Phase 1 contains 11 epics delivering foundational infrastructure:**

1. **Epic 1: Foundation & Infrastructure Setup** - Core infrastructure and development environment (7 FRs)
2. **Epic 2: User Authentication & Session Management** - Secure authentication with multiple methods (12 FRs)
3. **Epic 3: Multi-Tenancy & Schema Management** - Isolated tenants with automatic provisioning (8 FRs)
4. **Epic 4: Entity-Scoped User Profiles & Context Switching** - Different identities across entities (10 FRs)
5. **Epic 5: All Entity Types & Hierarchical Structure** - Complete 8-entity hierarchy (10 FRs)
6. **Epic 6: Teams, Permissions & Authorization** - Fine-grained access control (9 FRs)
7. **Epic 7: User Invitations & Onboarding** - Email-based user invitations (10 FRs)
8. **Epic 8: Portal Routing & Context Resolution** - 8 branded portals with routing (12 FRs)
9. **Epic 9: Polymorphic Shared Entities with RLS** - Reusable entities with privacy (10 FRs)
10. **Epic 10: API Keys & Developer Portal Access** - Three-tier API authentication (9 FRs)
11. **Epic 11: Custom Domains & SSL Management** - White-label domains with SSL (10 FRs)

---

## FR Coverage Map

| Epic | FRs Covered | Count |
|------|-------------|-------|
| **Epic 1: Foundation** | FR1-FR6, FR101 | 7 |
| **Epic 2: Authentication** | FR7-FR14, FR90-FR93 | 12 |
| **Epic 3: Multi-Tenancy** | FR15-FR20, FR102-FR103 | 8 |
| **Epic 4: User Profiles** | FR21-FR26, FR94-FR96, FR99 | 10 |
| **Epic 5: Entity Types** | FR27-FR34, FR104-FR105 | 10 |
| **Epic 6: Teams & Permissions** | FR35-FR41, FR97, FR106 | 9 |
| **Epic 7: Invitations** | FR42-FR49, FR98, FR107 | 10 |
| **Epic 8: Portal Routing** | FR50-FR60, FR95 | 12 |
| **Epic 9: Shared Entities** | FR61-FR70 | 10 |
| **Epic 10: API Keys** | FR71-FR79 | 9 |
| **Epic 11: Custom Domains** | FR80-FR89 | 10 |
| **Test Coverage** | FR108-FR112 (distributed across stories) | 5 |

**Total:** 112 FRs across 11 epics

---

## Epic 1: Foundation & Infrastructure Setup

**Goal:** Establish core infrastructure and development environment for all subsequent work.

**User Value:** Development team can build features on a solid foundation with all necessary services operational.

**FRs Covered:** FR1-FR6, FR101

---

### Story 1.1: Project Setup & Build System

As a developer,
I want the Phoenix project initialized with all dependencies,
So that I can start building features immediately.

**Acceptance Criteria:**

**Given** a fresh development environment
**When** I run `mix setup`
**Then** the project compiles successfully
**And** all dependencies are installed (Phoenix 1.8.1, Elixir 1.17+, Ash 3.0 with 15+ extensions)
**And** the project structure follows Phoenix conventions (lib/mcp/, lib/mcp_web/, test/, priv/)
**And** mix.exs includes all required dependencies: ash, ash_postgres, ash_authentication, ash_policies, ash_reactor, ash_paper_trail, ash_archival, reactor, oban, redix, finch, req, meilisearch
**And** .formatter.exs is configured for Ash + Phoenix
**And** CI configuration exists (.github/workflows or similar)

**Prerequisites:** None (first story)

**Technical Notes:**
- Follow architecture.md tech stack exactly
- Set Elixir version to 1.17+ in mix.exs
- Configure mix aliases: setup, precommit, quality, check
- Create .tool-versions for asdf version management

---

### Story 1.2: Docker Compose Infrastructure Services

As a developer,
I want all infrastructure services running via Docker Compose,
So that I can develop locally without manual service configuration.

**Acceptance Criteria:**

**Given** Docker and Docker Compose are installed
**When** I run `docker-compose up -d`
**Then** PostgreSQL 17+ starts with extensions enabled (timescaledb, postgis, pgvector, age)
**And** Redis starts on configured port (default 6379)
**And** MinIO starts with S3-compatible API (default 9000)
**And** Vault starts in dev mode with root token configured
**And** Meilisearch starts on configured port (default 7700)
**And** all services have health checks configured
**And** volume mounts persist data between restarts
**And** .env file contains all connection credentials
**And** services are accessible from Phoenix application

**Prerequisites:** Story 1.1

**Technical Notes:**
- docker-compose.yml in project root
- Use official images: postgres:17-alpine, redis:7-alpine, minio/minio, hashicorp/vault, getmeili/meilisearch
- PostgreSQL must have shared_preload_libraries='timescaledb,postgis,age' in postgresql.conf
- Vault root token in .env as VAULT_DEV_ROOT_TOKEN_ID
- Network: all services on same bridge network
- Health checks: pg_isready, redis-cli ping, vault status

---

### Story 1.3: PostgreSQL Schema Organization & Extensions

As a developer,
I want PostgreSQL properly configured with all required extensions and schemas,
So that multi-tenancy and advanced features work correctly.

**Acceptance Criteria:**

**Given** PostgreSQL 17+ is running via Docker Compose
**When** I run `mix ecto.setup`
**Then** database "mcp_dev" is created
**And** extension "timescaledb" is enabled
**And** extension "postgis" is enabled
**And** extension "pgvector" is enabled
**And** extension "age" is enabled (Apache AGE for graph database)
**And** schema "platform" is created
**And** schema "shared" is created
**And** search_path is set to "platform, shared, public" by default
**And** Repo module (Mcp.Core.Repo) connects successfully
**And** migrations run without errors

**Prerequisites:** Story 1.2

**Technical Notes:**
- Migration: priv/repo/migrations/20250117000001_create_platform_schema_and_extensions.exs
- Use `execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"` for each extension
- Set search_path in migration: `execute "ALTER DATABASE mcp_dev SET search_path TO platform, shared, public"`
- Repo configuration in config/dev.exs with runtime.exs overrides
- Connection pool size: 10 per config/config.exs
- Repo.init/2 callback loads credentials from environment variables

---

### Story 1.4: Lookup Tables Population

As a developer,
I want all lookup tables created and populated with complete data,
So that entity types, statuses, and other enums are available without migrations.

**Acceptance Criteria:**

**Given** the platform schema exists
**When** I run `mix ecto.migrate && mix run priv/repo/seeds.exs`
**Then** table platform.entity_types exists with 30+ entity types (user, user_profile, tenant, developer, reseller, merchant, mid, store, customer, vendor, product, product_variant, category, collection, order, order_item, cart, cart_item, transaction, payment_method, refund, chargeback, payout, shipment, shipment_item, tracking_event, page, blog_post, media, campaign, discount, coupon, loyalty_program, ticket, message, kb_article)
**And** table platform.status_types exists with all statuses (active, suspended, pending, invited, deleted, archived, expired, approved, rejected, processing, completed, failed, cancelled)
**And** table platform.address_types exists (home, business, shipping, billing, warehouse)
**And** table platform.email_types exists (personal, work, support, billing, noreply)
**And** table platform.phone_types exists (mobile, home, work, fax, sms_capable)
**And** table platform.social_platforms exists (twitter, facebook, instagram, linkedin, github, youtube, tiktok)
**And** table platform.image_types exists (avatar, logo, product, banner, thumbnail, gallery)
**And** table platform.document_types exists (kyc_id, passport, drivers_license, contract, invoice, receipt, tax_document, bank_statement, article_of_incorporation, certificate)
**And** table platform.plan_types exists (starter, professional, enterprise)
**And** all lookup tables have metadata columns (display_name, description, icon, color, sort_order, is_active)
**And** lookup tables support i18n (locale-specific display_name)

**Prerequisites:** Story 1.3

**Technical Notes:**
- Migration: priv/repo/migrations/20250117000002_create_lookup_tables.exs
- Seed file: priv/repo/seeds/lookup_tables.exs
- Each lookup table structure:
  ```sql
  CREATE TABLE platform.entity_types (
    value TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'
  );
  ```
- Use INSERT statements in seed file (NOT migrations for data)
- Entity types must match polymorphic owner_type values exactly

---

### Story 1.5: OTP Supervision Tree Architecture

As a developer,
I want the complete OTP supervision tree implemented,
So that the application has proper fault tolerance and process organization.

**Acceptance Criteria:**

**Given** the Phoenix application starts
**When** I run `iex -S mix phx.server`
**Then** Mcp.Application starts with :one_for_one strategy
**And** Mcp.Infrastructure.Supervisor starts with :rest_for_one strategy containing:
  - Mcp.Core.Repo (Ecto connection pool)
  - Mcp.Infrastructure.Cache.Supervisor → Redix pool + Cache.Manager + SessionStore
  - Mcp.Infrastructure.Secrets.Supervisor → VaultClient + CredentialManager + EncryptionService
  - Mcp.Infrastructure.Storage.Supervisor → S3Client + FileManager
  - Mcp.Infrastructure.Search.Supervisor → MeilisearchClient
**And** Mcp.Domains.Supervisor starts with :one_for_one strategy containing Ash domains (Auth, Tenants, Merchants, Payments, Underwriting, Analytics)
**And** Mcp.Services.Supervisor starts with :one_for_one strategy containing service GenServers (SchemaManager, ConversationManager, ModelRouter, ProcessorPool, AssessmentEngine, NotificationDispatcher, UsageTracker)
**And** Mcp.Jobs.Supervisor starts Oban with repo and config
**And** Mcp.Platform.Supervisor starts Phoenix.PubSub, Finch, PartitionSupervisor/Registry
**And** Mcp.Web.Supervisor starts McpWeb.Telemetry, McpWeb.Presence, McpWeb.Endpoint
**And** `:observer.start()` shows correct supervision tree
**And** killing a Cache.Manager process restarts only that process (not siblings)
**And** killing VaultClient restarts CredentialManager (rest_for_one in Infrastructure supervisor)

**Prerequisites:** Story 1.4

**Technical Notes:**
- File: lib/mcp/application.ex
- Supervisor structure per architecture.md OTP section
- Shared resources use permanent restart strategy
- Stateless processes (Ash domains) don't need supervision
- Infrastructure.Supervisor must be :rest_for_one for dependency ordering
- All other supervisors :one_for_one for fault isolation
- Registry for process lookup: {:via, Registry, {Mcp.Registry, key}}

---

### Story 1.6: Development Environment & Code Quality Tools

As a developer,
I want code quality tools configured and enforced,
So that code quality remains high throughout development.

**Acceptance Criteria:**

**Given** the project is set up
**When** I run `mix precommit`
**Then** code compiles without warnings
**And** Credo runs with strict mode and passes
**And** Code formatting is verified (mix format --check-formatted)
**And** Unused dependencies are detected
**And** All tests pass
**And** Mix task `mix quality` runs compile + credo + dialyzer
**And** Mix task `mix check` runs full suite (quality + test)
**And** Git pre-commit hook runs `mix precommit` automatically
**And** CI workflow runs on all pull requests
**And** Dialyzer PLT is cached for performance
**And** .credo.exs configures strict checks with project-specific rules

**Prerequisites:** Story 1.5

**Technical Notes:**
- Add to mix.exs aliases:
  ```elixir
  precommit: ["compile --warnings-as-errors", "credo --strict", "format --check-formatted", "deps.unlock --check-unused", "test"],
  quality: ["compile --warnings-as-errors", "credo --strict", "dialyzer"],
  check: ["quality", "test"]
  ```
- Git hooks: Use lefthook or husky for pre-commit
- .dialyzer_ignore.exs for known warnings
- CI: GitHub Actions or GitLab CI (test matrix for Elixir 1.17, 1.18)
- Code coverage: Mix task with SimpleCov or Coveralls

---

### Story 1.7: Test Coverage & Quality Gates

As a developer,
I want comprehensive test infrastructure configured,
So that all Phase 1 features have test coverage.

**Acceptance Criteria:**

**Given** the project has test infrastructure
**When** I run `mix test`
**Then** all tests run using ExUnit
**And** database uses SQL sandbox for isolation (Ecto.Adapters.SQL.Sandbox)
**And** test environment config exists (config/test.exs)
**And** Test database "mcp_test" is separate from dev
**And** Factory system exists for test data generation (ExMachina or similar)
**And** Test helpers are available (test/support/data_case.ex, conn_case.ex, channel_case.ex)
**And** Coverage reporting is available (`mix test --cover`)
**And** Tests run in parallel where safe
**And** Integration test helpers exist for multi-tenant scenarios
**And** Reactor saga testing utilities exist
**And** Ash policy testing utilities exist

**Prerequisites:** Story 1.6

**Technical Notes:**
- test/support/factory.ex for ExMachina factories
- test/support/fixtures.ex for common test data
- test/test_helper.exs starts sandbox, configures async
- Integration tests in test/integration/ for full scenarios
- Use tags (@tag :multi_tenant, @tag :reactor, @tag :slow) for categorization
- Coverage threshold: 80% minimum for Phase 1
- Property-based testing (StreamData) for critical paths

---

## Epic 2: User Authentication & Session Management

**Goal:** Users can securely authenticate and manage sessions.

**User Value:** Users can create accounts and log in securely with multiple authentication methods.

**FRs Covered:** FR7-FR14, FR90-FR93

---

### Story 2.1: User Resource & Registration

As a user,
I want to register an account with email and password,
So that I can access the platform securely.

**Acceptance Criteria:**

**Given** I am on the registration page
**When** I submit email "user@example.com" and password "SecurePass123!"
**Then** a user record is created in platform.users table
**And** password is hashed using bcrypt with cost factor 12
**And** password must meet requirements: min 8 chars, uppercase, lowercase, number, special character
**And** email must be valid RFC 5322 format
**And** email is unique (case-insensitive)
**And** user status is set to "active"
**And** created_at and updated_at timestamps are set
**And** user receives confirmation email (optional for now, required for production)
**And** weak passwords are rejected ("password123", "qwerty", common passwords)
**And** registration form shows real-time password strength indicator

**Prerequisites:** Epic 1 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/auth/user.ex
- Use ash_authentication extension for built-in auth
- Actions: :register, :sign_in, :sign_out
- Validations: Ash.Policy.Check.attribute for email format
- Password hashing: Bcrypt via ash_authentication (cost: 12)
- Migration: priv/repo/migrations/20250117000003_create_users.exs
- Table: platform.users (id, email, hashed_password, two_factor_enabled, two_factor_secret, password_change_required, status, last_sign_in_at, sign_in_count, failed_attempts, locked_at, deleted_at, timestamps)

---

### Story 2.2: Email/Password Authentication

As a user,
I want to sign in with my email and password,
So that I can access my account.

**Acceptance Criteria:**

**Given** I have a registered account
**When** I submit correct email and password
**Then** I am authenticated successfully
**And** JWT token is generated with user_id and email
**And** Session cookie is set with domain .base.do
**And** Cookie is secure (HTTPS only), http_only (XSS protection), same_site: "Lax"
**And** last_sign_in_at timestamp is updated
**And** sign_in_count is incremented
**And** I am redirected to appropriate portal based on context

**Given** I submit incorrect password
**When** I attempt to sign in
**Then** authentication fails with "Invalid email or password" message
**And** failed_attempts counter increments
**And** no information is leaked about whether email exists

**Given** I have failed 5 sign-in attempts
**When** I attempt to sign in again
**Then** account is locked (locked_at timestamp set)
**And** I see "Account locked due to too many failed attempts. Try again in 15 minutes."
**And** lockout expires after 15 minutes automatically

**Prerequisites:** Story 2.1

**Technical Notes:**
- Use ash_authentication for sign_in action
- Rate limiting: 5 attempts per 15 minutes per IP + email combination
- Store failed attempts in users table (failed_attempts, locked_at)
- Oban job to unlock accounts after 15 minutes
- JWT library: Joken or Guardian
- Session store: Redis via Redix
- LiveView page: lib/mcp_web/live/auth_live/sign_in.ex

---

### Story 2.3: TOTP 2FA Setup & Verification

As a user,
I want to enable two-factor authentication,
So that my account has additional security protection.

**Acceptance Criteria:**

**Given** I am signed in
**When** I navigate to 2FA setup page
**Then** I see a QR code for TOTP authenticator app (Google Authenticator, Authy, 1Password)
**And** I see a manual entry key (base32 secret)
**And** I can scan QR code with my authenticator app
**And** I am prompted to enter a 6-digit verification code
**And** when I enter correct code, 2FA is enabled (two_factor_enabled = true)
**And** two_factor_secret is encrypted and stored in users table
**And** I am shown backup codes (10 codes, one-time use, encrypted)
**And** backup codes can be regenerated if lost

**Given** I have 2FA enabled
**When** I sign in with email/password
**Then** I am prompted for 6-digit TOTP code
**And** code must be verified within 30-second window
**And** code can be used only once (replay protection)
**And** I can use backup code instead of TOTP code
**And** using backup code invalidates that specific code
**And** invalid code shows "Invalid verification code" with retry option

**Prerequisites:** Story 2.2

**Technical Notes:**
- Library: nimble_totp for TOTP generation/verification
- QR code: eqrcode library
- Secret generation: 32 bytes random via :crypto.strong_rand_bytes(32) |> Base.encode32()
- Encryption: HashiCorp Vault or Cloak for two_factor_secret and backup codes
- Time window: 30 seconds (± 1 window for clock drift tolerance)
- Store used TOTP codes in Redis with 90-second TTL (replay prevention)
- Backup codes: 10 codes, 16 chars each, bcrypt hashed

---

### Story 2.4: OAuth Authentication (Google & GitHub)

As a user,
I want to sign in with Google or GitHub,
So that I can use my existing accounts without creating a new password.

**Acceptance Criteria:**

**Given** I am on the sign-in page
**When** I click "Sign in with Google"
**Then** I am redirected to Google OAuth consent screen
**And** I authorize the application
**And** I am redirected back to the application with authorization code
**And** application exchanges code for access token
**And** application fetches user profile (email, name, avatar)
**And** if email exists in platform.users, user is signed in
**And** if email doesn't exist, new user is created with OAuth provider linked
**And** OAuth token is encrypted and stored for future API calls (if needed)
**And** user profile is populated from OAuth data (name, avatar_url)

**Given** I am on the sign-in page
**When** I click "Sign in with GitHub"
**Then** same flow as Google occurs
**And** GitHub email and avatar are used

**Given** I have an account with email/password
**When** I sign in with Google using same email
**Then** OAuth provider is linked to existing account
**And** I can use either email/password or Google to sign in

**Prerequisites:** Story 2.3

**Technical Notes:**
- Library: ueberauth with ueberauth_google and ueberauth_github strategies
- OAuth credentials: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET in .env
- Callback URL: https://platform.base.do/auth/{google|github}/callback
- Store OAuth tokens encrypted in platform.oauth_tokens table (user_id, provider, access_token, refresh_token, expires_at)
- Handle OAuth email verification status (some providers allow unverified emails)
- Avatar URL stored in user_profiles, not users (entity-scoped)

---

### Story 2.5: Forced Password Change on First Login

As a platform administrator,
I want seed admin account to require password change on first login,
So that default credentials are never used in production.

**Acceptance Criteria:**

**Given** platform admin account exists (admin@platform.local) with password_change_required = true
**When** I sign in with default credentials
**Then** I am authenticated but redirected to /change-password page
**And** I cannot access any other page until password is changed
**And** middleware redirects all requests to /change-password (except sign-out)
**And** I see form to enter new password (twice for confirmation)
**And** new password must meet all password requirements
**And** new password must be different from old password
**And** when I submit valid new password, password_change_required is set to false
**And** I am redirected to platform dashboard
**And** subsequent logins do not trigger password change flow

**Prerequisites:** Story 2.4

**Technical Notes:**
- Add password_change_required BOOLEAN to platform.users table
- Plug: McpWeb.Plugs.RequirePasswordChange (runs after authentication)
- Plug checks get_session(:password_change_required)
- Plug redirects to /change-password unless current path is /change-password or /auth/sign-out
- LiveView: lib/mcp_web/live/auth_live/change_password.ex
- Ash action: :change_password with validation that new != old

---

### Story 2.6: JWT Session Management with Context

As a developer,
I want JWT sessions to contain user context information,
So that authorization checks have all necessary data without database queries.

**Acceptance Criteria:**

**Given** a user signs in
**When** JWT token is generated
**Then** token contains:
  - user_id (UUID)
  - email
  - current_context (type, id, slug, profile_id)
  - authorized_contexts (array of all contexts user can access)
  - iat (issued at timestamp)
  - exp (expiration timestamp, 24 hours)
  - iss ("base.do")
**And** token is signed with secret key from environment variable JWT_SECRET_KEY
**And** token is stored in session cookie with domain .base.do
**And** token is verified on every request via McpWeb.Plugs.AuthPlug
**And** expired tokens are rejected with 401 Unauthorized
**And** invalid signatures are rejected with 401 Unauthorized
**And** current_user is assigned to conn from verified token
**And** token expiration is refreshed on each request (sliding session)

**Prerequisites:** Story 2.5

**Technical Notes:**
- Library: Joken for JWT generation/verification
- Secret key: Generate via `mix phx.gen.secret` and store in JWT_SECRET_KEY env var
- Claims structure:
  ```elixir
  %{
    user_id: "uuid",
    email: "user@example.com",
    current_context: %{
      type: :tenant,
      id: "tenant-uuid",
      slug: "acme",
      profile_id: "profile-uuid"
    },
    authorized_contexts: [%{type: :tenant, id: "...", slug: "...", profile_id: "..."}],
    iat: unix_timestamp,
    exp: unix_timestamp,
    iss: "base.do"
  }
  ```
- Plug: lib/mcp_web/plugs/auth_plug.ex (verify token, assign current_user to conn)
- Sliding session: Generate new token with updated exp on each request
- Store JWT in encrypted session cookie (not localStorage to prevent XSS)

---

### Story 2.7: User Soft Delete & GDPR Retention

As a platform administrator,
I want users to be soft deleted with 90-day retention,
So that we comply with GDPR while preserving audit trails.

**Acceptance Criteria:**

**Given** I am a platform admin
**When** I delete a user account
**Then** user status is set to "deleted"
**And** deleted_at timestamp is set to current time
**And** user cannot sign in (authentication blocked for deleted users)
**And** user data remains in database for 90 days
**And** Oban job is scheduled to permanently delete user after 90 days
**And** permanent deletion removes:
  - User record from platform.users
  - All user_profiles for that user
  - OAuth tokens
  - Personal data (addresses, emails, phones for owner_type = 'user')
**And** permanent deletion preserves:
  - Audit logs (ash_paper_trail)
  - Entity associations (tenants, merchants created by user remain)
**And** user can request data export before deletion (GDPR right to data portability)

**Given** a user is soft deleted
**When** they attempt to sign in
**Then** authentication fails with "Account no longer active"
**And** sign-in attempt is logged for security

**Prerequisites:** Story 2.6

**Technical Notes:**
- Add deleted_at TIMESTAMPTZ to platform.users
- Ash action: :soft_delete (sets status = "deleted", deleted_at = NOW())
- Oban worker: Mcp.Workers.PermanentUserDeletion (runs 90 days after deleted_at)
- Query scope: where(status != "deleted") in default reads
- GDPR export: JSON file with all user data (users, profiles, addresses, emails, phones, notes, todos, audit trail)
- Permanent deletion uses database transaction to remove all related records

---

### Story 2.8: Login Page UI

As a user,
I want a professional login page,
So that I can easily access my account.

**Acceptance Criteria:**

**Given** I navigate to any protected page while unauthenticated
**When** I am redirected to /auth/sign-in
**Then** I see a clean, branded login form with:
  - Email input (type="email", autocomplete="email", autofocus)
  - Password input (type="password", autocomplete="current-password", show/hide toggle)
  - "Remember me" checkbox (extends session to 30 days)
  - "Sign in" button (primary DaisyUI button)
  - "Forgot password?" link
  - Divider "OR"
  - "Sign in with Google" button (Google branding)
  - "Sign in with GitHub" button (GitHub branding)
  - "Don't have an account? Contact your administrator" text (NO self-registration link)
**And** form shows validation errors inline
**And** form shows generic error "Invalid email or password" on auth failure
**And** form shows account locked message when applicable
**And** password field has show/hide icon (eye icon)
**And** page is mobile responsive (DaisyUI responsive classes)
**And** page uses current context branding (logo, colors, theme)

**Prerequisites:** Story 2.7

**Technical Notes:**
- LiveView: lib/mcp_web/live/auth_live/sign_in.ex
- Template: DaisyUI form components (form-control, input, btn, divider)
- Branding: Load from context (tenant, merchant, or platform default)
- OAuth buttons: Use provider official button guidelines
- CSRF protection: Phoenix.Controller.get_csrf_token()
- Redirect after login: params["redirect_to"] || default_path_for_user(user)

---

### Story 2.9: Customer/Vendor Self-Registration (Merchant-Controlled)

As a customer or vendor,
I want to register an account at merchant portals,
So that I can access merchant services without waiting for an invitation.

**IMPORTANT:** This is the ONLY self-registration in the entire platform. All other entity types (platform admins, tenants, developers, resellers, merchants, stores) are invitation-only.

**Acceptance Criteria:**

**Given** merchant has customer_self_registration enabled in settings
**When** I navigate to customer.{merchant}.base.do
**Then** I see sign-in page with "Create Account" link visible
**And** clicking "Create Account" shows registration form with:
  - Email input (required, validated)
  - Password input (required, with strength indicator)
  - Password confirmation input
  - "Create Account" button
  - Password requirements shown (8+ chars, mixed types)
  - Link back to sign-in ("Already have an account?")
**And** on submit with valid data:
  - Customer user is created in platform.users
  - Customer profile is created in platform.user_profiles (entity_type: "customer")
  - Customer record is created in acq_{tenant}.customers
  - I am signed in automatically
  - I am redirected to customer portal dashboard

**Given** merchant has vendor_self_registration enabled in settings
**When** I navigate to vendor.{merchant}.base.do
**Then** same registration flow as customer but creates vendor records

**Given** merchant has customer_self_registration DISABLED in settings
**When** I navigate to customer.{merchant}.base.do
**Then** I see sign-in page WITHOUT "Create Account" link
**And** page shows "Don't have an account? Contact {merchant_name} for access."

**Given** I am at any NON-merchant portal (platform.base.do, {tenant}.base.do, app.base.do)
**When** I navigate to /register
**Then** I see "Registration not available. Contact your administrator for an invitation."
**And** NO registration form is displayed

**Given** I am at {tenant}.base.do/developers or {tenant}.base.do/resellers
**When** I attempt to access /register
**Then** I see "Invitation required. Contact tenant administrator."

**Prerequisites:** Story 2.8

**Technical Notes:**
- LiveView: lib/mcp_web/live/auth_live/register.ex
- Merchant settings fields (in platform.tenants or acq_{tenant}.merchants):
  - customer_self_registration BOOLEAN DEFAULT false
  - vendor_self_registration BOOLEAN DEFAULT false
- Registration ONLY works when:
  1. Portal is customer.{merchant}.base.do OR vendor.{merchant}.base.do
  2. ContextPlug identifies portal type as :customer_portal or :vendor_portal
  3. Merchant setting for that type is true
- Registration flow: Create user → Create user_profile → Create customer/vendor entity (single transaction)
- Validation: Email uniqueness, password strength
- Password strength indicator: zxcvbn library with real-time feedback
- Auto sign-in: Generate JWT token immediately after creation
- Default merchant settings: Both flags false (invitation-only by default)

---

### Story 2.10: 2FA Setup Page UI

As a user with 2FA enabled,
I want to see a setup page with QR code,
So that I can configure my authenticator app.

**Acceptance Criteria:**

**Given** I am signed in without 2FA
**When** I navigate to /auth/2fa/setup
**Then** I see:
  - QR code for TOTP secret (generated server-side)
  - Manual entry key (base32 secret, copyable)
  - "Scan with your authenticator app" instructions
  - List of compatible apps (Google Authenticator, Authy, 1Password)
  - Verification code input (6 digits)
  - "Enable 2FA" button
**And** when I enter correct TOTP code, 2FA is enabled
**And** I see success message "Two-factor authentication enabled"
**And** I see 10 backup codes displayed (download as text file)
**And** I see "Regenerate backup codes" option

**Given** I have 2FA enabled
**When** I navigate to /auth/2fa/setup
**Then** I see:
  - "Two-factor authentication is enabled" status
  - "Disable 2FA" button
  - "Regenerate backup codes" button
**And** I can disable 2FA (requires current password + TOTP code)

**Prerequisites:** Story 2.9

**Technical Notes:**
- LiveView: lib/mcp_web/live/auth_live/two_factor_setup.ex
- QR code generation server-side (eqrcode library)
- QR code rendered as SVG or PNG data URL
- Manual key shown in monospace font with copy button
- Backup codes download as .txt file via LiveView download helper
- Disable 2FA requires re-authentication (password + TOTP)

---

### Story 2.11: Forced Password Change Page UI

As a user,
I want to change my password when required,
So that I don't use default credentials.

**Acceptance Criteria:**

**Given** I am signed in with password_change_required = true
**When** I am redirected to /auth/change-password
**Then** I see form with:
  - "Change your password" heading
  - "For security, you must change your password before continuing."
  - Current password input
  - New password input (with strength indicator)
  - Confirm new password input
  - Password requirements checklist
  - "Change Password" button
  - "Sign Out" link
**And** form validates new password meets requirements
**And** form validates new password != old password
**And** form validates new password = confirm password
**And** on success, I see "Password changed successfully"
**And** I am redirected to dashboard
**And** subsequent logins don't trigger this flow

**Prerequisites:** Story 2.10

**Technical Notes:**
- LiveView: lib/mcp_web/live/auth_live/change_password.ex
- Middleware blocks all routes except /auth/change-password and /auth/sign-out
- Password strength indicator shows progress bar (weak/fair/good/strong)
- Requirements checklist: Real-time validation with checkmarks
- On submit, verify current password, then update to new password

---

### Story 2.12: Authentication Test Coverage

As a developer,
I want complete test coverage for all authentication flows,
So that security-critical code is well-tested.

**Acceptance Criteria:**

**Given** the authentication epic is complete
**When** I run `mix test test/mcp/auth/`
**Then** all tests pass with 100% coverage including:
  - User registration (valid, invalid email, weak password, duplicate email)
  - Email/password sign-in (correct, incorrect, rate limiting, account lockout)
  - TOTP 2FA (setup, verification, backup codes, replay protection)
  - OAuth (Google, GitHub, new user, existing user, linking)
  - Forced password change (redirect, validation, success)
  - JWT generation (claims, signing, expiration)
  - JWT verification (valid, expired, invalid signature)
  - Soft delete (soft delete, permanent delete after 90 days, GDPR export)
  - Session management (creation, refresh, expiration)
**And** integration tests cover full sign-in flows end-to-end
**And** property-based tests cover password validation edge cases

**Prerequisites:** Story 2.11

**Technical Notes:**
- Unit tests: test/mcp/domains/auth/user_test.exs
- Integration tests: test/mcp_web/live/auth_live_test.exs
- Factory: test/support/factory/user_factory.ex
- Fixtures: Common test users (admin, regular, 2fa_enabled, locked, deleted)
- Use ExMachina for factories
- Use StreamData for property tests (password validation)
- Test CSRF protection, XSS prevention, SQL injection prevention

---

## Epic 3: Multi-Tenancy & Schema Management

**Goal:** Platform can manage multiple isolated tenants with automatic provisioning.

**User Value:** Platform admins can onboard new payment processors as isolated tenants.

**FRs Covered:** FR15-FR20, FR102-FR103

---

### Story 3.1: Tenant Resource & Schema

As a platform administrator,
I want to create tenant records,
So that I can onboard new payment processors to the platform.

**Acceptance Criteria:**

**Given** I am a platform admin
**When** I create a tenant with name "Acme Payment Solutions" and slug "acme"
**Then** a tenant record is created in platform.tenants table
**And** slug is validated (lowercase, alphanumeric + hyphens only, 3-63 chars)
**And** slug is unique (case-insensitive)
**And** tenant has default status "active"
**And** tenant has branding JSONB field (logo_url, primary_color, secondary_color, font_family, daisyui_theme, custom_css, favicon_url)
**And** tenant has settings JSONB field (empty by default)
**And** tenant has created_at and updated_at timestamps

**Given** I attempt to create tenant with invalid slug "Acme Corp" (spaces)
**When** I submit the form
**Then** validation fails with "Slug must be lowercase alphanumeric with hyphens only"

**Given** I attempt to create tenant with existing slug "acme"
**When** I submit the form
**Then** validation fails with "Slug already taken"

**Prerequisites:** Epic 2 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/tenants/tenant.ex
- Migration: priv/repo/migrations/20250117000005_create_tenants.exs
- Table: platform.tenants (id, name, slug, status, branding JSONB, settings JSONB, timestamps)
- Validations: slug format regex /^[a-z0-9-]{3,63}$/, unique constraint
- Index on slug for fast lookups

---

### Story 3.2: Tenant Schema Creation (OnboardingReactor Saga)

As a platform administrator,
I want tenant schemas automatically created via Reactor saga,
So that tenant data is isolated without manual intervention.

**Acceptance Criteria:**

**Given** I create a new tenant "acme"
**When** OnboardingReactor saga executes
**Then** PostgreSQL schema "acq_acme" is created
**And** schema creation step completes successfully
**And** if schema creation fails, saga rolls back and tenant record is deleted
**And** saga continues to migration step

**Given** tenant schema creation fails (database connection error)
**When** saga compensate function executes
**Then** tenant record is deleted from platform.tenants
**And** error is logged with full context

**Prerequisites:** Story 3.1

**Technical Notes:**
- Reactor saga: lib/mcp/domains/tenants/onboarding_reactor.ex
- Step :create_schema runs SQL: `CREATE SCHEMA IF NOT EXISTS acq_#{slug}`
- Compensate function: `DROP SCHEMA IF EXISTS acq_#{slug} CASCADE`
- Use Mcp.Core.Repo.query/1 for raw SQL
- Saga input: %{tenant_params: map, admin_user: struct}
- Execute via Reactor.run(OnboardingReactor, inputs)

---

### Story 3.3: Tenant-Specific Migrations

As a developer,
I want tenant schemas to have all necessary tables,
So that tenant data can be stored in isolated schemas.

**Acceptance Criteria:**

**Given** tenant schema "acq_acme" exists
**When** OnboardingReactor migration step executes
**Then** the following tables are created in acq_acme schema:
  - developers
  - resellers
  - merchants
  - mids
  - stores
  - customers
  - vendors
**And** all tables have proper primary keys (UUID)
**And** all tables have foreign key constraints
**And** all tables have created_at and updated_at timestamps
**And** all tables have indexes on foreign keys
**And** migrations are idempotent (can run multiple times safely)

**Prerequisites:** Story 3.2

**Technical Notes:**
- Module: lib/mcp/multi_tenant.ex with function run_tenant_migrations/1
- Migrations in priv/repo/tenant_migrations/ directory (separate from platform migrations)
- Execute migrations with search_path set to acq_{tenant}
- Migration template: priv/repo/tenant_migrations/20250117000001_create_tenant_tables.exs
- Use Ecto.Migrator.run/4 with prefix option
- Tables created: developers, resellers, merchants, mids, stores, customers, vendors, products, transactions (hypertable), orders, subscriptions

---

### Story 3.4: Search Path Management

As a developer,
I want search_path properly managed for tenant queries,
So that queries automatically use correct schema without explicit prefixing.

**Acceptance Criteria:**

**Given** I am querying tenant "acme" data
**When** I call `Mcp.MultiTenant.with_tenant_context("acme", fn -> ... end)`
**Then** search_path is set to "acq_acme, platform, shared, public"
**And** queries inside function use acq_acme schema by default
**And** queries can access platform schema (users, tenants, lookup tables)
**And** queries can access shared schema (addresses, emails, phones)
**And** after function completes, search_path is reset to "platform, shared, public"
**And** search_path reset happens even if function raises exception (ensure in after block)

**Given** I run concurrent queries for different tenants
**When** multiple `with_tenant_context` calls execute
**Then** each database connection has independent search_path
**And** no query sees data from wrong tenant
**And** connection pool isolation is maintained

**Prerequisites:** Story 3.3

**Technical Notes:**
- Module: lib/mcp/multi_tenant.ex
- Function: with_tenant_context(tenant_slug, fun)
- Implementation:
  ```elixir
  def with_tenant_context(tenant_slug, fun) do
    schema_name = "acq_#{tenant_slug}"
    Repo.query("SET search_path TO #{schema_name}, platform, shared, public")
    try do
      fun.()
    after
      Repo.query("SET search_path TO platform, shared, public")
    end
  end
  ```
- Use Repo.put_dynamic_repo/1 for connection-specific settings
- Test with concurrent requests to verify isolation

---

### Story 3.5: Subdomain Provisioning (CloudFlare API or Stub)

As a platform administrator,
I want tenant subdomains automatically provisioned,
So that tenants can access their portal at {tenant}.base.do.

**Acceptance Criteria:**

**Given** OnboardingReactor saga reaches subdomain provisioning step
**When** subdomain provisioning executes for tenant "acme"
**Then** DNS A record is created: acme.base.do → platform IP
**And** if CloudFlare API is configured, real DNS record is created
**And** if CloudFlare API is NOT configured, stub logs provisioning request
**And** provisioning happens asynchronously (async?: true in Reactor)
**And** provisioning failure does NOT block tenant creation
**And** provisioning retry is scheduled via Oban if it fails

**Given** CloudFlare API credentials are configured (CLOUDFLARE_API_TOKEN, CLOUDFLARE_ZONE_ID)
**When** subdomain is provisioned
**Then** API request creates DNS record with:
  - Type: A
  - Name: acme
  - Content: platform IP address
  - TTL: 1 (auto)
  - Proxied: true (CloudFlare CDN)
**And** API response is logged

**Prerequisites:** Story 3.4

**Technical Notes:**
- OnboardingReactor step :provision_subdomain (async?: true)
- Module: lib/mcp/dns.ex with create_subdomain/1
- CloudFlare API: POST /zones/:zone_id/dns_records
- Stub implementation logs to Logger.info("Provisioning subdomain: #{slug}.base.do")
- Retry via Oban worker: Mcp.Workers.SubdomainProvisioner
- Compensate function: Delete DNS record if tenant creation fails
- Environment variables: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ZONE_ID, PLATFORM_IP

---

### Story 3.6: Initial Tenant Admin User Creation

As a platform administrator,
I want tenant creation to automatically create an initial admin user,
So that tenant can access their portal immediately.

**Acceptance Criteria:**

**Given** OnboardingReactor saga completes schema and migrations
**When** initial admin creation step executes
**Then** user is created in platform.users with email from tenant_params
**And** user_profile is created in platform.user_profiles with:
  - user_id: created user
  - entity_type: "tenant"
  - entity_id: created tenant id
  - is_admin: true
  - status: "invited" (must accept invitation and set password)
**And** invitation email is sent with secure token
**And** user can accept invitation to set password and activate account

**Given** initial admin creation fails (duplicate email)
**When** saga compensate function executes
**Then** tenant schema is dropped
**And** tenant record is deleted
**And** DNS record is removed
**And** error is returned to platform admin

**Prerequisites:** Story 3.5

**Technical Notes:**
- OnboardingReactor step: :create_admin (Ash action)
- Creates user + profile in single transaction
- Invitation token generated via :crypto.strong_rand_bytes(32) |> Base.url_encode64()
- Invitation stored in platform.invitations table (user_id, token, expires_at: 24 hours)
- Email template: "Tenant admin invitation" with link to /invitations/accept?token=XXX
- Wait for schema + migrations before creating admin

---

### Story 3.7: Tenant Seed Data

As a developer,
I want comprehensive seed data for testing,
So that I can test multi-tenant scenarios.

**Acceptance Criteria:**

**Given** I run `mix run priv/repo/seeds.exs`
**Then** platform admin is created (admin@platform.local, password_change_required: true)
**And** sample tenant "Acme Payment Solutions" is created with slug "acme"
**And** acq_acme schema is created with all tables
**And** tenant admin user is created (admin@acme.local)
**And** tenant has default branding configuration:
  - logo_url: placeholder
  - primary_color: #FF6B35
  - secondary_color: #004E89
  - daisyui_theme: "corporate"
**And** seed data includes second tenant "Globex Corp" with slug "globex"
**And** both tenants can be accessed at acme.base.do and globex.base.do

**Prerequisites:** Story 3.6

**Technical Notes:**
- Seed file: priv/repo/seeds/tenants.exs
- Platform admin: email "admin@platform.local", password "ChangeMe123!", password_change_required: true
- Use OnboardingReactor.run() to create tenants properly (not direct inserts)
- Tenant admins: "admin@acme.local", "admin@globex.local" with invited status
- Include sample branding for visual testing

---

### Story 3.8: Multi-Tenancy Test Coverage

As a developer,
I want complete test coverage for multi-tenancy,
So that tenant isolation is guaranteed.

**Acceptance Criteria:**

**Given** multi-tenancy epic is complete
**When** I run `mix test test/mcp/multi_tenant_test.exs`
**Then** all tests pass with 100% coverage including:
  - Tenant creation (valid, invalid slug, duplicate slug)
  - OnboardingReactor saga (full success, schema failure rollback, migration failure rollback)
  - Schema isolation (tenant A cannot query tenant B data)
  - Search path management (correct path, concurrent queries, exception safety)
  - Subdomain provisioning (CloudFlare API success, stub mode, retry on failure)
  - Initial admin creation (success, duplicate email rollback)
**And** integration tests cover full tenant onboarding flow
**And** tests verify search_path is reset on exception
**And** tests verify concurrent tenant queries don't leak data

**Prerequisites:** Story 3.7

**Technical Notes:**
- Test file: test/mcp/domains/tenants/tenant_test.exs
- Integration test: test/integration/tenant_onboarding_test.exs
- Factory: tenant_factory with :tenant, :tenant_with_schema, :tenant_with_admin
- Test helpers: create_tenant_with_data/1, switch_to_tenant/2
- Use Ecto.Adapters.SQL.Sandbox.checkout/2 for schema isolation testing
- Test search_path with: Repo.query("SHOW search_path") after context switch

---


## Epic 4: Entity-Scoped User Profiles & Context Switching

**Goal:** Users can maintain different professional identities across entities.

**User Value:** Users can work with multiple organizations using appropriate identity for each context.

**FRs Covered:** FR21-FR26, FR94-FR96, FR99

---

### Story 4.1: User Profile Resource

As a user,
I want separate profiles for each entity I belong to,
So that I can have different professional identities per organization.

**Acceptance Criteria:**

**Given** I am a user (user_id: uuid-123)
**When** I am added to tenant "acme" as admin
**Then** user_profile is created in platform.user_profiles with:
  - user_id: uuid-123
  - entity_type: "tenant"
  - entity_id: acme tenant id
  - first_name, last_name, nickname
  - avatar_url, bio, title
  - contact_email, phone, timezone (defaults to UTC)
  - preferences: {} (JSONB)
  - is_admin: true
  - is_developer: false
  - status: "active"
**And** user_profile is unique per (user_id, entity_type, entity_id)

**Given** same user is added to merchant "bobs-burgers" as non-admin
**When** profile is created
**Then** separate user_profile exists with different name, avatar, title

**Prerequisites:** Epic 3 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/auth/user_profile.ex
- Migration: priv/repo/migrations/20250117000004_create_user_profiles.exs
- Table: platform.user_profiles (id, user_id FK, entity_type FK entity_types, entity_id, first_name, last_name, nickname, avatar_url, bio, title, contact_email, phone, timezone, preferences JSONB, is_admin, is_developer, status, timestamps)
- Unique constraint: (user_id, entity_type, entity_id)
- Indexes: (user_id), (entity_type, entity_id)

---

### Story 4.2: Profile Management Actions

As a user,
I want to update my profile for each entity,
So that I can customize my identity per organization.

**Acceptance Criteria:**

**Given** I have a profile in tenant "acme"
**When** I update profile with: first_name "Alice", last_name "Johnson", title "CTO"
**Then** profile is updated in platform.user_profiles
**And** changes reflect immediately in UI
**And** other profiles (merchant, etc.) remain unchanged

**Prerequisites:** Story 4.1

**Technical Notes:**
- Ash actions: :update_profile, :list_user_profiles
- LiveView: lib/mcp_web/live/profile_live/edit.ex
- Avatar upload to MinIO bucket "avatars"
- Validations: email format, phone E.164, timezone from TZ database

---

### Story 4.3: Context Resolution from JWT

As a developer,
I want JWT tokens to include current profile data,
So that profile information is available without database queries.

**Acceptance Criteria:**

**Given** user signs in at acme.base.do
**When** JWT token is generated
**Then** current_context includes profile_id for acme tenant
**And** token includes current profile data (first_name, last_name, is_admin, is_developer)
**And** authorized_contexts includes all user profiles with basic info

**Prerequisites:** Story 4.2

**Technical Notes:**
- Extend JWT claims structure from Story 2.6
- Load all user profiles on sign-in
- Current profile determined by subdomain/context
- Update McpWeb.Plugs.AuthPlug to load current_profile from JWT

---

### Story 4.4: Context Switching with Profile Change

As a user,
I want to switch between entities and see my appropriate profile,
So that I can work with different identities seamlessly.

**Acceptance Criteria:**

**Given** I am signed in to tenant "acme" as "Alice Johnson, CTO"
**When** I switch to merchant "bobs-burgers"
**Then** session is rotated (new JWT generated)
**And** current_context changes to merchant context
**And** current profile changes to merchant profile ("Chef Alice")
**And** navigation shows "Chef Alice" with merchant avatar
**And** old session is invalidated for security

**Prerequisites:** Story 4.3

**Technical Notes:**
- Reactor saga: lib/mcp/domains/auth/context_switch_reactor.ex
- Steps: validate_access, load_permissions, invalidate_session, create_new_session, audit_log
- Redirect to appropriate subdomain
- Audit log in platform.audit_log

---

### Story 4.5: Context Switcher UI (app.base.do)

As a multi-context user,
I want to see all my accessible contexts in one place,
So that I can easily navigate between organizations.

**Acceptance Criteria:**

**Given** I navigate to app.base.do while signed in
**When** page loads
**Then** I see "Select Organization" heading
**And** I see grid of cards (one per authorized context) showing:
  - Entity logo or icon
  - Entity name
  - My role (Admin, Developer, User)
  - Entity type badge
**And** clicking a card switches to that context

**Given** I have only one context
**When** I sign in
**Then** I am redirected directly to that context (skip app.base.do)

**Prerequisites:** Story 4.4

**Technical Notes:**
- LiveView: lib/mcp_web/live/discovery_live/index.ex
- DaisyUI card component with hover effects
- Icons: heroicons for entity types
- Sort by: entity type, then name

---

### Story 4.6: Navigation Context Switcher Dropdown

As a multi-context user,
I want a context switcher in navigation,
So that I can switch without visiting app.base.do.

**Acceptance Criteria:**

**Given** I am signed in with multiple contexts
**When** I view any page
**Then** I see dropdown in navigation showing current context name and icon
**And** clicking dropdown shows all my contexts
**And** clicking an item switches to that context

**Given** I have only one context
**When** I view navigation
**Then** context switcher is hidden

**Prerequisites:** Story 4.5

**Technical Notes:**
- Component: lib/mcp_web/components/context_switcher.ex
- Renders in McpWeb.Layouts.App topbar
- DaisyUI dropdown component
- Current context highlighted

---

### Story 4.7: Profile Display Per Context

As a user,
I want to see my profile specific to current context,
So that I know which identity I'm using.

**Acceptance Criteria:**

**Given** I am in tenant "acme" context
**When** I view profile dropdown
**Then** I see avatar, name, title for tenant profile

**Given** I switch to merchant context
**When** I view profile dropdown
**Then** I see different avatar, name, title for merchant profile

**Prerequisites:** Story 4.6

**Technical Notes:**
- Profile dropdown: lib/mcp_web/components/profile_dropdown.ex
- Load current_profile from conn.assigns
- Profile page: lib/mcp_web/live/profile_live/show.ex

---

### Story 4.8: Profile Role Flags (is_admin, is_developer)

As a platform,
I want profiles to have role flags,
So that permissions can be determined per entity.

**Acceptance Criteria:**

**Given** user profile has is_admin: true
**When** permission check runs
**Then** user is considered admin for that entity

**Given** user profile has is_developer: true
**When** developer portal access is checked
**Then** user can access {tenant}.base.do/developers portal

**Prerequisites:** Story 4.7

**Technical Notes:**
- Flags stored in user_profiles table
- Helper functions: admin?(conn), developer?(conn)
- UI conditionals: <div :if={@current_profile.is_admin}>

---

### Story 4.9: Profile Status Management

As an entity admin,
I want to manage user profile statuses,
So that I can suspend or deactivate users from my entity.

**Acceptance Criteria:**

**Given** I am tenant admin
**When** I suspend a user profile in my tenant
**Then** profile status is set to "suspended"
**And** user cannot sign in to tenant context
**And** user's other profiles remain active

**Prerequisites:** Story 4.8

**Technical Notes:**
- Status values: active, suspended, invited, pending
- Ash actions: :suspend_profile, :activate_profile
- Sign-in check: Verify current_profile.status == "active"

---

### Story 4.10: Entity-Scoped Profile Test Coverage

As a developer,
I want complete test coverage for user profiles,
So that multi-profile functionality is reliable.

**Acceptance Criteria:**

**Given** entity-scoped profiles epic is complete
**When** I run `mix test test/mcp/auth/user_profile_test.exs`
**Then** all tests pass with 100% coverage including:
  - Profile creation, updates, context resolution
  - Context switching, profile display, role flags, status management
**And** integration tests cover full context switch flow

**Prerequisites:** Story 4.9

**Technical Notes:**
- Test files: test/mcp/domains/auth/user_profile_test.exs
- Factory: :user_profile, :admin_profile, :developer_profile
- Test JWT contains correct profile data

---

## Epic 5: All Entity Types & Hierarchical Structure

**Goal:** Complete entity hierarchy operational with all 8 entity types.

**User Value:** Platform supports full organizational hierarchy from platform → tenant → merchant → store/customer/vendor.

**FRs Covered:** FR27-FR34, FR104-FR105

---

### Story 5.1: Developer Resource

As a tenant admin,
I want to create developer entities,
So that external developers can integrate with our platform.

**Acceptance Criteria:**

**Given** I am a tenant admin
**When** I create a developer in my tenant
**Then** developer record is created in acq_{tenant}.developers table
**And** developer can belong to multiple tenants
**And** developer has profile in platform.user_profiles for each tenant
**And** developer can access {tenant}.base.do/developers portal

**Prerequisites:** Epic 4 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/developers/developer.ex
- Migration: priv/repo/tenant_migrations/XXXXX_create_developers.exs (in acq_{tenant} schema)
- Table: acq_{tenant}.developers (id, name, status, metadata JSONB, timestamps)
- Cross-tenant: Developer user can have profiles in multiple tenants

---

### Story 5.2: Reseller Resource

As a tenant admin,
I want to create reseller entities,
So that partners can manage merchant portfolios.

**Acceptance Criteria:**

**Given** I am a tenant admin
**When** I create a reseller in my tenant
**Then** reseller record is created in acq_{tenant}.resellers table
**And** reseller can belong to multiple tenants
**And** reseller can manage multiple merchants (portfolio)
**And** reseller can see merchant payment data only (not PII/business data)

**Prerequisites:** Story 5.1

**Technical Notes:**
- Ash resource: lib/mcp/domains/resellers/reseller.ex
- Table: acq_{tenant}.resellers (id, name, status, commission_config JSONB, metadata JSONB, timestamps)
- Reseller data visibility: Field-level policies restrict access to payment fields only

---

### Story 5.3: Merchant Resource

As a tenant admin,
I want to create merchant entities,
So that businesses can accept payments.

**Acceptance Criteria:**

**Given** I am a tenant admin
**When** I create a merchant with name "Bob's Burgers" and slug "bobs-burgers"
**Then** merchant record is created in acq_{tenant}.merchants table
**And** merchant belongs to single tenant only
**And** merchant has own subdomain {merchant}.base.do
**And** merchant can have MIDs, stores, customers, vendors

**Prerequisites:** Story 5.2

**Technical Notes:**
- Ash resource: lib/mcp/domains/merchants/merchant.ex
- Table: acq_{tenant}.merchants (id, tenant_id FK platform.tenants, reseller_id FK resellers, name, slug, status, branding JSONB, settings JSONB, timestamps)
- Unique constraint: (tenant_id, slug)
- Subdomain provision via MerchantOnboardingReactor (similar to tenant onboarding)
- Settings JSONB includes:
  - customer_self_registration: BOOLEAN (default false) - Allow customers to register at customer.{merchant}.base.do
  - vendor_self_registration: BOOLEAN (default false) - Allow vendors to register at vendor.{merchant}.base.do
  - payment_gateway_config: JSONB
  - feature_flags: JSONB

---

### Story 5.4: Store Resource

As a merchant admin,
I want to create store entities,
So that I can manage multiple locations or product lines.

**Acceptance Criteria:**

**Given** I am a merchant admin
**When** I create a store with name "North Location" and slug "north"
**Then** store record is created in acq_{tenant}.stores table
**And** store belongs to single merchant
**And** store has routing_type "path" (default) or "subdomain"
**And** path-based store accessed at {merchant}.base.do/stores/north
**And** subdomain store accessed at north.{merchant}.base.do (premium feature)

**Prerequisites:** Story 5.3

**Technical Notes:**
- Ash resource: lib/mcp/domains/merchants/store.ex
- Table: acq_{tenant}.stores (id, merchant_id FK merchants, name, slug, routing_type, subdomain, custom_domain, branding JSONB, settings JSONB, timestamps)
- Routing types: "path" (free), "subdomain" ($5/month)
- Unique constraint: (merchant_id, slug)

---

### Story 5.5: Customer Resource

As a merchant,
I want customer entities,
So that end-users can register and make purchases.

**Acceptance Criteria:**

**Given** I am a customer at customer.{merchant}.base.do
**When** I register an account
**Then** customer record is created in acq_{tenant}.customers table
**And** customer can self-register (ONLY entity type with self-registration besides vendor)
**And** customer belongs to single merchant
**And** customer can belong to multiple stores within merchant

**Prerequisites:** Story 5.4

**Technical Notes:**
- Ash resource: lib/mcp/domains/customers/customer.ex
- Table: acq_{tenant}.customers (id, merchant_id FK merchants, user_id FK platform.users, status, preferences JSONB, metadata JSONB, timestamps)
- Self-registration enabled only at customer.{merchant}.base.do subdomain
- Customer user_profile created on registration

---

### Story 5.6: Vendor Resource

As a merchant admin,
I want vendor entities,
So that suppliers can manage inventory and orders.

**Acceptance Criteria:**

**Given** I am a merchant admin
**When** I create a vendor or vendor self-registers
**Then** vendor record is created in acq_{tenant}.vendors table
**And** vendor can self-register at vendor.{merchant}.base.do
**And** vendor belongs to single merchant
**And** vendor can manage product catalog and inventory

**Prerequisites:** Story 5.5

**Technical Notes:**
- Ash resource: lib/mcp/domains/vendors/vendor.ex
- Table: acq_{tenant}.vendors (id, merchant_id FK merchants, user_id FK platform.users, company_name, status, metadata JSONB, timestamps)
- Self-registration enabled at vendor.{merchant}.base.do

---

### Story 5.7: Entity Hierarchy & Relationships

As a platform,
I want proper entity hierarchy and relationships enforced,
So that data integrity is maintained.

**Acceptance Criteria:**

**Given** entity hierarchy exists
**When** I query relationships
**Then** relationships are enforced:
  - Platform → Tenants (1:many)
  - Tenant → Developers, Resellers, Merchants (1:many each)
  - Merchant → MIDs, Stores, Customers, Vendors (1:many each)
  - Reseller → Merchants (many:many via portfolio)
  - Store → Customers (many:many via membership)

**Prerequisites:** Story 5.6

**Technical Notes:**
- Ash relationships: belongs_to, has_many, many_to_many
- Foreign key constraints with ON DELETE CASCADE for hierarchical integrity
- Junction tables: reseller_merchants, store_customers

---

### Story 5.8: Entity Seed Data

As a developer,
I want comprehensive seed data for all entity types,
So that I can test complete hierarchy.

**Acceptance Criteria:**

**Given** I run `mix run priv/repo/seeds.exs`
**Then** all entity types have sample data:
  - Tenant "Acme" with schema acq_acme
  - Developer "Alice Dev" in Acme
  - Reseller "Partner Resellers" in Acme
  - Merchant "Bob's Burgers" with subdomain
  - Store "North Location" (path-based) and "South Location" (subdomain)
  - Customer "Charlie Customer" registered
  - Vendor "Sysco Foods" registered

**Prerequisites:** Story 5.7

**Technical Notes:**
- Seed file: priv/repo/seeds/entities.exs
- Create entities in hierarchical order (tenant → developer/reseller/merchant → store/customer/vendor)
- Assign user_profiles for each entity user

---

### Story 5.9: Hierarchical Permission Inheritance

As a platform,
I want permissions to inherit down hierarchy,
So that parent entity admins can manage child entities.

**Acceptance Criteria:**

**Given** I am a tenant admin
**When** permission check runs
**Then** I have full permissions on all child entities (developers, resellers, merchants)

**Given** I am a merchant admin
**When** permission check runs
**Then** I have full permissions on all child entities (stores, customers, vendors)
**And** I do NOT have permissions on sibling merchants

**Prerequisites:** Story 5.8

**Technical Notes:**
- Ash policy helpers: has_permission_on_child?/2
- Permission checks traverse hierarchy upward
- Implement in Ash policies with expr(tenant_id == ^actor(:tenant_id))

---

### Story 5.10: All Entity Types Test Coverage

As a developer,
I want complete test coverage for all entity types,
So that hierarchy is reliable.

**Acceptance Criteria:**

**Given** all entity types epic is complete
**When** I run `mix test test/mcp/domains/`
**Then** all tests pass with 100% coverage including:
  - Entity creation for all 8 types
  - Relationship integrity (FK constraints, cascade deletes)
  - Hierarchical permissions
  - Subdomain routing for merchants and stores
  - Self-registration for customers and vendors only

**Prerequisites:** Story 5.9

**Technical Notes:**
- Test files per domain: developers_test.exs, resellers_test.exs, merchants_test.exs, stores_test.exs, customers_test.exs, vendors_test.exs
- Factory: All entity types
- Integration tests: Full hierarchy creation

---

## Epic 6: Teams, Permissions & Authorization

**Goal:** Fine-grained access control across entity hierarchy.

**User Value:** Admins can delegate responsibilities via teams with precise permissions and scopes.

**FRs Covered:** FR35-FR41, FR97, FR106

---

### Story 6.1: Teams Resource

As an entity admin,
I want to create teams,
So that I can organize users with shared permissions.

**Acceptance Criteria:**

**Given** I am a tenant admin
**When** I create a team "Support Team"
**Then** team record is created in platform.teams table
**And** team has name, description, permissions array
**And** team can be assigned to entity scopes (tenant + child entities)

**Prerequisites:** Epic 5 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/teams/team.ex
- Migration: priv/repo/migrations/XXXXX_create_teams.exs
- Table: platform.teams (id, name, description, permissions TEXT[], entity_type, entity_id, created_by_id, timestamps)
- Permissions: [:read, :write, :archive, :create_users, :create_teams, :manage_members, :create_api_keys, :manage_api_keys, :manage_webhooks]

---

### Story 6.2: Team Members

As an entity admin,
I want to add users to teams,
So that they inherit team permissions.

**Acceptance Criteria:**

**Given** I have a team "Support Team"
**When** I add user "Bob" to the team
**Then** team_member record is created in platform.team_members
**And** Bob inherits all team permissions
**And** Bob can access all entities in team's scope

**Prerequisites:** Story 6.1

**Technical Notes:**
- Ash resource: lib/mcp/domains/teams/team_member.ex
- Table: platform.team_members (id, team_id FK teams, user_profile_id FK user_profiles, role, added_by_id, timestamps)
- Junction table for many-to-many relationship

---

### Story 6.3: Team Scopes (Entity + Children)

As an entity admin,
I want to assign teams to entity scopes,
So that team permissions apply to entity and all child entities.

**Acceptance Criteria:**

**Given** I am tenant admin
**When** I assign team to tenant scope
**Then** team permissions apply to tenant + all developers, resellers, merchants

**Given** I am merchant admin
**When** I assign team to merchant scope
**Then** team permissions apply to merchant + all stores, customers, vendors
**And** team permissions do NOT apply to sibling merchants

**Prerequisites:** Story 6.2

**Technical Notes:**
- Table: platform.team_scopes (id, team_id FK teams, entity_type, entity_id, timestamps)
- Scope resolution: Check if entity is in hierarchy under team scope
- Helper: entity_in_scope?(entity, team_scopes)

---

### Story 6.4: Ash Policies for Authorization

As a developer,
I want Ash policies to enforce authorization,
So that resource-level access control is declarative.

**Acceptance Criteria:**

**Given** Ash policy is defined on resource
**When** user attempts action
**Then** policy is evaluated automatically
**And** action is allowed/denied based on policy rules

**Example policy:**
```elixir
policy action_type(:read) do
  authorize_if actor_attribute_equals(:is_admin, true)
  authorize_if team_has_permission(:read)
end
```

**Prerequisites:** Story 6.3

**Technical Notes:**
- Ash policies defined in each resource
- Custom checks: lib/mcp/domains/policies/checks.ex
- Checks: actor_attribute_equals, team_has_permission, entity_in_scope
- Policy failures return {:error, :forbidden}

---

### Story 6.5: Row-Level Security (RLS) Policies

As a database administrator,
I want RLS policies on shared entities,
So that database enforces access control.

**Acceptance Criteria:**

**Given** RLS policy is defined on platform.addresses
**When** user queries addresses
**Then** database only returns addresses user can access:
  - Own addresses (owner_type = 'user', owner_id = current_user_id)
  - Entity addresses (user has profile for entity)

**Prerequisites:** Story 6.4

**Technical Notes:**
- RLS policies in migrations for shared entities (addresses, emails, phones, documents, images, notes, todos)
- Use current_setting('app.current_user_id') to get user from session
- Set via: SET SESSION app.current_user_id = 'uuid'
- Helper function: platform.can_access_entity(user_id, entity_type, entity_id)

---

### Story 6.6: Field-Level Policies

As a platform,
I want field-level policies to restrict data visibility,
So that resellers see only payment data, not PII.

**Acceptance Criteria:**

**Given** reseller queries merchant resource
**When** Ash loads merchant
**Then** reseller sees only: id, name, slug, payment_volume, mids
**And** reseller does NOT see: customers, customer_count, product_data, PII

**Prerequisites:** Story 6.5

**Technical Notes:**
- Ash field policies:
  ```elixir
  field_policies do
    field_policy [:customers, :customer_count, :pii_fields] do
      forbid_if actor_attribute_equals(:role, :reseller)
    end
    field_policy [:id, :name, :slug, :payment_volume, :mids] do
      authorize_if actor_attribute_equals(:role, :reseller)
    end
  end
  ```

---

### Story 6.7: Permission Checks in UI

As a developer,
I want helper functions for permission checks in UI,
So that UI elements show/hide based on permissions.

**Acceptance Criteria:**

**Given** I am in a LiveView template
**When** I use permission helper
**Then** UI conditionally renders:
  - `<div :if={can?(@current_user, :create, @resource)}>Create</div>`
  - `<button :if={admin?(@current_user)}>Delete</button>`

**Prerequisites:** Story 6.6

**Technical Notes:**
- Helpers: lib/mcp_web/live/auth_helpers.ex
- Functions: can?(user, action, resource), admin?(user), developer?(user)
- Checks current_profile permissions + team permissions
- Import in LiveView: `use McpWeb, :live_view` includes helpers

---

### Story 6.8: Team Management UI

As an entity admin,
I want a team management interface,
So that I can create teams and manage members.

**Acceptance Criteria:**

**Given** I am an entity admin
**When** I navigate to /teams
**Then** I see list of all teams in my entity
**And** I can click "Create Team" to add new team
**And** team form has: name, description, permissions (checkboxes), scopes (multi-select)
**And** I can add/remove team members
**And** I can edit team permissions

**Prerequisites:** Story 6.7

**Technical Notes:**
- LiveView: lib/mcp_web/live/teams_live/index.ex, show.ex, form_component.ex
- DaisyUI: table, modal, checkbox group, multi-select
- Permissions checkboxes: All available permissions with descriptions
- Scopes multi-select: Entity + child entities in hierarchy

---

### Story 6.9: Team Seed Data

As a developer,
I want sample teams for testing,
So that I can test authorization scenarios.

**Acceptance Criteria:**

**Given** I run seeds
**Then** sample teams are created:
  - "Tenant Admins" (all permissions, tenant scope)
  - "Developers" (read + write, tenant scope, is_developer: true)
  - "Support Team" (read only, tenant + merchant scopes)
  - "Merchant Managers" (all permissions, merchant scope)

**Prerequisites:** Story 6.8

**Technical Notes:**
- Seed file: priv/repo/seeds/teams.exs
- Create teams for seed tenant "acme"
- Add seed users to teams as members

---

### Story 6.10: Authorization Test Coverage

As a developer,
I want complete test coverage for authorization,
So that security is guaranteed.

**Acceptance Criteria:**

**Given** authorization epic is complete
**When** I run `mix test test/mcp/policies/`
**Then** all tests pass with 100% coverage including:
  - Ash policies (allow, deny, field restrictions)
  - RLS policies (user can access own + entity data)
  - Field policies (reseller sees limited fields)
  - Team permissions (inherited correctly)
  - Hierarchical scopes (parent can access children)

**Prerequisites:** Story 6.9

**Technical Notes:**
- Test files: test/mcp/domains/policies_test.exs, test/mcp/multi_tenant/rls_test.exs
- Test all permission combinations
- Test policy failures return :forbidden
- Test RLS at database level with manual SQL queries

---

## Epic 7: User Invitations & Onboarding

**Goal:** Admins can invite users to entities with proper roles.

**User Value:** Admins can grow their teams by inviting users via email.

**FRs Covered:** FR42-FR49, FR98, FR107

---

### Story 7.1: Invitation Resource

As an entity admin,
I want to invite users via email,
So that they can join my entity.

**Acceptance Criteria:**

**Given** I am a tenant admin
**When** I invite "alice@example.com" as developer
**Then** invitation record is created in platform.invitations
**And** invitation has secure token (32 bytes, base64 encoded)
**And** invitation expires in 24 hours
**And** invitation contains: email, entity_type, entity_id, role, permissions

**Prerequisites:** Epic 6 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/invitations/invitation.ex
- Migration: priv/repo/migrations/XXXXX_create_invitations.exs
- Table: platform.invitations (id, email, entity_type, entity_id, role, permissions JSONB, token, invited_by_id, status, expires_at, accepted_at, timestamps)
- Token generation: :crypto.strong_rand_bytes(32) |> Base.url_encode64()

---

### Story 7.2: DeveloperInviteReactor Saga

As a platform,
I want invitation process to be a Reactor saga,
So that invitation workflow is reliable and transactional.

**Acceptance Criteria:**

**Given** admin invites a user
**When** DeveloperInviteReactor saga executes
**Then** saga steps execute in order:
  1. Check if user exists by email
  2. Create invitation record
  3. Generate secure token
  4. Send invitation email
  5. Schedule cleanup job (24 hours)
**And** if email send fails, saga does NOT fail (invitation still created)

**Prerequisites:** Story 7.1

**Technical Notes:**
- Reactor saga: lib/mcp/domains/invitations/developer_invite_reactor.ex
- Steps: check_existing_user, create_invitation, generate_token, send_email (async), schedule_cleanup (async)
- Email templates: "invitation_new_user" and "invitation_existing_user"
- Cleanup job: Oban worker Mcp.Workers.ExpiredInvitationCleaner

---

### Story 7.3: Invitation Email Templates

As a user,
I want to receive invitation emails,
So that I can accept invitations.

**Acceptance Criteria:**

**Given** invitation is sent
**When** email is delivered
**Then** email contains:
  - Inviting entity name and logo
  - Role being invited to (Developer, Admin, etc.)
  - "Accept Invitation" button linking to /invitations/accept?token=XXX
  - Expiration time (24 hours from now)
  - Different template for new vs existing users

**New user:** "You've been invited to join Acme Corp as a Developer. Create your account to get started."
**Existing user:** "You've been invited to join Acme Corp as a Developer. Sign in to accept."

**Prerequisites:** Story 7.2

**Technical Notes:**
- Email templates: lib/mcp_web/templates/email/invitation_new_user.html.heex, invitation_existing_user.html.heex
- Use Phoenix.Swoosh for email delivery
- SMTP config in runtime.exs
- Email library: Swoosh

---

### Story 7.4: Accept Invitation Flow

As an invited user,
I want to accept invitations,
So that I can access the entity.

**Acceptance Criteria:**

**Given** I receive invitation email
**When** I click "Accept Invitation" link
**Then** I am redirected to /invitations/accept?token=XXX
**And** if I'm not signed in, I see sign-in/registration form
**And** if I'm signed in, I see "Accept Invitation" confirmation page
**And** when I accept, user_profile is created for entity
**And** invitation status is set to "accepted"
**And** I am redirected to entity portal

**Given** invitation is expired (> 24 hours)
**When** I attempt to accept
**Then** I see "Invitation expired. Please request a new invitation."

**Prerequisites:** Story 7.3

**Technical Notes:**
- LiveView: lib/mcp_web/live/invitations_live/accept.ex
- Verify token validity (not expired, not already accepted)
- Create user_profile with permissions from invitation
- Set invitation.accepted_at = NOW(), status = "accepted"
- Send confirmation email: "Welcome to Acme Corp"

---

### Story 7.5: Revoke Pending Invitations

As an entity admin,
I want to revoke pending invitations,
So that I can cancel invitations that are no longer needed.

**Acceptance Criteria:**

**Given** I have sent an invitation
**When** I click "Revoke" on pending invitation
**Then** invitation status is set to "revoked"
**And** invitation can no longer be accepted
**And** attempting to accept shows "Invitation revoked"

**Prerequisites:** Story 7.4

**Technical Notes:**
- Ash action: :revoke_invitation
- Set status = "revoked", revoked_at = NOW(), revoked_by_id = current_user
- Accept flow checks: status == "pending" AND expires_at > NOW()

---

### Story 7.6: Refresh Expired Invitations

As an entity admin,
I want to refresh expired invitations,
So that I can resend them without creating duplicates.

**Acceptance Criteria:**

**Given** invitation is expired
**When** I click "Resend Invitation"
**Then** new token is generated
**And** expires_at is reset to 24 hours from now
**And** invitation email is resent
**And** old token is invalidated

**Prerequisites:** Story 7.5

**Technical Notes:**
- Ash action: :refresh_invitation
- Generate new token, set new expires_at
- Re-run send_email step of DeveloperInviteReactor
- Old token no longer valid (token updated)

---

### Story 7.7: Invitation Cleanup Job

As a platform,
I want expired invitations automatically cleaned up,
So that the database doesn't accumulate stale data.

**Acceptance Criteria:**

**Given** invitation is created
**When** 24 hours pass
**Then** Oban job runs to clean up expired invitation
**And** invitation status is set to "expired"
**And** old invitations (> 90 days, expired/revoked) are permanently deleted

**Prerequisites:** Story 7.6

**Technical Notes:**
- Oban worker: Mcp.Workers.ExpiredInvitationCleaner
- Scheduled on invitation creation (24 hours delay)
- Cron job: Clean up old invitations daily
- Permanent delete query: DELETE FROM invitations WHERE status IN ('expired', 'revoked', 'accepted') AND created_at < NOW() - INTERVAL '90 days'

---

### Story 7.8: Invitation Management UI

As an entity admin,
I want an invitation management interface,
So that I can send, view, and manage invitations.

**Acceptance Criteria:**

**Given** I am an entity admin
**When** I navigate to /invitations
**Then** I see list of all invitations (pending, accepted, expired, revoked)
**And** I can click "Invite User" to send new invitation
**And** invitation form has: email, role, permissions (checkboxes)
**And** I can revoke pending invitations
**And** I can resend expired invitations
**And** I see invitation status and expiration time

**Prerequisites:** Story 7.7

**Technical Notes:**
- LiveView: lib/mcp_web/live/invitations_live/index.ex, form_component.ex
- Table columns: Email, Role, Status, Expires, Actions (Revoke/Resend)
- Status badges: Pending (yellow), Accepted (green), Expired (gray), Revoked (red)
- DaisyUI: table, modal, badge

---

### Story 7.9: Invitation Seed Data

As a developer,
I want sample invitations for testing,
So that I can test invitation flows.

**Acceptance Criteria:**

**Given** I run seeds
**Then** sample invitations are created:
  - Pending invitation to "dev@example.com" as developer (valid)
  - Expired invitation to "old@example.com" (expired 25 hours ago)
  - Accepted invitation to "alice@example.com" (accepted yesterday)

**Prerequisites:** Story 7.8

**Technical Notes:**
- Seed file: priv/repo/seeds/invitations.exs
- Use DeveloperInviteReactor for realistic invitations
- Manually set expires_at for expired invitation (testing)

---

### Story 7.10: Invitation Test Coverage

As a developer,
I want complete test coverage for invitations,
So that invitation workflows are reliable.

**Acceptance Criteria:**

**Given** invitations epic is complete
**When** I run `mix test test/mcp/invitations/`
**Then** all tests pass with 100% coverage including:
  - Invitation creation (valid, duplicate email)
  - DeveloperInviteReactor saga (full flow, email failure)
  - Accept invitation (valid, expired, revoked)
  - Revoke invitation
  - Refresh invitation
  - Cleanup job (expire, permanent delete)

**Prerequisites:** Story 7.9

**Technical Notes:**
- Test file: test/mcp/domains/invitations_test.exs
- Integration test: Full invitation flow (create → email → accept → profile created)
- Test email delivery (use Swoosh.TestAdapter)
- Test Oban job execution

---

## Epic 8: Portal Routing & Context Resolution

**Goal:** Route users to appropriate portals based on subdomain and resolve entity context automatically.

**User Value:** Users access the right portal for their role with proper branding and context without manual configuration.

**FRs Covered:** FR50-FR60, FR95

---

### Story 8.1: McpWeb.ContextPlug - Subdomain Resolution

As a developer,
I want a plug that resolves entity context from subdomain,
So that the application knows which portal to render.

**Acceptance Criteria:**

**Given** a request arrives at platform.base.do
**When** ContextPlug executes
**Then** context is resolved to {type: :platform, entity: nil}
**And** conn.assigns.context = %{type: :platform, entity: nil, branding: default_platform_branding}

**Given** a request arrives at acme.base.do
**When** ContextPlug executes
**Then** context is resolved to {type: :tenant, entity: Tenant with slug "acme"}
**And** conn.assigns.context = %{type: :tenant, entity: tenant_struct, branding: tenant.branding}
**And** database query loads tenant by slug from subdomain

**Given** a request arrives at bobs-burgers.base.do
**When** ContextPlug executes
**Then** context is resolved to {type: :merchant, entity: Merchant with slug "bobs-burgers"}
**And** merchant tenant is preloaded for multi-tenant query context

**Given** a request arrives at customer.bobs-burgers.base.do
**When** ContextPlug executes
**Then** context is resolved to {type: :customer_portal, merchant: merchant_struct}
**And** third-level subdomain indicates portal type

**Given** subdomain doesn't match any entity
**When** ContextPlug executes
**Then** user sees 404 error "Organization not found"

**Prerequisites:** Epic 7 complete

**Technical Notes:**
- Plug: lib/mcp_web/plugs/context_plug.ex
- Runs early in pipeline (after :fetch_session, before :authenticate)
- Extract subdomain from conn.host via String.split(host, ".")
- Pattern matching:
  - platform.base.do → :platform
  - {slug}.base.do → :tenant (query platform.tenants)
  - {merchant_slug}.base.do → :merchant (query acq_{tenant}.merchants)
  - {portal}.{merchant_slug}.base.do → :customer_portal | :vendor_portal
  - {store_slug}.{merchant_slug}.base.do → :store_portal
- Cache tenant/merchant lookups in Redis (5 min TTL)
- Assign to conn: context, entity, branding
- Set Repo.put_dynamic_repo for tenant schema if needed

---

### Story 8.2: Platform Portal (platform.base.do)

As a platform administrator,
I want to access platform admin portal,
So that I can manage tenants and platform-level configuration.

**Acceptance Criteria:**

**Given** I am signed in as platform admin
**When** I navigate to platform.base.do
**Then** I see platform admin dashboard showing:
  - Total tenant count
  - Active tenant list
  - Platform health metrics
  - "Create Tenant" button
**And** navigation includes: Tenants, Users, System Settings, Audit Logs
**And** branding shows platform logo and theme

**Given** I am not a platform admin
**When** I attempt to access platform.base.do
**Then** I see "Access denied. Platform admin required."

**Prerequisites:** Story 8.1

**Technical Notes:**
- LiveView: lib/mcp_web/live/platform_live/dashboard.ex
- Layout: lib/mcp_web/components/layouts/platform.html.heex
- Authorization: Policy check require_platform_admin()
- Metrics: Query platform.tenants, platform.users counts
- Navigation component: lib/mcp_web/components/platform_nav.ex

---

### Story 8.3: Discovery Portal (app.base.do)

As a multi-context user,
I want a discovery portal showing all my contexts,
So that I can choose which organization to work with.

**Acceptance Criteria:**

**Given** I am signed in with multiple contexts
**When** I navigate to app.base.do
**Then** I see "Select Organization" page with grid of context cards
**And** each card shows:
  - Entity logo/icon
  - Entity name
  - My role badge (Admin, Developer, User)
  - Entity type badge (Tenant, Merchant, Store)
**And** clicking a card redirects to that entity's subdomain with context switch
**And** cards are sorted by: last_accessed DESC, then alphabetically

**Given** I have only one context
**When** I sign in
**Then** I am automatically redirected to that context (skip app.base.do)
**And** I never see discovery portal

**Given** I am not signed in
**When** I navigate to app.base.do
**Then** I am redirected to sign-in page

**Prerequisites:** Story 8.2

**Technical Notes:**
- LiveView: lib/mcp_web/live/discovery_live/index.ex
- Load all user_profiles for current user with preloaded entities
- Sort by last_accessed_at column (add to user_profiles table)
- Card component: DaisyUI card with hover:scale-105 transition
- Context switch via ContextSwitchReactor from Epic 4
- Update last_accessed_at on context switch

---

### Story 8.4: Tenant Portal ({tenant}.base.do)

As a tenant admin or user,
I want to access my tenant portal,
So that I can manage developers, resellers, and merchants.

**Acceptance Criteria:**

**Given** I am signed in with tenant context
**When** I navigate to acme.base.do
**Then** I see tenant dashboard showing:
  - Tenant name and branding
  - Developer count, Reseller count, Merchant count
  - Recent activity feed
  - Navigation: Dashboard, Developers, Resellers, Merchants, Teams, Settings
**And** page uses tenant's custom branding (logo, colors, DaisyUI theme)
**And** navigation shows context switcher if I have multiple contexts

**Given** I am tenant admin
**When** I view navigation
**Then** I see admin-only links: Teams, Settings, Invitations

**Given** I am not authorized for this tenant
**When** I attempt to access acme.base.do
**Then** I see "Access denied" error

**Prerequisites:** Story 8.3

**Technical Notes:**
- LiveView: lib/mcp_web/live/tenant_live/dashboard.ex
- Layout: lib/mcp_web/components/layouts/tenant.html.heex
- Authorization: Policy check has_profile_for_tenant?(user, tenant)
- Branding loaded from conn.assigns.context.branding
- Apply DaisyUI theme via data-theme attribute: <html data-theme={@branding.daisyui_theme}>
- Query counts from acq_{tenant} schema using MultiTenant.with_tenant_context/2

---

### Story 8.5: Developer Portal ({tenant}.base.do/developers)

As a developer,
I want to access developer portal,
So that I can manage API keys and integrations.

**Acceptance Criteria:**

**Given** I am signed in with is_developer: true for tenant
**When** I navigate to acme.base.do/developers
**Then** I see developer dashboard showing:
  - My API keys list
  - API documentation links
  - Integration guides
  - Webhook management
  - Navigation: Dashboard, API Keys, Webhooks, Docs
**And** path-based routing (not subdomain) for developer portal

**Given** I am not a developer
**When** I attempt to access /developers
**Then** I see "Developer access required"

**Given** I am tenant admin
**When** I view /developers
**Then** I see all developers' API keys (admin view)

**Prerequisites:** Story 8.4

**Technical Notes:**
- LiveView: lib/mcp_web/live/developer_live/dashboard.ex
- Layout: Same tenant layout, different navigation
- Authorization: Policy check current_profile.is_developer == true OR is_admin
- Path-based routing in router.ex: scope "/developers", DeveloperLive
- Context still resolved as :tenant, but portal_type: :developer

---

### Story 8.6: Reseller Portal ({tenant}.base.do/resellers)

As a reseller,
I want to access reseller portal,
So that I can manage my merchant portfolio and view payment data.

**Acceptance Criteria:**

**Given** I am signed in as reseller
**When** I navigate to acme.base.do/resellers
**Then** I see reseller dashboard showing:
  - My merchant portfolio (name, status, monthly volume)
  - Commission summary
  - Payment reports (aggregated data only, no PII)
  - Navigation: Dashboard, Merchants, Reports, Settings
**And** I can only see merchants assigned to me
**And** field-level policies hide customer PII and business data

**Given** I am not a reseller
**When** I attempt to access /resellers
**Then** I see "Reseller access required"

**Prerequisites:** Story 8.5

**Technical Notes:**
- LiveView: lib/mcp_web/live/reseller_live/dashboard.ex
- Authorization: Policy check entity_type == "reseller" OR is_admin
- Field-level policies from Epic 6 apply (only payment fields visible)
- Query only merchants linked to current reseller via reseller_merchants junction
- Path-based routing: scope "/resellers", ResellerLive

---

### Story 8.7: Merchant Portal ({merchant}.base.do)

As a merchant admin or user,
I want to access my merchant portal,
So that I can manage stores, customers, and products.

**Acceptance Criteria:**

**Given** I am signed in with merchant context
**When** I navigate to bobs-burgers.base.do
**Then** I see merchant dashboard showing:
  - Merchant branding and logo
  - Store count, Customer count, Order count
  - Recent orders list
  - Navigation: Dashboard, Stores, Customers, Vendors, Products, Orders, Settings
**And** page uses merchant's custom branding
**And** subdomain-based routing (separate subdomain per merchant)

**Given** I am merchant admin
**When** I view settings
**Then** I can configure branding, payment methods, custom domains

**Given** I am not authorized for this merchant
**When** I attempt to access merchant subdomain
**Then** I see "Access denied"

**Prerequisites:** Story 8.6

**Technical Notes:**
- LiveView: lib/mcp_web/live/merchant_live/dashboard.ex
- Layout: lib/mcp_web/components/layouts/merchant.html.heex
- Context resolution: ContextPlug resolves merchant from subdomain
- Branding cascade: merchant.branding overrides tenant.branding
- Tenant schema context set via MultiTenant.with_tenant_context(tenant_slug)
- Query from acq_{tenant}.merchants, stores, customers, etc.

---

### Story 8.8: Customer Portal (customer.{merchant}.base.do)

As a customer,
I want to access customer portal,
So that I can browse products and manage my orders.

**Acceptance Criteria:**

**Given** I am signed in as customer
**When** I navigate to customer.bobs-burgers.base.do
**Then** I see customer portal showing:
  - Product catalog
  - My orders list
  - My account settings
  - Shopping cart
  - Navigation: Shop, Orders, Account
**And** I can only see my own orders and data
**And** third-level subdomain indicates customer portal

**Given** I am not signed in AND merchant has customer_self_registration enabled
**When** I navigate to customer.{merchant}.base.do
**Then** I see customer sign-in page with "Create Account" link
**And** I can register or sign in

**Given** I am not signed in AND merchant has customer_self_registration disabled
**When** I navigate to customer.{merchant}.base.do
**Then** I see customer sign-in page WITHOUT "Create Account" link
**And** page shows "Contact {merchant_name} for access"

**Prerequisites:** Story 8.7

**Technical Notes:**
- LiveView: lib/mcp_web/live/customer_live/shop.ex, orders.ex
- Layout: lib/mcp_web/components/layouts/customer.html.heex
- Context resolution: ContextPlug detects "customer" prefix → :customer_portal
- RLS policies ensure customer sees only own data
- Self-registration controlled by merchant.settings.customer_self_registration (Story 2.9)
- Third-level subdomain pattern: {portal_type}.{merchant_slug}.base.do

---

### Story 8.9: Vendor Portal (vendor.{merchant}.base.do)

As a vendor,
I want to access vendor portal,
So that I can manage my products and inventory.

**Acceptance Criteria:**

**Given** I am signed in as vendor
**When** I navigate to vendor.bobs-burgers.base.do
**Then** I see vendor portal showing:
  - My product catalog
  - Inventory levels
  - Purchase orders from merchant
  - Navigation: Products, Inventory, Orders, Account
**And** I can only manage my own products
**And** third-level subdomain indicates vendor portal

**Given** I am not signed in AND merchant has vendor_self_registration enabled
**When** I navigate to vendor.{merchant}.base.do
**Then** I see vendor sign-in page with "Create Account" link
**And** I can register or sign in

**Given** I am not signed in AND merchant has vendor_self_registration disabled
**When** I navigate to vendor.{merchant}.base.do
**Then** I see vendor sign-in page WITHOUT "Create Account" link
**And** page shows "Contact {merchant_name} for access"

**Prerequisites:** Story 8.8

**Technical Notes:**
- LiveView: lib/mcp_web/live/vendor_live/products.ex, inventory.ex
- Layout: lib/mcp_web/components/layouts/vendor.html.heex
- Context resolution: ContextPlug detects "vendor" prefix → :vendor_portal
- RLS policies scope data to current vendor
- Self-registration controlled by merchant.settings.vendor_self_registration (Story 2.9)

---

### Story 8.10: Store Portal ({store}.{merchant}.base.do or /{store})

As a store manager,
I want to access store portal,
So that I can manage store-specific products and orders.

**Acceptance Criteria:**

**Given** I am signed in as store manager
**When** I navigate to north.bobs-burgers.base.do (subdomain store)
**Then** I see store-specific dashboard showing:
  - Store name and location
  - Store inventory
  - Store orders
  - Navigation: Dashboard, Inventory, Orders, Settings
**And** subdomain routing if store.routing_type == "subdomain"

**Given** store uses path-based routing
**When** I navigate to bobs-burgers.base.do/stores/north
**Then** same store portal is displayed
**And** path-based routing if store.routing_type == "path"

**Prerequisites:** Story 8.9

**Technical Notes:**
- LiveView: lib/mcp_web/live/store_live/dashboard.ex
- Context resolution: ContextPlug detects store subdomain OR /stores/:slug path
- Two routing strategies:
  1. Subdomain: {store_slug}.{merchant_slug}.base.do → query stores by subdomain field
  2. Path: {merchant_slug}.base.do/stores/:slug → query stores by slug
- Store routing_type field determines which strategy is used
- Premium feature: Subdomain routing ($5/month per store)

---

### Story 8.11: Branding Cascade System

As a developer,
I want branding to cascade from platform → tenant → merchant → store,
So that each entity can customize appearance while inheriting parent defaults.

**Acceptance Criteria:**

**Given** branding is defined at multiple levels
**When** page renders
**Then** branding cascade applies in order:
  1. Store branding (if store context)
  2. Merchant branding (if merchant/store context)
  3. Tenant branding (if tenant context)
  4. Platform branding (default)
**And** each level overrides parent's properties
**And** undefined properties inherit from parent

**Example:**
- Platform: logo_url: "platform.png", primary_color: "#000", daisyui_theme: "light"
- Tenant: primary_color: "#FF0000" (inherits logo and theme from platform)
- Merchant: logo_url: "merchant.png" (inherits primary_color from tenant, theme from platform)
- Final: logo_url: "merchant.png", primary_color: "#FF0000", daisyui_theme: "light"

**Prerequisites:** Story 8.10

**Technical Notes:**
- Module: lib/mcp_web/branding.ex
- Function: resolve_branding(context) returns merged branding map
- Branding fields: logo_url, favicon_url, primary_color, secondary_color, accent_color, font_family, daisyui_theme, custom_css, custom_js
- Apply in root layout: <html data-theme={@branding.daisyui_theme}>
- CSS variables: :root { --primary: #{@branding.primary_color}; }
- Cache resolved branding in conn.assigns after ContextPlug

---

### Story 8.12: Portal Routing Test Coverage

As a developer,
I want complete test coverage for portal routing,
So that context resolution is reliable.

**Acceptance Criteria:**

**Given** portal routing epic is complete
**When** I run `mix test test/mcp_web/plugs/context_plug_test.exs`
**Then** all tests pass with 100% coverage including:
  - Subdomain resolution (platform, tenant, merchant, customer, vendor, store)
  - Context assignment to conn
  - Branding cascade
  - Authorization checks per portal
  - 404 for unknown subdomains
  - Path-based vs subdomain-based store routing
**And** integration tests cover full request flow for each portal type

**Prerequisites:** Story 8.11

**Technical Notes:**
- Test file: test/mcp_web/plugs/context_plug_test.exs
- Test helper: build_conn_with_host(host) to simulate different subdomains
- Test all 8 portal types with proper fixtures
- Test branding inheritance with partial overrides
- Test authorization failures for each portal

---

## Epic 9: Polymorphic Shared Entities with RLS

**Goal:** Users and entities can create shared resources with automatic access control.

**User Value:** Users can attach addresses, emails, documents, notes to any entity with proper privacy.

**FRs Covered:** FR61-FR70

---

### Story 9.1: Addresses with PostGIS Geocoding

As a user or entity,
I want to create addresses with automatic geocoding,
So that location data is stored with coordinates.

**Acceptance Criteria:**

**Given** I am signed in
**When** I create an address with:
  - owner_type: "user", owner_id: current_user.id
  - address_type: "home"
  - line1: "123 Main St", city: "Portland", state: "OR", postal_code: "97201", country: "US"
**Then** address is created in platform.addresses
**And** PostGIS geocodes address to lat/lng coordinates
**And** location column stores GEOGRAPHY(POINT) type
**And** address is linked to owner via polymorphic association
**And** RLS policy allows me to read this address

**Given** address cannot be geocoded (invalid address)
**When** geocoding fails
**Then** address is still created with location = NULL
**And** validation warning shows "Could not geocode address"

**Prerequisites:** Epic 8 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/address.ex
- Migration: priv/repo/migrations/20250117000006_create_polymorphic_shared_entities.exs
- Table: platform.addresses (id, owner_type FK entity_types, owner_id, address_type FK address_types, line1, line2, city, state, postal_code, country, location GEOGRAPHY(POINT), metadata JSONB, timestamps)
- Geocoding: Use PostGIS geocoder OR external API (Google Maps, Mapbox)
- Function: geocode_address(address_struct) returns {lat, lng}
- Ash change: after_action :geocode_address
- RLS policy: CREATE POLICY address_access ON addresses FOR ALL USING (platform.can_access_owner(current_user_id(), owner_type, owner_id))

---

### Story 9.2: Emails with Type Classification

As a user or entity,
I want to create emails with type classification,
So that contact information is organized.

**Acceptance Criteria:**

**Given** I am signed in
**When** I create email with:
  - owner_type: "tenant", owner_id: tenant_id
  - email_type: "support"
  - email: "support@acme.com"
  - is_primary: true
**Then** email is created in platform.emails
**And** email format is validated (RFC 5322)
**And** RLS policy allows me to read this email if I belong to tenant

**Given** I create multiple emails for same owner
**When** I set is_primary: true on new email
**Then** previous primary email is automatically set to is_primary: false

**Prerequisites:** Story 9.1

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/email.ex
- Table: platform.emails (id, owner_type FK entity_types, owner_id, email_type FK email_types, email, is_primary, is_verified, verified_at, metadata JSONB, timestamps)
- Validation: Regex for email format or library (email_checker)
- Unique primary: Ash change unset_other_primary_emails before setting new primary
- RLS policy: Same pattern as addresses

---

### Story 9.3: Phones with Type Classification

As a user or entity,
I want to create phone numbers with type classification,
So that contact numbers are organized.

**Acceptance Criteria:**

**Given** I am signed in
**When** I create phone with:
  - owner_type: "merchant", owner_id: merchant_id
  - phone_type: "mobile"
  - phone: "+15035551234"
  - is_primary: true
  - sms_capable: true
**Then** phone is created in platform.phones
**And** phone format is validated (E.164 format)
**And** country code is extracted and stored
**And** RLS policy allows me to read this phone

**Prerequisites:** Story 9.2

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/phone.ex
- Table: platform.phones (id, owner_type FK entity_types, owner_id, phone_type FK phone_types, phone, country_code, is_primary, sms_capable, is_verified, verified_at, metadata JSONB, timestamps)
- Validation: E.164 format via ex_phone_number library
- Extract country code from phone number
- Unique primary pattern same as emails

---

### Story 9.4: Social Links

As a user or entity,
I want to create social media links,
So that profiles can show social presence.

**Acceptance Criteria:**

**Given** I am signed in
**When** I create social link with:
  - owner_type: "user_profile", owner_id: profile_id
  - platform: "twitter"
  - handle: "@johndoe"
  - url: "https://twitter.com/johndoe"
**Then** social link is created in platform.socials
**And** platform is validated against social_platforms lookup table
**And** URL format is validated
**And** RLS policy allows me to read this social link

**Prerequisites:** Story 9.3

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/social.ex
- Table: platform.socials (id, owner_type FK entity_types, owner_id, platform FK social_platforms, handle, url, is_verified, metadata JSONB, timestamps)
- Validation: URL format, platform exists in lookup table
- Icon/color loaded from social_platforms table for UI rendering

---

### Story 9.5: Images with S3/MinIO Storage

As a user or entity,
I want to upload images,
So that profiles and entities can have visual assets.

**Acceptance Criteria:**

**Given** I am signed in
**When** I upload image file (PNG, JPG, WebP, max 5MB)
**Then** image is uploaded to MinIO bucket
**And** image is resized to multiple sizes (thumbnail, medium, large)
**And** image record is created in platform.images with:
  - owner_type, owner_id
  - image_type: "avatar" | "logo" | "banner" | "product" | "gallery"
  - original_url, thumbnail_url, medium_url, large_url
  - file_size, mime_type, width, height
**And** RLS policy allows me to access this image

**Given** image exceeds 5MB
**When** I attempt upload
**Then** validation fails with "Image too large (max 5MB)"

**Prerequisites:** Story 9.4

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/image.ex
- Table: platform.images (id, owner_type FK entity_types, owner_id, image_type FK image_types, original_url, thumbnail_url, medium_url, large_url, file_size, mime_type, width, height, alt_text, metadata JSONB, timestamps)
- Storage: MinIO buckets (images-original, images-processed)
- Image processing: Mogrify or Vix for resizing
- Sizes: thumbnail (150x150), medium (500x500), large (1200x1200)
- Upload via Phoenix.LiveView.UploadConfig
- Cleanup: Delete from MinIO on record deletion

---

### Story 9.6: Documents with Encrypted Storage

As a user or entity,
I want to upload documents with encryption,
So that sensitive files are stored securely.

**Acceptance Criteria:**

**Given** I am signed in
**When** I upload document (PDF, DOCX, etc., max 25MB)
**Then** document is encrypted using Vault encryption service
**And** encrypted document is stored in MinIO
**And** document record is created in platform.documents with:
  - owner_type, owner_id
  - document_type: "kyc_id" | "contract" | "invoice" | etc.
  - file_name, file_size, mime_type, encrypted_url
  - encryption_key_id (reference to Vault key)
**And** RLS policy allows me to access this document

**Given** I download document
**When** request is made
**Then** document is decrypted on-the-fly
**And** decrypted content is streamed to client
**And** original encrypted file remains in storage

**Prerequisites:** Story 9.5

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/document.ex
- Table: platform.documents (id, owner_type FK entity_types, owner_id, document_type FK document_types, file_name, file_size, mime_type, encrypted_url, encryption_key_id, is_verified, metadata JSONB, timestamps)
- Encryption: Vault transit encryption engine
- Upload flow: Upload → Encrypt → Store encrypted
- Download flow: Fetch → Decrypt → Stream
- MinIO bucket: documents-encrypted
- Preview generation for PDFs (thumbnail of first page)

---

### Story 9.7: Todos with Assignment

As a user or entity,
I want to create todos,
So that tasks can be tracked per context.

**Acceptance Criteria:**

**Given** I am signed in in tenant context
**When** I create todo with:
  - owner_type: "tenant", owner_id: tenant_id
  - title: "Review merchant onboarding docs"
  - description: "Check all compliance requirements"
  - due_date: 2025-01-20
  - assigned_to_id: user_id
  - status: "pending"
**Then** todo is created in platform.todos
**And** todo appears in my todo list
**And** assigned user receives notification
**And** RLS policy allows owner and assigned user to access todo

**Prerequisites:** Story 9.6

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/todo.ex
- Table: platform.todos (id, owner_type FK entity_types, owner_id, created_by_id, assigned_to_id, title, description, status, priority, due_date, completed_at, metadata JSONB, timestamps)
- Status values: pending, in_progress, completed, cancelled
- Priority values: low, medium, high, urgent
- RLS policy: can_access_owner OR assigned_to_id = current_user_id
- Notification via Oban worker when assigned

---

### Story 9.8: Notes with Full-Text Search

As a user or entity,
I want to create notes with search capability,
So that information is easily discoverable.

**Acceptance Criteria:**

**Given** I am signed in
**When** I create note with:
  - owner_type: "merchant", owner_id: merchant_id
  - title: "Customer feedback from Q4"
  - content: "Customers requesting faster checkout flow..."
  - tags: ["feedback", "checkout", "ux"]
**Then** note is created in platform.notes
**And** note content is indexed in Meilisearch for full-text search
**And** I can search notes by keywords, title, tags
**And** RLS policy allows me to access note

**Given** I search for "checkout"
**When** search query runs
**Then** all notes containing "checkout" are returned
**And** results are ranked by relevance
**And** only notes I can access are returned (RLS + Meilisearch filtering)

**Prerequisites:** Story 9.7

**Technical Notes:**
- Ash resource: lib/mcp/domains/shared/note.ex
- Table: platform.notes (id, owner_type FK entity_types, owner_id, created_by_id, title, content TEXT, tags TEXT[], is_pinned, metadata JSONB, timestamps)
- Full-text search: Meilisearch integration
- Ash notification: after_action :index_in_meilisearch
- Meilisearch index: notes with fields: id, title, content, tags, owner_type, owner_id
- Meilisearch filter: ownerIds must match user's accessible entities
- Search function: Mcp.Search.search_notes(query, current_user)

---

### Story 9.9: RLS Policy Helper Functions

As a database administrator,
I want RLS helper functions,
So that access control is enforced at database level.

**Acceptance Criteria:**

**Given** RLS policies are enabled on shared entities
**When** query executes
**Then** database automatically filters results using:
  - platform.can_access_owner(user_id, owner_type, owner_id)
  - platform.get_user_entity_ids(user_id, entity_type)

**Function: can_access_owner(user_id, owner_type, owner_id)**
- Returns true if user_id matches owner_id AND owner_type = 'user'
- Returns true if user has profile for (owner_type, owner_id)
- Returns false otherwise

**Function: get_user_entity_ids(user_id, entity_type)**
- Returns array of entity_ids where user has profile of entity_type

**Prerequisites:** Story 9.8

**Technical Notes:**
- Migration: priv/repo/migrations/XXXXX_create_rls_helper_functions.exs
- SQL functions:
  ```sql
  CREATE OR REPLACE FUNCTION platform.can_access_owner(
    p_user_id UUID,
    p_owner_type TEXT,
    p_owner_id UUID
  ) RETURNS BOOLEAN AS $$
  BEGIN
    IF p_owner_type = 'user' AND p_owner_id = p_user_id THEN
      RETURN TRUE;
    END IF;

    RETURN EXISTS (
      SELECT 1 FROM platform.user_profiles
      WHERE user_id = p_user_id
        AND entity_type = p_owner_type
        AND entity_id = p_owner_id
        AND status = 'active'
    );
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  ```
- Set session user: SET SESSION app.current_user_id = 'uuid';
- RLS policies reference current_setting('app.current_user_id')::uuid

---

### Story 9.10: Polymorphic Shared Entities Test Coverage

As a developer,
I want complete test coverage for shared entities,
So that polymorphic associations and RLS work correctly.

**Acceptance Criteria:**

**Given** shared entities epic is complete
**When** I run `mix test test/mcp/domains/shared/`
**Then** all tests pass with 100% coverage including:
  - Address creation with geocoding
  - Email/phone creation with primary flag management
  - Social links, images, documents (upload, encryption, download)
  - Todos with assignment
  - Notes with full-text search
  - RLS policies (user can access own + entity data, user cannot access other user's data)
  - Polymorphic associations work for all entity types

**Prerequisites:** Story 9.9

**Technical Notes:**
- Test files: test/mcp/domains/shared/*_test.exs
- Test RLS at SQL level:
  - Set session user via SET SESSION
  - Query directly and verify filtered results
  - Test user A cannot see user B's data
  - Test user can see entity data if has profile
- Test image upload: Use bypass for MinIO in test
- Test document encryption: Mock Vault encryption service
- Test Meilisearch: Use sandbox mode or mock

---

## Epic 10: API Keys & Developer Portal Access

**Goal:** Developers can access platform APIs via secure API keys.

**User Value:** Developers can integrate with platform programmatically using properly scoped API keys.

**FRs Covered:** FR71-FR79

---

### Story 10.1: API Key Resource (Three-Tier Model)

As a platform,
I want three-tier API key model,
So that different entity types have appropriate access scopes.

**Acceptance Criteria:**

**Given** API key system exists
**When** I examine key structure
**Then** three key types are supported:
  1. **Developer keys** (tenant-scoped, tenant-defined permissions)
  2. **Merchant keys** (auto-scoped to own merchant, self-service)
  3. **Reseller keys** (auto-scoped to own reseller + assigned merchants)
**And** each key type has unique prefix: dev_ak_, merch_ak_, res_ak_
**And** keys expire after 90 days by default
**And** keys can be rotated by owner or admin

**Prerequisites:** Epic 9 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/api_keys/api_key.ex
- Migration: priv/repo/migrations/20250117000009_create_api_keys_and_teams.exs
- Table: platform.api_keys (id, key_type, key_prefix, hashed_key, entity_type, entity_id, created_by_id, name, description, permissions JSONB, scopes JSONB, expires_at, last_used_at, status, metadata JSONB, timestamps)
- Key types: developer, merchant, reseller
- Prefixes: dev_ak_{32_chars}, merch_ak_{32_chars}, res_ak_{32_chars}
- Key generation: :crypto.strong_rand_bytes(32) |> Base.url_encode64()
- Hash keys with bcrypt before storing (cost: 12)
- Store only hashed key, return plain key once on creation

---

### Story 10.2: Developer API Keys (Tenant-Scoped)

As a tenant admin,
I want to create developer API keys with custom permissions,
So that developers can integrate with our tenant's features.

**Acceptance Criteria:**

**Given** I am tenant admin
**When** I create developer API key with:
  - name: "Production API"
  - permissions: [:read_merchants, :read_transactions, :write_webhooks]
  - scopes: [tenant_id]
  - expires_at: 90 days from now
**Then** API key is created with prefix "dev_ak_"
**And** plain key is shown once: "dev_ak_abc123xyz..." (copy to clipboard)
**And** hashed key is stored in database
**And** developer can use key to authenticate API requests within tenant
**And** key permissions restrict which endpoints are accessible

**Given** developer API key has permission :read_merchants
**When** API request is made to GET /api/merchants
**Then** request is authorized and returns tenant merchants

**Given** developer API key lacks permission :write_merchants
**When** API request is made to POST /api/merchants
**Then** request is denied with 403 Forbidden

**Prerequisites:** Story 10.1

**Technical Notes:**
- Ash action: :create_developer_key (admin only)
- Permissions: Array of atoms [:read_merchants, :write_merchants, :read_transactions, :write_transactions, :read_customers, :write_customers, :manage_webhooks, :manage_api_keys]
- Scopes: Array of entity_ids developer can access (usually just tenant_id)
- API authentication: McpWeb.Plugs.ApiAuthPlug verifies API-Key header
- Permission checks: authorize_api_action(key, :read, :merchants)

---

### Story 10.3: Merchant API Keys (Self-Service, Auto-Scoped)

As a merchant,
I want to create my own API keys,
So that I can integrate my systems without tenant admin involvement.

**Acceptance Criteria:**

**Given** I am merchant admin
**When** I create merchant API key
**Then** API key is created with prefix "merch_ak_"
**And** key is automatically scoped to my merchant only (cannot be changed)
**And** permissions are fixed: [:read_own_data, :write_own_data, :manage_webhooks]
**And** I cannot access other merchants' data
**And** tenant admin cannot access my merchant key (privacy)

**Given** merchant API key exists
**When** API request is made to GET /api/products
**Then** only my merchant's products are returned
**And** query is automatically scoped via Ash policies

**Prerequisites:** Story 10.2

**Technical Notes:**
- Ash action: :create_merchant_key (merchant admin or self-service)
- Auto-scope: entity_type = "merchant", entity_id = current_merchant.id
- Fixed permissions: Merchant keys have preset permissions, not customizable
- Ash policies enforce merchant_id = actor(:merchant_id)
- Merchant cannot modify scope or permissions

---

### Story 10.4: Reseller API Keys (Portfolio-Scoped)

As a reseller,
I want API keys scoped to my merchant portfolio,
So that I can access payment data for merchants I manage.

**Acceptance Criteria:**

**Given** I am reseller
**When** I create reseller API key
**Then** API key is created with prefix "res_ak_"
**And** key is automatically scoped to my reseller + assigned merchants
**And** permissions are fixed: [:read_payment_data, :read_portfolio_merchants]
**And** field-level policies apply (no PII access)

**Given** reseller API key exists
**When** API request is made to GET /api/merchants
**Then** only merchants in my portfolio are returned
**And** only payment-related fields are included (no PII)

**Prerequisites:** Story 10.3

**Technical Notes:**
- Ash action: :create_reseller_key (reseller or admin)
- Auto-scope: entity_type = "reseller", entity_id = current_reseller.id, merchant_ids = portfolio_merchant_ids
- Fixed permissions: [:read_payment_data, :read_portfolio_merchants]
- Field-level policies from Epic 6 apply automatically
- Query joins reseller_merchants to filter portfolio

---

### Story 10.5: API Key Expiration & Rotation

As a developer or admin,
I want API keys to expire and be rotatable,
So that security is maintained over time.

**Acceptance Criteria:**

**Given** API key is created
**When** 90 days pass
**Then** key status is set to "expired"
**And** API requests using expired key return 401 Unauthorized with "API key expired"

**Given** I am key owner or admin
**When** I rotate API key
**Then** new key is generated with same permissions/scopes
**And** old key is revoked
**And** new key has new expiration (90 days from rotation)
**And** notification is sent to key owner and admins

**Given** non-admin developer rotates key
**When** rotation completes
**Then** admin receives notification: "Developer X rotated API key Y"

**Prerequisites:** Story 10.4

**Technical Notes:**
- Ash action: :rotate_key
- Rotation creates new key + revokes old key in single transaction
- Notification via Oban worker: Mcp.Workers.ApiKeyRotationNotifier
- Expiration check in ApiAuthPlug: IF expires_at < NOW() THEN return 401
- Oban cron job: Daily check for expiring keys (< 7 days), send warning email

---

### Story 10.6: API Key Management UI

As a user,
I want to manage my API keys,
So that I can create, view, rotate, and revoke keys.

**Acceptance Criteria:**

**Given** I am developer/merchant/reseller
**When** I navigate to API Keys page
**Then** I see list of my API keys showing:
  - Name, Created, Last Used, Expires, Status
  - Key prefix (dev_ak_***, merch_ak_***, res_ak_***)
  - Actions: Rotate, Revoke, View Details
**And** I can create new API key
**And** plain key is shown once after creation with "Copy" button
**And** I can rotate key (new key shown once)
**And** I can revoke key (confirmation required)

**Given** I am tenant admin
**When** I view API Keys admin page
**Then** I see all developer keys in my tenant
**And** I can revoke any key
**And** I can view key usage logs

**Prerequisites:** Story 10.5

**Technical Notes:**
- LiveView: lib/mcp_web/live/api_keys_live/index.ex, form_component.ex
- Show plain key in modal after creation (one-time display)
- Clipboard copy: JavaScript hook or LiveView JS command
- Revoke confirmation: DaisyUI modal with "Are you sure?"
- Usage logs: Query platform.api_key_usage_logs table (log each API request)

---

### Story 10.7: API Authentication Plug

As a developer,
I want API authentication via header,
So that programmatic access works seamlessly.

**Acceptance Criteria:**

**Given** I have valid API key
**When** I make API request with header `API-Key: dev_ak_abc123xyz...`
**Then** request is authenticated
**And** conn.assigns.api_key contains key struct
**And** conn.assigns.api_actor contains entity (tenant/merchant/reseller)
**And** last_used_at timestamp is updated
**And** usage is logged to api_key_usage_logs

**Given** API key is invalid (wrong key, expired, revoked)
**When** I make API request
**Then** request returns 401 Unauthorized with JSON: {"error": "Invalid API key"}

**Given** API key lacks required permission
**When** I attempt restricted action
**Then** request returns 403 Forbidden with JSON: {"error": "Insufficient permissions"}

**Prerequisites:** Story 10.6

**Technical Notes:**
- Plug: lib/mcp_web/plugs/api_auth_plug.ex
- Run in API pipeline: pipeline :api do plug :api_auth end
- Extract API-Key header: get_req_header(conn, "api-key")
- Hash incoming key and compare to stored hashed_key
- Load associated entity and permissions
- Set actor for Ash: Ash.PlugHelpers.set_actor(conn, api_actor)
- Log usage: Async Oban job to prevent blocking request
- Rate limiting: 1000 requests/hour per key via Hammer or similar

---

### Story 10.8: API Versioning (Header-Based)

As a platform,
I want header-based API versioning,
So that API evolution doesn't break existing integrations.

**Acceptance Criteria:**

**Given** API supports multiple versions
**When** I make API request with header `API-Version: 2025-01-17`
**Then** request is routed to version 2025-01-17 handlers
**And** response matches that version's schema

**Given** no API-Version header is provided
**When** I make API request
**Then** latest stable version is used by default

**Given** requested version is deprecated
**When** I make API request
**Then** request succeeds but response includes header: `Deprecation: true, Sunset: 2025-12-31`

**Prerequisites:** Story 10.7

**Technical Notes:**
- Header: API-Version (NOT path-based /v1/)
- Version format: YYYY-MM-DD (date-based, Stripe-style)
- Plug: lib/mcp_web/plugs/api_version_plug.ex
- Extract API-Version header, default to latest
- Route to versioned controllers: McpWeb.API.V20250117.MerchantController
- Version registry: lib/mcp_web/api/versions.ex with supported versions, deprecated versions, sunset dates
- Response headers: API-Version, Deprecation (if deprecated), Sunset (deprecation end date)

---

### Story 10.9: API Documentation

As a developer,
I want API documentation,
So that I can integrate with the platform.

**Acceptance Criteria:**

**Given** I am developer
**When** I navigate to {tenant}.base.do/developers/docs
**Then** I see comprehensive API documentation with:
  - Authentication guide (API key setup)
  - Endpoint reference (all available endpoints grouped by resource)
  - Request/response examples
  - Error codes and handling
  - Rate limits
  - Versioning guide
  - Code examples (curl, Python, JavaScript, Ruby)
**And** documentation is searchable
**And** "Try it" interactive console for testing endpoints

**Prerequisites:** Story 10.8

**Technical Notes:**
- Documentation tool: ExDoc or custom Phoenix page
- OpenAPI spec: Generate from Ash resources using AshJsonApi
- OpenAPI file: priv/static/openapi.yaml
- Render with: Redoc, Swagger UI, or Stoplight Elements
- Interactive console: Embedded Postman-like tool or custom LiveView
- Code examples: Generate from OpenAPI spec using openapi-generator
- Host at: McpWeb.DeveloperLive.DocsController

---

### Story 10.10: API Keys Test Coverage

As a developer,
I want complete test coverage for API keys,
So that API security is guaranteed.

**Acceptance Criteria:**

**Given** API keys epic is complete
**When** I run `mix test test/mcp/api_keys/`
**Then** all tests pass with 100% coverage including:
  - Key creation (all three types)
  - Key authentication (valid, invalid, expired, revoked)
  - Permission checks (authorized, denied)
  - Key rotation (new key, old revoked, notifications)
  - Scope enforcement (tenant, merchant, reseller)
  - Field-level policies for reseller keys
  - API versioning (header routing, default version)

**Prerequisites:** Story 10.9

**Technical Notes:**
- Test files: test/mcp/domains/api_keys_test.exs, test/mcp_web/plugs/api_auth_plug_test.exs
- Test API requests: Use Plug.Test to build conn with API-Key header
- Factory: :developer_api_key, :merchant_api_key, :reseller_api_key
- Test rate limiting: Exceed 1000 requests, verify 429 Too Many Requests
- Test usage logging: Verify log entries created

---

## Epic 11: Custom Domains & SSL Management

**Goal:** Tenants and merchants can use custom domains with automatic SSL provisioning.

**User Value:** White-label experience with custom branded domains and secure HTTPS.

**FRs Covered:** FR80-FR89

---

### Story 11.1: Custom Domain Resource

As a tenant or merchant admin,
I want to add custom domains,
So that users can access my portal at my branded domain.

**Acceptance Criteria:**

**Given** I am tenant admin
**When** I add custom domain "portal.acmepayments.com"
**Then** custom domain record is created in platform.custom_domains with:
  - entity_type: "tenant", entity_id: tenant_id
  - domain: "portal.acmepayments.com"
  - status: "pending_verification"
  - dns_challenge_type: "TXT"
  - dns_challenge_value: "bmad_verify_abc123xyz..."
  - verification_instructions displayed
**And** domain format is validated (valid FQDN, no subdomains of base.do)
**And** domain uniqueness is enforced (globally unique across all entities)

**Given** domain is already in use
**When** I attempt to add it
**Then** validation fails with "Domain already in use"

**Prerequisites:** Epic 10 complete

**Technical Notes:**
- Ash resource: lib/mcp/domains/custom_domains/custom_domain.ex
- Migration: priv/repo/migrations/XXXXX_create_custom_domains.exs (part of 20250117000009 or separate)
- Table: platform.custom_domains (id, entity_type FK entity_types, entity_id, domain, status, dns_challenge_type, dns_challenge_value, verified_at, ssl_certificate_id, ssl_provisioned_at, ssl_expires_at, ssl_renewal_scheduled_at, metadata JSONB, timestamps)
- Domain validation: Regex for FQDN, check not subdomain of .base.do
- Unique constraint on domain column
- Status values: pending_verification, verified, ssl_provisioning, active, failed, disabled

---

### Story 11.2: DNS Verification Challenge

As a tenant/merchant admin,
I want DNS verification instructions,
So that I can prove domain ownership.

**Acceptance Criteria:**

**Given** I add custom domain "portal.acmepayments.com"
**When** domain record is created
**Then** I see verification instructions:
  - "Add the following TXT record to your DNS:"
  - Record type: TXT
  - Host: _bmad-verify.portal.acmepayments.com
  - Value: bmad_verify_abc123xyz...
  - TTL: 300 (5 minutes)
**And** instructions include links to DNS provider help (Cloudflare, Route53, Namecheap guides)
**And** "Verify DNS" button to trigger verification check

**Prerequisites:** Story 11.1

**Technical Notes:**
- DNS challenge generation: :crypto.strong_rand_bytes(32) |> Base.url_encode64()
- Challenge prefix: bmad_verify_
- TXT record host: _bmad-verify.{domain}
- Store challenge in dns_challenge_value column
- Verification trigger starts ProvisionReactor saga

---

### Story 11.3: ProvisionReactor Saga (DNS Verification)

As a platform,
I want DNS verification automated via Reactor saga,
So that domain provisioning is reliable.

**Acceptance Criteria:**

**Given** user clicks "Verify DNS"
**When** ProvisionReactor saga executes
**Then** saga steps execute:
  1. Query DNS for TXT record (_bmad-verify.{domain})
  2. Verify TXT value matches dns_challenge_value
  3. If valid, set status: "verified", verified_at: NOW()
  4. If invalid, retry up to 3 times with 30-second delay
  5. If all retries fail, set status: "failed", log error
**And** saga is idempotent (can be retried safely)

**Prerequisites:** Story 11.2

**Technical Notes:**
- Reactor saga: lib/mcp/domains/custom_domains/provision_reactor.ex
- DNS lookup: Use :inet_res.nslookup/3 or dns library (dns_cluster)
- Query: :inet_res.nslookup('_bmad-verify.portal.acmepayments.com', :in, :txt)
- Parse TXT records, find matching challenge
- Retry logic: Reactor step with max_retries: 3, retry_delay: 30_000
- Compensate function: Set status to "failed" on final failure
- Async: Run via Oban worker for background processing

---

### Story 11.4: SSL Certificate Provisioning (Let's Encrypt ACME)

As a platform,
I want automatic SSL certificate provisioning,
So that custom domains are secure without manual intervention.

**Acceptance Criteria:**

**Given** DNS verification succeeds
**When** ProvisionReactor continues to SSL provisioning step
**Then** SSL certificate is requested from Let's Encrypt via ACME protocol
**And** ACME HTTP-01 challenge is completed:
  - Serve /.well-known/acme-challenge/{token} with key authorization
**And** certificate is issued and stored
**And** certificate is installed on load balancer/reverse proxy
**And** status is set to "active"
**And** ssl_expires_at is set (90 days from now)

**Given** ACME challenge fails
**When** SSL provisioning step executes
**Then** saga retries ACME flow
**And** if all retries fail, status is set to "failed", admin is notified

**Prerequisites:** Story 11.3

**Technical Notes:**
- ACME client: :acme library for Elixir or :letsencrypt_erlang
- ACME challenge: HTTP-01 (serve token at /.well-known/acme-challenge/{token})
- McpWeb.ACMEController handles challenge responses
- Certificate storage: Store cert + private key in Vault
- Certificate installation:
  - Option 1: Update Nginx/HAProxy config, reload
  - Option 2: Cloudflare API (upload cert)
  - Option 3: Kubernetes Ingress annotation
- Compensate function: Delete partial cert data on failure

---

### Story 11.5: Routing Configuration (Nginx/HAProxy/CloudFlare)

As a platform,
I want custom domain routing configured automatically,
So that traffic reaches the correct entity portal.

**Acceptance Criteria:**

**Given** SSL certificate is provisioned
**When** routing configuration step executes
**Then** routing is configured:
  - Nginx: Add server block for custom domain → proxy_pass to Phoenix app with X-Forwarded-Host header
  - HAProxy: Add frontend/backend for custom domain
  - CloudFlare: DNS A/CNAME record pointing to platform IP + SSL enabled
**And** McpWeb.CustomDomainPlug resolves custom domain to entity context
**And** request to portal.acmepayments.com routes to tenant "acme" portal

**Prerequisites:** Story 11.4

**Technical Notes:**
- Routing plugin: Choose based on deployment:
  - Nginx: Generate config file, reload: `nginx -s reload`
  - HAProxy: Update config, reload gracefully
  - CloudFlare: API call to create DNS record + SSL settings
- McpWeb.CustomDomainPlug: Similar to ContextPlug but queries custom_domains table
- Plug pipeline: CustomDomainPlug runs before ContextPlug
- If custom domain found: Set entity context from custom_domains.entity_type/entity_id
- If not found: Fall through to ContextPlug (subdomain resolution)

---

### Story 11.6: SSL Certificate Renewal (80-Day Schedule)

As a platform,
I want automatic SSL renewal,
So that certificates don't expire.

**Acceptance Criteria:**

**Given** SSL certificate is active
**When** 80 days pass (10 days before expiration)
**Then** Oban job triggers SSL renewal
**And** new certificate is requested from Let's Encrypt
**And** new certificate is installed, replacing old one
**And** ssl_expires_at is updated to new expiration date (90 days from renewal)
**And** routing is reloaded with new certificate

**Given** renewal fails
**When** retries are exhausted
**Then** admin receives urgent notification: "SSL renewal failed for portal.acmepayments.com"
**And** status is set to "renewal_failed"

**Prerequisites:** Story 11.5

**Technical Notes:**
- Oban worker: Mcp.Workers.SSLRenewal
- Scheduled on certificate provisioning: ssl_renewal_scheduled_at = ssl_expires_at - 10 days
- Renewal flow: Same ACME process as initial provisioning
- Graceful rollover: Install new cert, keep old until verified working, then remove old
- Retry logic: 3 attempts over 24 hours before alerting admin

---

### Story 11.7: DNS Validation (Daily Check)

As a platform,
I want daily DNS validation,
So that domain hijacking is detected immediately.

**Acceptance Criteria:**

**Given** custom domain is active
**When** daily DNS validation runs
**Then** DNS TXT record is checked for _bmad-verify.{domain}
**And** if TXT record is missing or changed, status is set to "verification_failed"
**And** admin receives notification: "DNS verification failed for portal.acmepayments.com - possible hijacking"
**And** domain is disabled (status: "disabled") to prevent misuse

**Given** DNS validation passes
**When** check completes
**Then** domain remains active
**And** last_validated_at timestamp is updated

**Prerequisites:** Story 11.6

**Technical Notes:**
- Oban cron job: Mcp.Workers.DailyDNSValidator (runs daily at 3 AM)
- Query all active custom domains
- For each: Query DNS TXT record, verify challenge value matches
- On failure: Set status to "disabled", send notification
- Re-verification: Admin can click "Re-verify DNS" to trigger ProvisionReactor again

---

### Story 11.8: McpWeb.CustomDomainPlug

As a developer,
I want custom domain resolution plug,
So that custom domains map to correct entity contexts.

**Acceptance Criteria:**

**Given** request arrives at portal.acmepayments.com
**When** CustomDomainPlug executes
**Then** custom domain is queried from platform.custom_domains
**And** if found and status == "active":
  - Load entity (tenant/merchant) from entity_type/entity_id
  - Set conn.assigns.context with entity
  - Set conn.assigns.branding with entity branding
  - Skip ContextPlug (already resolved)
**And** if not found or inactive:
  - Fall through to ContextPlug (subdomain resolution)

**Prerequisites:** Story 11.7

**Technical Notes:**
- Plug: lib/mcp_web/plugs/custom_domain_plug.ex
- Runs before ContextPlug in pipeline
- Query: Repo.get_by(CustomDomain, domain: conn.host, status: "active")
- Cache custom domain lookups in Redis (5 min TTL, invalidate on status change)
- If custom domain found: Set conn.private.custom_domain = true (skip ContextPlug)
- Load entity with preloads (branding, etc.)

---

### Story 11.9: Custom Domain Management UI

As a tenant/merchant admin,
I want to manage custom domains,
So that I can add, verify, and monitor domains.

**Acceptance Criteria:**

**Given** I am tenant/merchant admin
**When** I navigate to Settings > Custom Domains
**Then** I see list of custom domains showing:
  - Domain, Status, Verified Date, SSL Expires, Actions
**And** I can click "Add Custom Domain"
**And** domain form has: domain input, entity selection (if admin of multiple)
**And** after adding, I see verification instructions with DNS challenge
**And** I can click "Verify DNS" to trigger verification
**And** I can view SSL certificate details (issuer, expiration, renewal date)
**And** I can disable/enable domain
**And** I can delete domain (confirmation required)

**Prerequisites:** Story 11.8

**Technical Notes:**
- LiveView: lib/mcp_web/live/settings_live/custom_domains.ex
- Table columns: Domain, Status badge, Verified (date), SSL Expires (date + badge if < 30 days), Actions
- Status badges:
  - pending_verification (yellow)
  - verified (blue)
  - active (green)
  - failed (red)
  - disabled (gray)
- Verification modal shows DNS instructions + "Verify DNS" button
- SSL details modal shows certificate info from Vault

---

### Story 11.10: Custom Domains Test Coverage

As a developer,
I want complete test coverage for custom domains,
So that domain provisioning is reliable.

**Acceptance Criteria:**

**Given** custom domains epic is complete
**When** I run `mix test test/mcp/custom_domains/`
**Then** all tests pass with 100% coverage including:
  - Domain creation (valid, invalid, duplicate)
  - DNS verification (ProvisionReactor saga success, failure, retries)
  - SSL provisioning (ACME flow, certificate storage)
  - Routing configuration (Nginx/HAProxy/CloudFlare)
  - SSL renewal (schedule, success, failure notification)
  - Daily DNS validation (pass, fail, domain disabled)
  - CustomDomainPlug resolution (custom domain found, not found, inactive)

**Prerequisites:** Story 11.9

**Technical Notes:**
- Test files: test/mcp/domains/custom_domains_test.exs, test/mcp_web/plugs/custom_domain_plug_test.exs
- Mock DNS lookups: Use :meck or Mimic to mock :inet_res.nslookup
- Mock ACME client: Mock certificate issuance responses
- Test ProvisionReactor saga: Full flow + compensate functions
- Test Oban workers: SSL renewal, DNS validation
- Integration test: Full flow from domain add → DNS verify → SSL provision → routing → request handling

---

## Test Coverage Summary

**Total Phase 1 Test Requirements:**
- FR108: All authentication flows (Epic 2, Story 2.12)
- FR109: All multi-tenant operations (Epic 3, Story 3.8)
- FR110: All Reactor sagas (Distributed across stories 3.8, 7.10, 11.10)
- FR111: All authorization policies (Epic 6, Story 6.10)
- FR112: All portal routing (Epic 8, Story 8.12)

**Test Coverage by Epic:**
- Epic 1: Story 1.7 (Test infrastructure foundation)
- Epic 2: Story 2.12 (Authentication test coverage)
- Epic 3: Story 3.8 (Multi-tenancy test coverage)
- Epic 4: Story 4.10 (Entity-scoped profiles test coverage)
- Epic 5: Story 5.10 (All entity types test coverage)
- Epic 6: Story 6.10 (Authorization test coverage)
- Epic 7: Story 7.10 (Invitations test coverage)
- Epic 8: Story 8.12 (Portal routing test coverage)
- Epic 9: Story 9.10 (Polymorphic shared entities test coverage)
- Epic 10: Story 10.10 (API keys test coverage)
- Epic 11: Story 11.10 (Custom domains test coverage)

---

## Epic Completion Summary

**Phase 1 - Foundation Complete:**

✅ **Epic 1:** Foundation & Infrastructure Setup (7 stories)
✅ **Epic 2:** User Authentication & Session Management (12 stories)
✅ **Epic 3:** Multi-Tenancy & Schema Management (8 stories)
✅ **Epic 4:** Entity-Scoped User Profiles & Context Switching (10 stories)
✅ **Epic 5:** All Entity Types & Hierarchical Structure (10 stories)
✅ **Epic 6:** Teams, Permissions & Authorization (10 stories)
✅ **Epic 7:** User Invitations & Onboarding (10 stories)
✅ **Epic 8:** Portal Routing & Context Resolution (12 stories)
✅ **Epic 9:** Polymorphic Shared Entities with RLS (10 stories)
✅ **Epic 10:** API Keys & Developer Portal Access (10 stories)
✅ **Epic 11:** Custom Domains & SSL Management (10 stories)

**Total Stories: 109 stories implementing 112 functional requirements**

**All Functional Requirements (FR1-FR112) are now mapped to implementable stories.**

---

*This document is now complete and ready for Phase 1 implementation. Each epic contains detailed stories with acceptance criteria, prerequisites, and technical notes sufficient for development teams with zero codebase context.*

