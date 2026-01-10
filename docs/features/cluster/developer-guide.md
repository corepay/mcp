# Developer Guide: Clustering

## Architecture

We use `libcluster` with the `LibclusterPostgres` strategy.

### How it Works

1.  **Registration**: When a node starts, it inserts a row into the `libcluster_postgres` table (created automatically) with its node name (e.g., `mcp@10.0.0.1`).
2.  **Discovery**: Nodes listen on a Postgres channel (`cluster` by default).
3.  **Heartbeat**: Nodes periodically update their "last seen" timestamp.
4.  **Pruning**: Stale nodes are removed from the table.
5.  **Connection**: When a new node is discovered via Postgres NOTIFY, the Erlang VM connects to it using standard Distributed Erlang.

## Configuration

### `mix.exs`

```elixir
{:libcluster_postgres, "~> 0.2"}
```

### `config/config.exs`

```elixir
config :libcluster,
  topologies: [
    postgres_cluster: [
      strategy: LibclusterPostgres.Strategy,
      config: [
        hostname: "localhost",
        username: "base_mcp_dev",
        password: "base_mcp_dev_password",
        database: "base_mcp_dev",
        port: 41789
      ]
    ]
  ]
```

### `lib/mcp/application.ex`

```elixir
children = [
  # ...
  {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies) || [], [name: Mcp.ClusterSupervisor]]},
  # ...
]
```

## Local Development

To test clustering locally:

1.  Start Node A:
    ```bash
    iex --sname a -S mix phx.server
    ```
2.  Start Node B:
    ```bash
    iex --sname b -S mix phx.server
    ```
3.  In Node A's console:
    ```elixir
    Node.list()
    # Should return [:b@hostname]
    ```

## Troubleshooting

*   **Nodes not connecting**: Ensure both nodes share the same **Erlang Cookie**. Check `RELX_COOKIE` env var or `~/.erlang.cookie`.
*   **Postgres Connection**: Ensure the database user has permissions to create tables (for the first run) and LISTEN/NOTIFY.
*   **Firewalls**: Ensure ports 4369 (EPMD) and the distribution port range are open between nodes.
