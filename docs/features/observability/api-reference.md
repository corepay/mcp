# Observability API Reference

## Telemetry Events

The following events are emitted by the Ash Framework and available for capture.

### Ash Actions

| Event Name | Measurements | Metadata | Description |
| :--- | :--- | :--- | :--- |
| `[:ash, :action, :start]` | `system_time` | `resource`, `action`, `domain` | Emitted when an action starts. |
| `[:ash, :action, :stop]` | `duration` | `resource`, `action`, `domain`, `result` | Emitted when an action completes successfully. |
| `[:ash, :action, :exception]` | `duration` | `resource`, `action`, `domain`, `kind`, `reason` | Emitted when an action raises an exception. |

### Database (Ecto)

| Event Name | Measurements | Metadata | Description |
| :--- | :--- | :--- | :--- |
| `[:mcp, :repo, :query]` | `total_time`, `decode_time`, `query_time` | `query`, `source`, `params` | Emitted for every SQL query executed. |

## Mix Tasks

### `mix db.analyze`

Analyzes a SQL query and suggests indexes.

**Usage**: `mix db.analyze <query>`

**Arguments**:
- `<query>`: The SQL query string to analyze. Must be enclosed in quotes.
