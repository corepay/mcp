defmodule Mcp.Platform.Types.OwnerType do
  @moduledoc """
  Enum type representing the owner type for polymorphic ownership relationships.
  """
  use Ash.Type.Enum, values: [:user, :tenant, :merchant, :developer]
end
