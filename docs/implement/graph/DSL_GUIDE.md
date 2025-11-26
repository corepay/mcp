# Graph DSL Guide

## Introduction

The `Mcp.Graph.Extension` allows Ash Resources to define their role within the
graph database using a simple, declarative DSL. This extension bridges the gap
between Ash's relational model and the graph's node/edge model.

## Usage

### 1. Add the Extension

Add `Mcp.Graph.Extension` to your resource's `extensions` list and `use` it to
import the macros.

```elixir
defmodule Mcp.Platform.Merchant do
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    extensions: [Mcp.Graph.Extension]

  use Mcp.Graph.Extension
  # ...
end
```

### 2. Define Graph Structure

Use the `graph` block to define the node type and relationships.

```elixir
graph do
  node_type :merchant
  graph_relationship :reseller, :belongs_to, Mcp.Platform.Reseller
  graph_relationship :stores, :has_many, Mcp.Platform.Store
end
```

## DSL Reference

### `node_type`

Defines the label that will be used for this resource in the graph database.

- **Syntax**: `node_type :atom`
- **Example**: `node_type :customer` -> `(:Customer)` node in Cypher.

### `graph_relationship`

Defines a potential edge in the graph.

- **Syntax**: `graph_relationship :name, :type, DestinationResource`
- **Arguments**:
  - `:name` - The name of the relationship (e.g., `:stores`).
  - `:type` - The cardinality (`:has_many`, `:belongs_to`, etc.).
  - `DestinationResource` - The Ash Resource module this relates to.

## Implementation Details

### How it Works

The extension uses `Spark.Dsl` to compile these definitions into the resource's
configuration.

- **Macros**: `node_type` and `graph_relationship` are manual macros that call
  `Spark.Dsl.Builder`.
- **Introspection**: You can inspect a resource's graph config at runtime:
  ```elixir
  Mcp.Graph.Info.graph(Mcp.Platform.Merchant)
  # Returns %Spark.Dsl.Section{...}
  ```

### Extending the DSL

To add new options (e.g., `graph_index` or `graph_property`), modify
`lib/mcp/graph/extension.ex`:

1. Add the option to the `schema`.
2. Define a manual macro using `Spark.Dsl.Builder.set_option`.
