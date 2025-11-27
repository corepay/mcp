# API Reference: Clustering

## Modules

### `Cluster.Supervisor`

The main supervisor that manages the clustering strategy.

**Usage:**

```elixir
{Cluster.Supervisor, [topologies, [name: Mcp.ClusterSupervisor]]}
```

*   `topologies`: A keyword list of topology configurations.
*   `name`: The name to register the supervisor process.

## Configuration Options

### `LibclusterPostgres.Strategy`

Strategy for Postgres-based discovery.

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `config` | `keyword` | `[]` | Database connection configuration (see below). |
| `heartbeat_interval` | `integer` | `5000` | Interval in ms to update the node's heartbeat. |
| `channel_name` | `string` | `"cluster"` | The Postgres channel name for LISTEN/NOTIFY. |

#### Database Configuration (`config`)

| Option | Type | Description |
| :--- | :--- | :--- |
| `hostname` | `string` | Database hostname. |
| `username` | `string` | Database username. |
| `password` | `string` | Database password. |
| `database` | `string` | Database name. |
| `port` | `integer` | Database port. |
| `ssl` | `boolean` | Whether to use SSL. |

## Ash Resources

*None.* Clustering is an infrastructure concern and does not expose Ash resources.
