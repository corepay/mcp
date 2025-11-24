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
  end

  pipeline :jwt_auth do
    plug McpWeb.Auth.SessionPlug, protected_routes: ["/dashboard", "/settings"]
  end

  pipeline :gdpr_auth do
    plug McpWeb.Auth.GdprAuthPlug,
      require_auth: true,
      audit_action: "GDPR_ACCESS",
      rate_limit: true
  end

  pipeline :gdpr_admin_auth do
    plug McpWeb.Auth.GdprAuthPlug,
      require_auth: true,
      require_admin: true,
      audit_action: "GDPR_ADMIN_ACCESS",
      rate_limit: true
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug McpWeb.ApiSecurityHeaders
  end

  pipeline :api_csrf do
    plug :accepts, ["json"]
    plug :protect_from_forgery
    plug McpWeb.ApiSecurityHeaders
  end

  scope "/", McpWeb do
    pipe_through :browser

    get "/", PageController, :home

    # SSL/ACME challenge routes (must be accessible without authentication)
    get "/.well-known/acme-challenge/:token", PageController, :acme_challenge

    # OAuth routes
    get "/auth/:provider", OAuthController, :authorize
    get "/auth/:provider/callback", OAuthController, :callback

    # Authentication routes
    live "/sign_in", AuthLive.Login, :index
    post "/sign_in", AuthController, :create
    delete "/sign_out", AuthController, :delete

    # Password change (special route for forced password changes)
    get "/change_password", ChangePasswordController, :show

    # Protected routes (require JWT authentication) - moved to separate scope
  end

  scope "/", McpWeb do
    pipe_through [:browser, :jwt_auth]

    get "/dashboard", PageController, :dashboard
    get "/settings", PageController, :settings
    get "/settings/security", PageController, :security_settings
    get "/settings/privacy", PageController, :privacy_settings

    # 2FA setup and management routes
    live "/2fa/setup", AuthLive.TwoFactorSetup, :index

    post "/oauth/link/:provider", OAuthController, :link
    get "/oauth/link/:provider/callback", OAuthController, :link_callback
    delete "/oauth/unlink/:provider", OAuthController, :unlink
    get "/oauth/provider/:provider", OAuthController, :provider_info
    get "/oauth/providers", OAuthController, :linked_providers
    post "/oauth/refresh/:provider", OAuthController, :refresh_token

    # GDPR routes (require authentication and audit logging)
    scope "/gdpr" do
      pipe_through :gdpr_auth

      live "/", GdprLive, :index
      get "/data-export", GdprController, :request_data_export
      post "/data-export", GdprController, :request_data_export
      get "/export/:export_id/status", GdprController, :get_export_status
      get "/export/:export_id/download", GdprController, :download_export
      post "/request-deletion", GdprController, :request_deletion
      post "/cancel-deletion", GdprController, :cancel_deletion
      get "/deletion-status", GdprController, :get_deletion_status
      get "/consent", GdprController, :get_consent
      post "/consent", GdprController, :update_consent
      get "/audit-trail", GdprController, :get_audit_trail
    end
  end

  # Tenant-specific routes (require tenant context)
  scope "/:tenant_schema", McpWeb do
    pipe_through [:browser, :jwt_auth]

    # Tenant settings
    live "/settings/live", TenantSettingsLive, :index
    live "/settings/live/:tab", TenantSettingsLive, :index
  end

  # API routes
  scope "/api", McpWeb do
    pipe_through :api

    # Health check endpoints (no authentication required for monitoring)
    get "/health", HealthController, :health
    get "/health/ready", HealthController, :ready
    get "/health/live", HealthController, :live
    get "/health/detailed", HealthController, :detailed

    # OAuth API endpoints
    get "/oauth/providers", OAuthController, :linked_providers
    get "/oauth/provider/:provider", OAuthController, :provider_info
    post "/oauth/refresh/:provider", OAuthController, :refresh_token

    # GDPR API endpoints (require authentication and audit logging)
    scope "/gdpr" do
      pipe_through [:gdpr_auth]

      # Read-only operations (no CSRF required)
      get "/export/:export_id/status", GdprController, :get_export_status
      get "/export/:export_id/download", GdprController, :download_export
      get "/deletion-status", GdprController, :get_deletion_status
      get "/consent", GdprController, :get_consent
      get "/audit-trail", GdprController, :get_audit_trail

      # State-changing operations (API token auth, no CSRF required)
      post "/data-export", GdprController, :request_data_export
      post "/export", GdprController, :export_data  # Additional route for tests
      post "/request-deletion", GdprController, :request_deletion
      post "/cancel-deletion", GdprController, :cancel_deletion
      post "/consent", GdprController, :update_consent

      # Data deletion endpoints
      delete "/data/:user_id", GdprController, :delete_user_data

      # Admin endpoints (require admin authentication and enhanced audit logging)
      scope "/admin" do
        pipe_through :gdpr_admin_auth

        # Admin read-only operations (no CSRF required)
        get "/compliance-report", GdprController, :admin_get_compliance_report
        get "/compliance", GdprController, :admin_get_compliance  # Additional route for tests
        get "/users/:user_id/data", GdprController, :admin_get_user_data

        # Admin state-changing operations (require CSRF protection and input validation)
        scope "/" do
          pipe_through :api_csrf

          post "/users/:user_id/delete", GdprController, :admin_delete_user
          post "/anonymize-overdue", GdprController, :admin_anonymize_overdue_users
        end
      end
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", McpWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mcp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: McpWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
