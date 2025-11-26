defmodule Mcp.Payments do
  @moduledoc """
  Ash Domain for the Payments context.
  """

  use Ash.Domain,
    otp_app: :mcp

  resources do
    # Core Resources
    resource Mcp.Payments.Charge
    resource Mcp.Payments.Refund
    resource Mcp.Payments.Customer
    resource Mcp.Payments.PaymentMethod
    resource Mcp.Payments.GatewayTransaction
  end
end
