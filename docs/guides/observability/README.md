# Observability & Performance

## Overview
The MCP Platform includes built-in observability tools to monitor application performance, track business metrics, and optimize database queries. This ensures high availability and allows for proactive performance tuning.

## Key Capabilities

### 1. Application Telemetry (Ash Telemetry)
- **Structured Events**: Automatically emits events for every Ash Action (create, read, update, destroy).
- **Granular Metrics**: Tracks duration, success/failure rates, and complexity of business logic.
- **Standard Integration**: Built on top of the Erlang `telemetry` standard, compatible with Prometheus, StatsD, and Honeycomb.

### 2. Database Performance (Index Advisor)
- **Query Analysis**: Analyzes SQL queries to identify missing indexes.
- **Cost Estimation**: Estimates the performance improvement of adding suggested indexes.
- **Hypothetical Indexes**: Uses `hypopg` to simulate indexes without modifying the database, ensuring safe analysis.

## Quick Start

### Checking Metrics
Metrics are emitted automatically. You can view them via the Phoenix Dashboard (if enabled) or your configured metrics backend.

### Analyzing a Query
To analyze a slow query and get index recommendations:

```bash
mix db.analyze "SELECT * FROM users WHERE email = 'test@example.com'"
```

## Related Resources
- [Core Platform Infrastructure](../core-platform/README.md)
