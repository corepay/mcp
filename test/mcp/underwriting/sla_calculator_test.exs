defmodule Mcp.Underwriting.SlaCalculatorTest do
  use ExUnit.Case, async: true
  alias Mcp.Underwriting.SlaCalculator

  test "calculates due date 4 hours from submission" do
    submitted_at = DateTime.utc_now()
    due_at = SlaCalculator.calculate_due_at(submitted_at)
    
    diff = DateTime.diff(due_at, submitted_at, :hour)
    assert diff == 4
  end
end
