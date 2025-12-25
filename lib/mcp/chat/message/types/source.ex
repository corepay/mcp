defmodule Mcp.Chat.Message.Types.Source do
  @moduledoc """
  Source type for chat messages (e.g. user, system, assistant).
  """
  use Ash.Type.Enum, values: [:agent, :user]
end
