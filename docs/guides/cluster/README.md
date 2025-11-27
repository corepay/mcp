# Clustering & Service Discovery

**Status:** ✅ Active
**Version:** 1.0.0

## Overview

The Clustering module enables multiple instances of the MCP Platform to discover each other and form a distributed Erlang cluster. This is essential for features that require real-time communication, distributed caching, and background job coordination across nodes.

We use **Postgres-based Service Discovery** (`libcluster_postgres`) to allow nodes to find each other in environments without native service discovery (like Render, Heroku, or simple Docker Compose setups).

## Quick Start

1.  **Add Dependency**: Ensure `libcluster_postgres` is in `mix.exs`.
2.  **Configure**: Set up the `postgres_cluster` topology in `config/config.exs`.
3.  **Deploy**: Deploy multiple instances of the application pointing to the same database.
4.  **Verify**: Run `Node.list()` in a remote console to see connected nodes.

## Key Features

*   **Infrastructure Agnostic**: Works anywhere Postgres is available.
*   **Zero-Config**: No need for complex DNS, K8s RBAC, or Multicast setup.
*   **Automatic Healing**: Nodes automatically join/leave the cluster as they start/stop.

## Documentation

*   **[Developer Guide](developer-guide.md)**: Implementation details and configuration.
*   **[API Reference](api-reference.md)**: Internal module reference.
*   **[Stakeholder Guide](stakeholder-guide.md)**: Business value and benefits.
*   **[User Guide](user-guide.md)**: Operational guide for managing the cluster.
