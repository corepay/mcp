defmodule McpWeb.Router do
  use McpWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {McpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug McpWeb.TenantRouting
    plug McpWeb.Plugs.PutTenantInSession
    plug McpWeb.Plugs.ThemePlug
  end

  pipeline :platform_admin_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :platform_admin}
  end

  pipeline :tenant_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :tenant_portal}
  end

  pipeline :merchant_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :merchant_portal}
  end

  pipeline :developer_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :developer_portal}
  end

  pipeline :reseller_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :reseller_portal}
  end

  pipeline :customer_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :customer_portal}
  end

  pipeline :vendor_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :vendor_portal}
  end

  pipeline :jwt_auth do
    plug :fetch_session
    plug McpWeb.Auth.SessionPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug McpWeb.Plugs.ApiVersioning
    plug McpWeb.ApiSecurityHeaders
    plug McpWeb.Plugs.RequireApiKey
  end

  # Platform Admin Portal
  scope "/admin", McpWeb do
    pipe_through [:browser, :platform_admin_layout]

    live_session :admin_auth, session: %{"portal_context" => "admin"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/admin", McpWeb do
    pipe_through [:browser, :jwt_auth, :platform_admin_layout]

    live "/dashboard", Platform.DashboardLive
    live "/tenants", MockDashboardLive
    live "/settings", MockDashboardLive
  end

  # Tenant Portal
  scope "/tenant", McpWeb do
    pipe_through [:browser, :tenant_portal_layout]

    live_session :tenant_auth, session: %{"portal_context" => "tenant"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/tenant", McpWeb do
    pipe_through [:browser, :jwt_auth, :tenant_portal_layout]

    live "/dashboard", Tenant.DashboardLive
    live "/applications", Tenant.ApplicationsLive
    live "/applications/:id", Tenant.ApplicationDetailLive
    live "/settings", TenantSettingsLive
    live "/merchants", MockDashboardLive
    live "/gdpr", GdprLive
    live "/change-password", AuthLive.ChangePassword

    live_session :tenant_underwriting,
      on_mount: [{McpWeb.Auth.LiveAuth, :require_authenticated}] do
      live "/underwriting", Tenant.UnderwritingLive
      live "/underwriting/board", Tenant.Underwriting.KanbanLive
      live "/underwriting/settings", Tenant.Underwriting.SettingsLive
      live "/underwriting/:id", Tenant.ReviewLive
    end

    post "/select", TenantSessionController, :create
  end

  # Merchant Portal
  scope "/app", McpWeb do
    pipe_through [:browser, :merchant_portal_layout]

    live_session :merchant_auth, session: %{"portal_context" => "merchant"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/app", McpWeb do
    pipe_through [:browser, :jwt_auth, :merchant_portal_layout]

    live "/dashboard", MockDashboardLive
    live "/orders", MockDashboardLive
    live "/products", MockDashboardLive
    live "/customers", MockDashboardLive
  end

  pipeline :store_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :store_portal}
  end

  # Store Portal
  scope "/app/stores/:store_slug", McpWeb do
    pipe_through [:browser, :store_portal_layout]

    live_session :store_auth, session: %{"portal_context" => "store"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/app/stores/:store_slug", McpWeb do
    pipe_through [:browser, :jwt_auth, :store_portal_layout]

    live "/dashboard", MockDashboardLive
    live "/terminal", MockDashboardLive
    live "/invoices", MockDashboardLive
    live "/subscriptions", MockDashboardLive
  end

  # Developer Portal
  scope "/developers", McpWeb do
    pipe_through [:browser, :developer_portal_layout]

    live_session :developer_auth, session: %{"portal_context" => "developer"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/developers", McpWeb do
    pipe_through [:browser, :jwt_auth, :developer_portal_layout]

    live "/dashboard", MockDashboardLive
    live "/apps", MockDashboardLive
    live "/docs", MockDashboardLive
  end

  # Reseller Portal
  scope "/partners", McpWeb do
    pipe_through [:browser, :reseller_portal_layout]

    live_session :reseller_auth, session: %{"portal_context" => "reseller"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/partners", McpWeb do
    pipe_through [:browser, :jwt_auth, :reseller_portal_layout]

    live "/dashboard", MockDashboardLive
    live "/applications", Reseller.ApplicationsLive
    live "/applications/:id", Reseller.UnderwritingApplicationLive
    live "/merchants", MockDashboardLive
    live "/commissions", MockDashboardLive
  end

  # Customer Portal
  scope "/store/account", McpWeb do
    pipe_through [:browser, :customer_portal_layout]

    live_session :customer_auth, session: %{"portal_context" => "customer"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/store/account", McpWeb do
    pipe_through [:browser, :jwt_auth, :customer_portal_layout]

    live "/dashboard", MockDashboardLive
    live "/orders", MockDashboardLive
    live "/profile", MockDashboardLive
  end

  # Vendor Portal
  scope "/vendors", McpWeb do
    pipe_through [:browser, :vendor_portal_layout]

    live_session :vendor_auth, session: %{"portal_context" => "vendor"} do
      live "/sign-in", AuthLive.Login, :index
      live "/", LandingLive, :index
    end
  end

  scope "/vendors", McpWeb do
    pipe_through [:browser, :jwt_auth, :vendor_portal_layout]

    live "/dashboard", MockDashboardLive
    live "/products", MockDashboardLive
    live "/orders", MockDashboardLive
  end

  pipeline :ola_layout do
    plug :put_layout, html: {McpWeb.Layouts, :ola_layout}
  end

  # OLA (Online Application) Portal
  scope "/online-application", McpWeb do
    pipe_through [:browser, :ola_layout]

    live_session :ola_auth,
      on_mount: [{McpWeb.Auth.LiveAuth, :optional_auth}],
      session: %{"portal_context" => "ola"} do
      live "/", Ola.RegistrationLive, :index
      live "/application", Ola.ApplicationLive, :index
      live "/login", AuthLive.Login, :index
    end
  end

  # Default/Public Routes
  scope "/", McpWeb do
    pipe_through :browser

    live "/", LandingLive, :home

    # Auth Routes - Global sign-in removed in favor of scoped routes
    post "/sign-in", AuthController, :create
    delete "/sign-out", AuthController, :delete

    # Routes for tests
    live "/register", Ola.RegistrationLive, :index
    live "/password-reset", AuthLive.ChangePassword, :index
  end

  # API Routes
  scope "/api", McpWeb do
    pipe_through :api

    get "/health", HealthController, :health
  end

  scope "/api/gdpr", McpWeb do
    pipe_through [:api, :jwt_auth]

    post "/request-deletion", GdprController, :request_deletion
    post "/export", GdprController, :request_data_export
    get "/export/:token/status", GdprController, :get_export_status
    post "/consent", GdprController, :update_consent
    get "/consent", GdprController, :get_consent
    get "/audit-trail", GdprController, :get_audit_trail
    delete "/data/:id", GdprController, :delete_user_data
    get "/deletion-status", GdprController, :get_deletion_status
    get "/admin/compliance", GdprController, :admin_compliance
  end

  scope "/auth", McpWeb do
    pipe_through :api

    post "/register", AuthController, :register
    post "/login", AuthController, :login
    post "/logout", AuthController, :logout
    post "/refresh", AuthController, :refresh
    post "/verify-2fa", AuthController, :verify_2fa
    post "/forgot-password", AuthController, :forgot_password
    post "/reset-password", AuthController, :reset_password
  end

  scope "/auth", McpWeb do
    pipe_through :browser

    get "/:provider", OAuthController, :authorize
    get "/:provider/callback", OAuthController, :callback
  end

  scope "/oauth", McpWeb do
    pipe_through [:browser, :jwt_auth]

    delete "/unlink/:provider", OAuthController, :unlink
    get "/link/:provider", OAuthController, :link
    get "/link/:provider/callback", OAuthController, :link_callback
    get "/provider/:provider", OAuthController, :provider_info
    get "/providers", OAuthController, :linked_providers
    post "/refresh/:provider", OAuthController, :refresh_token
  end

  scope "/api", McpWeb do
    pipe_through :api

    # V1 Routes (Header-based versioning handled by controller namespace resolution or explicit routing)
    # For now, we map /assessments directly to Api.AssessmentController
    # In a full setup, we might use a macro to dispatch based on conn.assigns.api_version

    post "/assessments", Api.AssessmentController, :create
    get "/assessments/:id", Api.AssessmentController, :show

    post "/instruction_sets", Api.InstructionSetController, :create
    get "/instruction_sets/:id", Api.InstructionSetController, :show

    resources "/webhooks/endpoints", Api.WebhookController, except: [:new, :edit]

    # Payments API
    post "/payments", PaymentsController, :create
    get "/payments/:id", PaymentsController, :show
    post "/payments/forms/sessions", PaymentsController, :create_form_session
    post "/payments/boarding/merchants", PaymentsController, :create_merchant

    resources "/payment_methods", PaymentMethodsController, only: [:create, :show, :delete]

    # Customers API
    resources "/customers", CustomersController, only: [:create, :show, :delete]
    # Test uses POST for update?
    post "/customers/:id", CustomersController, :update

    post "/voids", VoidsController, :create
    post "/refunds", RefundsController, :create
    get "/refunds/:id", RefundsController, :show

    post "/webhooks/qorpay", WebhooksController, :handle_qorpay

    get "/payments/utilities/bin/:bin", PaymentsController, :bin_lookup
    get "/payments/transactions/:id", PaymentsController, :show_transaction

    get "/profile", AuthController, :profile
  end

  scope "/gdpr", McpWeb do
    pipe_through [:browser, :jwt_auth]

    post "/request-deletion", GdprController, :request_deletion
    post "/cancel-deletion", GdprController, :cancel_deletion
    get "/consent", GdprController, :get_consent
    post "/consent", GdprController, :update_consent
    get "/audit-trail", GdprController, :get_audit_trail
    get "/data-export", GdprController, :data_export_request
    post "/data-export", GdprController, :create_data_export
    get "/export/:token", GdprController, :download_export
  end

  # Dynamic tenant routes (must be last)
  scope "/:tenant_schema", McpWeb do
    pipe_through [:browser, :jwt_auth]

    get "/settings", TenantSettingsController, :index
    get "/settings/dashboard", TenantSettingsController, :dashboard
    get "/settings/import-export", TenantSettingsController, :import_export
    get "/settings/export", TenantSettingsController, :export_settings
    post "/settings/import", TenantSettingsController, :import_settings

    # Specific settings pages
    get "/settings/features", TenantSettingsController, :features
    post "/settings/features/:feature", TenantSettingsController, :toggle_feature
    get "/settings/branding", TenantSettingsController, :branding
    put "/settings/branding", TenantSettingsController, :update_branding

    # Category routes (catch-all for settings)
    get "/settings/:category", TenantSettingsController, :show_category
    put "/settings/:category", TenantSettingsController, :update_category
    get "/settings/:category/edit", TenantSettingsController, :edit_category
  end
end
