defmodule Mcp.Payments.Steps.UpdateRefundStatus do
  @moduledoc """
  Reactor step to update refund status based on gateway result.
  """
  use Reactor.Step

  def run(arguments, _context, _options) do
    refund = arguments.refund
    result = arguments.gateway_result

    if result.success do
      # Success
      params = %{
        provider_ref: result.data["transaction_id"] || result.data["id"]
      }

      refund
      |> Ash.Changeset.for_update(:succeed, params)
      |> Ash.update()
    else
      # Failure
      # We could store failure reason if we added it to the fail action
      refund
      |> Ash.Changeset.for_update(:fail, %{})
      |> Ash.update()
    end
  end
end
