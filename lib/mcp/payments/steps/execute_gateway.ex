defmodule Mcp.Payments.Steps.ExecuteGateway do
  @moduledoc """
  Reactor step to execute a payment gateway transaction.
  """

  use Reactor.Step
  require Logger

  alias Mcp.Payments.Gateways.Factory

  def run(arguments, _context, _options) do
    provider = arguments.provider
    amount = arguments.amount
    currency = arguments.currency
    payment_method = arguments.payment_method
    customer = arguments.customer

    adapter = Factory.get_adapter(provider)

    # Construct source from payment_method
    source =
      %{}
      |> then(fn map ->
        if payment_method.provider_token,
          do: Map.put(map, :token, payment_method.provider_token),
          else: map
      end)
      |> Map.put(:payment_method, payment_method)

    context = %{
      charge_id: arguments.charge_id,
      customer: customer
    }

    case adapter.authorize(amount, currency, source, context) do
      {:ok, result} ->
        {:ok, %{success: true, data: result, raw: result}}

      {:error, reason} ->
        {:ok, %{success: false, error: reason, raw: reason}}
    end
  end
end
