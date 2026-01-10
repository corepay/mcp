# Developer Guide: LLM Strategy

## Architecture

The LLM integration is built on a **Provider Abstraction** layer within the
`AgentRunner`. This allows the system to treat different LLM backends (Ollama,
OpenRouter) as interchangeable plugins.

### Core Components

- **AgentRunner**: The execution engine that handles prompt construction, LLM
  API calls, and response parsing. It implements the `execute_with_fallback/5`
  logic.
- **LlmUsage**: A dedicated Ash resource for tracking metrics. It is associated
  with every `Execution`.
- **AgentBlueprint**: Stores the `routing_config` that dictates how an agent
  should behave.

## Smart Routing Logic

The `AgentRunner` follows this flow:

1. **Primary Attempt**: Executes the prompt using the `primary_provider`
   (default: `:ollama`).
2. **Confidence Check**: Parses the JSON response for a `confidence` field
   (0.0 - 1.0).
3. **Fallback Trigger**: If confidence is below `min_confidence` (default: 0.8)
   OR if a JSON parsing error occurs:
   - Logs a warning.
   - **Fallback Attempt**: Re-executes the _same_ prompt using the
     `fallback_provider` (default: `:openrouter`).
4. **Tracking**: Records usage metrics (tokens, latency, cost) for the _final_
   successful provider (or the last failed attempt).

## Configuration

To configure an agent for smart routing, update its `AgentBlueprint`:

```elixir
blueprint = %AgentBlueprint{
  name: "Underwriter",
  routing_config: %{
    mode: :fallback,          # Enable fallback logic
    primary_provider: :ollama,
    fallback_provider: :openrouter,
    min_confidence: 0.9       # Strict confidence threshold
  }
}
```

## Adding New Providers

To add a new provider (e.g., Anthropic direct):

1. Update `Mcp.Ai.LlmUsage` resource to include the new provider atom.
2. Implement a `run_anthropic/3` function in `AgentRunner`.
3. Add a clause to `execute_provider/4` in `AgentRunner`.
