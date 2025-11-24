defmodule Mcp.Platform do
  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Platform.Tenant
  end
end
