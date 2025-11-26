defmodule Mcp.Payments.Steps.CalculateAuditStatus do
  @moduledoc """
  Reactor step to calculate audit status from gateway result.
  """
  use Reactor.Step

  def run(arguments, _context, _options) do
    if arguments.gateway_result.success do
      {:ok, :success}
    else
      {:ok, :failure}
    end
  end
end
