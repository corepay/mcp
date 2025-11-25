defmodule Mcp.Platform do
  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Platform.Tenant
    resource Mcp.Platform.TenantSettings
    resource Mcp.Platform.TenantBranding
  end
end
