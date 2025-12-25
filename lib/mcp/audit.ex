defmodule Mcp.Audit do
  @moduledoc """
  Audit domain for tracking system activities.
  """
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Mcp.Audit.Version
  end

  admin do
    show?(true)
  end
end
