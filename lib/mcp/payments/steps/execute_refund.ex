defmodule Mcp.Payments.Steps.ExecuteRefund do
  @moduledoc """
  Reactor step to execute a refund transaction.
  """
  use Reactor.Step
  require Logger

  alias Mcp.Payments.Gateways.Factory

  def run(arguments, _context, _options) do
    provider = arguments.provider
    amount = arguments.amount
    transaction_id = arguments.provider_ref

    adapter = Factory.get_adapter(provider)

    case adapter.refund(transaction_id, amount, %{}) do
      {:ok, result} ->
        {:ok, %{success: true, data: result, raw: result}}

      {:error, reason} ->
        {:ok, %{success: false, error: reason, raw: reason}}
    end
  end
end
