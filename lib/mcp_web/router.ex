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
    plug McpWeb.Auth.SessionPlug, protected_routes: ["/dashboard", "/settings"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug McpWeb.ApiSecurityHeaders
  end

  # Platform Admin Portal
  scope "/admin", McpWeb do
    pipe_through [:browser, :jwt_auth, :platform_admin_layout]
    
    live "/", Platform.DashboardLive
    live "/tenants", MockDashboardLive
    live "/settings", MockDashboardLive
  end

  # Tenant Portal
  scope "/tenant", McpWeb do
    pipe_through [:browser, :jwt_auth, :tenant_portal_layout]
    
    live "/", Tenant.DashboardLive
    live "/settings", TenantSettingsLive
    live "/merchants", MockDashboardLive
  end

  # Merchant Portal
  scope "/app", McpWeb do
    pipe_through [:browser, :jwt_auth, :merchant_portal_layout]
    
    live "/", MockDashboardLive
    live "/orders", MockDashboardLive
    live "/products", MockDashboardLive
    live "/customers", MockDashboardLive
  end

  pipeline :store_portal_layout do
    plug :put_layout, html: {McpWeb.Layouts.PortalLayouts, :store_portal}
  end

  # Store Portal
  scope "/app/stores/:store_slug", McpWeb do
    pipe_through [:browser, :jwt_auth, :store_portal_layout]
    
    live "/", MockDashboardLive
    live "/terminal", MockDashboardLive
    live "/invoices", MockDashboardLive
    live "/subscriptions", MockDashboardLive
  end

  # Developer Portal
  scope "/developers", McpWeb do
    pipe_through [:browser, :jwt_auth, :developer_portal_layout]
    
    live "/", MockDashboardLive
    live "/apps", MockDashboardLive
    live "/docs", MockDashboardLive
  end

  # Reseller Portal
  scope "/partners", McpWeb do
    pipe_through [:browser, :jwt_auth, :reseller_portal_layout]
    
    live "/", MockDashboardLive
    live "/merchants", MockDashboardLive
    live "/commissions", MockDashboardLive
  end

  # Customer Portal
  scope "/store/account", McpWeb do
    pipe_through [:browser, :jwt_auth, :customer_portal_layout]
    
    live "/", MockDashboardLive
    live "/orders", MockDashboardLive
    live "/profile", MockDashboardLive
  end

  # Vendor Portal
  scope "/vendors", McpWeb do
    pipe_through [:browser, :jwt_auth, :vendor_portal_layout]
    
    live "/", MockDashboardLive
    live "/products", MockDashboardLive
    live "/orders", MockDashboardLive
  end

  # Default/Public Routes
  scope "/", McpWeb do
    pipe_through :browser

    get "/", PageController, :home
    
    # Auth Routes
    live "/sign_in", AuthLive.Login, :index
    post "/sign_in", AuthController, :create
    delete "/sign_out", AuthController, :delete
  end

  # API Routes
  scope "/api", McpWeb do
    pipe_through :api
    
    get "/health", HealthController, :health
  end
end
