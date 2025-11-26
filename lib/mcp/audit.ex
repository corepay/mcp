defmodule Mcp.Audit do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Mcp.Audit.Version
  end

  admin do
    show?(true)
  end
end
