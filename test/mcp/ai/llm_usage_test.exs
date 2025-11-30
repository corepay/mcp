defmodule Mcp.Ai.LlmUsageTest do
  use Mcp.DataCase

  alias Mcp.Ai.LlmUsage
  alias Mcp.Underwriting.Execution

  describe "llm_usages" do
    test "creates a usage record" do
      pipeline = Ash.create!(Mcp.Underwriting.Pipeline, %{name: "Test Pipeline"})
      
      execution = Ash.create!(Execution, %{
        pipeline_id: pipeline.id,
        subject_id: Ecto.UUID.generate(),
        subject_type: :individual,
        status: :pending
      })

      usage = Ash.create!(LlmUsage, %{
        execution_id: execution.id,
        provider: :ollama,
        model: "llama3",
        prompt_tokens: 10,
        completion_tokens: 20,
        total_tokens: 30,
        latency_ms: 100
      })

      assert usage.provider == :ollama
      assert usage.total_tokens == 30
      assert usage.execution_id == execution.id
    end
  end
end
