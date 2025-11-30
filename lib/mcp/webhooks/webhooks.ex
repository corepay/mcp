defmodule Mcp.Webhooks do
  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Webhooks.Endpoint
    resource Mcp.Webhooks.Delivery
  end
end
