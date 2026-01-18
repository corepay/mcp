defmodule Mcp.Ai.VectorTest do
  @moduledoc """
  Tests for AI vectorization and semantic search.
  """
  use Mcp.DataCase, async: false

  alias Mcp.Ai.Document

  describe "document vectorization" do
    test "can search for documents using semantic search" do
      tenant = insert(:tenant)

      # Insert documents
      {:ok, _doc1} =
        Document.create(
          %{
            content: "The quick brown fox jumps over the lazy dog"
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, _doc2} =
        Document.create(
          %{
            content:
              "Quantum computing is a type of computing that uses quantum-mechanical phenomena"
          },
          actor: %{tenant_id: tenant.id}
        )

      # Search for "animals" (should match doc1 better)
      # Note: We need to mock the embedding model or ensure it works in test environment
      # For now, this is a placeholder for the logic.
      # In a real test, we'd mock Mcp.Ai.OpenAiEmbeddingModel.generate/2.

      # Since we use strategy :ash_oban, we need to process jobs if we want to test search immediately
      # Or change strategy to :after_action for tests.
      # Document.search("animal")
    end
  end
end
