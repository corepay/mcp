defmodule Mcp.Payments.Steps.ExecuteVoid do
  @moduledoc """
  Reactor step to execute a void transaction.
  """
  use Reactor.Step
  require Logger

  alias Mcp.Payments.Gateways.Factory

  def run(arguments, _context, _options) do
    provider = arguments.provider
    transaction_id = arguments.provider_ref

    adapter = Factory.get_adapter(provider)

    case adapter.void(transaction_id, %{}) do
      {:ok, result} ->
        {:ok, %{success: true, data: result, raw: result}}

      {:error, reason} ->
        {:ok, %{success: false, error: reason, raw: reason}}
    end
  end
end
