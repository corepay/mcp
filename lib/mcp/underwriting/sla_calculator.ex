defmodule Mcp.Underwriting.SlaCalculator do
  @moduledoc """
  Calculates SLA deadlines for applications.
  """

  @default_sla_hours 4

  def calculate_due_at(submitted_at) do
    # Simple logic: submitted_at + 4 hours
    # Future: Handle business hours, weekends, holidays
    DateTime.add(submitted_at, @default_sla_hours, :hour)
  end
end
