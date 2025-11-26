defmodule Mcp.Payments.Gateways.Factory do
  @moduledoc """
  Factory to instantiate the correct payment gateway adapter.
  """

  @spec get_adapter(atom()) :: module()
  def get_adapter(:qorpay), do: Mcp.Payments.Gateways.QorPay
  # Placeholder
  def get_adapter(:stripe), do: Mcp.Payments.Gateways.Stripe
  def get_adapter(_), do: raise("Unknown payment provider")
end
