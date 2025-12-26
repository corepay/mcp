defmodule Mcp.Communication do
  @moduledoc """
  Domain for webhooks and external communication.
  """
  use Ash.Domain

  resources do
    resource Mcp.Communication.WebhookEndpoint
    resource Mcp.Communication.WebhookDelivery
  end
end
