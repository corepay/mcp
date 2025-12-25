defmodule Mcp.Webhooks do
  @moduledoc """
  Webhooks domain definition.
  """
  use Ash.Domain,
    otp_app: :mcp

  resources do
    resource Mcp.Webhooks.Endpoint
    resource Mcp.Webhooks.Delivery
  end
end
