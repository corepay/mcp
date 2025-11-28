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
    plug McpWeb.Auth.SessionPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug McpWeb.ApiSecurityHeaders
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
    
    live_session :admin_underwriting,
      on_mount: [{McpWeb.Auth.LiveAuth, :require_authenticated}, {McpWeb.Auth.LiveAuth, :require_admin}] do
      live "/underwriting", Admin.UnderwritingLive
      live "/underwriting/board", Admin.Underwriting.KanbanLive
      live "/underwriting/settings", Admin.Underwriting.SettingsLive
      live "/underwriting/:id", Admin.ReviewLive
    end
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

    live_session :ola_auth, on_mount: [{McpWeb.Auth.LiveAuth, :optional_auth}], session: %{"portal_context" => "ola"} do
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
  end

  # API Routes
  scope "/api", McpWeb do
    pipe_through :api

    get "/health", HealthController, :health
  end
end
