# Observability Developer Guide

## Introduction
This guide covers how to leverage the observability tools in the MCP Platform to monitor your features and optimize performance.

## Ash Telemetry

### 1. Automatic Instrumentation
All Ash Resources are automatically instrumented. You do not need to add manual `telemetry` calls for standard CRUD actions.

### 2. Custom Spans
If you have complex custom calculations or external API calls, you can wrap them in a span:

```elixir
:telemetry.span([:mcp, :custom_job], %{}, fn ->
  result = perform_complex_work()
  {result, %{tags: :metadata}}
end)
```

### 3. Viewing Metrics (Local)
In development, you can see telemetry events in the console logs if debug logging is enabled.

## Index Advisor

### 1. Usage
The `mix db.analyze` task is your primary tool for query optimization.

**Command**:
```bash
mix db.analyze "YOUR SQL QUERY HERE"
```

**Example Output**:
```text
Analyzing query...

Estimated Cost (Current): 120.5
Estimated Cost (Optimized): 5.2
Improvement: 95.6%

Suggested Indexes:
1. CREATE INDEX ON users (email);
```

### 2. When to Use
- **New Features**: Run analysis on your main read queries before merging a PR.
- **Slow Endpoints**: If an API endpoint is sluggish, capture the SQL query (via logs) and run it through the analyzer.

### 3. Applying Suggestions
If the advisor suggests an index:
1. Create a new migration: `mix ecto.gen.migration add_index_to_users`.
2. Add the index in the migration file.
3. Run `mix ecto.migrate`.
