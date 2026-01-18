defmodule Mcp.Graph do
  @moduledoc """
  The Graph domain for relationships and knowledge graphs.
  """
  use Ash.Domain, extensions: [AshAi], validate_config_inclusion?: false

  tools do
    tool(:traversal, Mcp.Graph.Query, :traversal)
    tool(:find_connected_risks, Mcp.Graph.Query, :find_connected_risks)
  end

  resources do
    resource Mcp.Graph.Query
  end
end
