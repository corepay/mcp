defmodule Mcp.Ai.LlmUsageTest do
  use Mcp.DataCase

  alias Mcp.Ai.LlmUsage
  alias Mcp.Underwriting.Execution

  describe "llm_usages" do
    test "creates a usage record" do
      usage =
        Ash.create!(
          LlmUsage,
          %{
            provider: :ollama,
            model: "llama3",
            prompt_tokens: 10,
            completion_tokens: 20,
            total_tokens: 30,
            latency_ms: 100
          },
          authorize?: false
        )

      assert usage.provider == :ollama
      assert usage.total_tokens == 30
    end
  end
end
