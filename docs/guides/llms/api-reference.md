# API Reference: LLM Resources

## Resources

### Mcp.Ai.LlmUsage

Tracks the consumption and performance of LLM requests.

| Attribute           | Type    | Description                          |
| :------------------ | :------ | :----------------------------------- |
| `id`                | UUID    | Unique identifier                    |
| `execution_id`      | UUID    | ID of the associated Execution       |
| `provider`          | Atom    | `:ollama` or `:openrouter`           |
| `model`             | String  | Model name (e.g., "llama3", "gpt-4") |
| `prompt_tokens`     | Integer | Number of input tokens               |
| `completion_tokens` | Integer | Number of output tokens              |
| `total_tokens`      | Integer | Total tokens consumed                |
| `cost`              | Decimal | Estimated cost in USD                |
| `latency_ms`        | Integer | Request duration in milliseconds     |

### AgentBlueprint (Routing Config)

The `routing_config` attribute on `AgentBlueprint` controls the smart routing
behavior.

**Type**: `Map`

| Key                 | Type  | Default       | Description                                            |
| :------------------ | :---- | :------------ | :----------------------------------------------------- |
| `mode`              | Atom  | `:single`     | `:single` (no fallback) or `:fallback` (smart routing) |
| `primary_provider`  | Atom  | `:ollama`     | The first provider to attempt                          |
| `fallback_provider` | Atom  | `:openrouter` | The provider to use if primary fails/low confidence    |
| `min_confidence`    | Float | `0.8`         | Threshold (0.0-1.0) for triggering fallback            |

## Error Handling

The `AgentRunner` standardizes errors from all providers into a common format:

```elixir
{:ok, %{"error" => "Description of error"}}
```

If a fallback occurs, the error from the primary provider is logged, but the
final result returned to the `Orchestrator` will be the result of the fallback
attempt (success or error).
