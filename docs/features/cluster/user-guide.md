# User Guide: Clustering Operations

## Overview

This guide explains how to operate and monitor the application cluster.

## Monitoring the Cluster

### Checking Connected Nodes

You can check which nodes are currently connected via the remote console.

1.  **Connect to a running node**:
    ```bash
    # If running via Docker/Release
    bin/mcp remote_console
    ```
2.  **Run the check**:
    ```elixir
    Node.list()
    # Returns: [:"mcp@10.0.0.2", :"mcp@10.0.0.3"]
    ```
    If the list is empty `[]`, the node is isolated.

### Database Table

The cluster state is persisted in the `libcluster_postgres` table (or similar, depending on configuration defaults). You can query this table to see registered nodes.

```sql
SELECT * FROM libcluster_postgres;
```

## Common Operations

### Adding a Node
Simply start a new instance of the application pointing to the same database. It will automatically:
1.  Register itself in Postgres.
2.  Discover other nodes.
3.  Join the cluster.

### Removing a Node
Simply stop the application instance.
*   **Graceful Shutdown**: The node will attempt to unregister itself.
*   **Crash**: The node will remain in the DB table until the `heartbeat` expires, after which other nodes will prune it.

## Troubleshooting

### Split Brain
If nodes are running but not seeing each other:
1.  **Check DB Connectivity**: Can all nodes reach the DB?
2.  **Check Cookies**: Run `Node.get_cookie()` on all nodes. They MUST match.
3.  **Check Logs**: Look for `[libcluster]` errors in the logs.

### "Node is down" Messages
It is normal to see "Node down" messages during deployments as old pods/servers are terminated and new ones replace them.
