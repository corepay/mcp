defmodule Mcp.Underwriting.PlaybookTest do
  @moduledoc """
  Verifies the Playbook and PlaybookConcierge logic.
  """
  use Mcp.DataCase
  alias Mcp.Underwriting.{Playbook, PlaybookConcierge}

  setup do
    unique_id = System.unique_integer([:positive])
    schema = "acq_test_playbook_#{unique_id}"
    Mcp.Repo.query!("CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")

    # Simple DDL for playbooks table
    Mcp.Repo.query!("CREATE TABLE \"#{schema}\".underwriting_playbooks (
      id uuid PRIMARY KEY,
      name text,
      industry text,
      rules_markdown text,
      thresholds jsonb,
      hash text,
      is_active boolean,
      inserted_at timestamp(6),
      updated_at timestamp(6)
    )")

    {:ok, schema: schema}
  end

  test "creates a playbook and calculates hash", %{schema: schema} do
    playbook =
      Playbook
      |> Ash.Changeset.for_create(:create, %{
        name: "SaaS Conservative",
        industry: "SaaS",
        rules_markdown: "# Rules\n1. No high risk countries.",
        thresholds: %{auto_approve: 95, auto_reject: 40}
      })
      |> Ash.create!(tenant: schema, authorize?: false)

    assert playbook.hash != nil
    assert playbook.is_active == true

    # Verify update triggers hash change
    updated =
      playbook
      |> Ash.Changeset.for_update(:update, %{rules_markdown: "# Updated Rules"})
      |> Ash.update!(tenant: schema, authorize?: false)

    assert updated.hash != playbook.hash
  end

  # Skipping actual AI call in standard test suite if not on CI with Ollama
  @tag :external_api
  test "concierge suggests rules", %{schema: schema} do
    # This would normally call AshAi/Ollama
    # Since we are in a headless environment, we'd need a mock or just verify the action exists
    assert {:ok, _result} =
             PlaybookConcierge.suggest_rules(%{industry: "High-Risk Retail"},
               tenant: schema,
               authorize?: false
             )
  end
end
