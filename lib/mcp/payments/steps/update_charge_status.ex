defmodule Mcp.Payments.Steps.UpdateChargeStatus do
  @moduledoc """
  Reactor step to update charge status based on gateway result.
  """
  use Reactor.Step
  require Logger

  def run(arguments, _context, _options) do
    charge = arguments.charge
    result = arguments.gateway_result
    action = Map.get(arguments, :action, :capture)

    if result.success do
      # Success
      charge
      |> Ash.Changeset.for_update(action, %{})
      |> Ash.update()
    else
      # Failure
      reason = inspect(result.error)

      charge
      |> Ash.Changeset.for_update(:fail, %{failure_reason: reason})
      |> Ash.update()
    end
  end
end
