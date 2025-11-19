defmodule McpWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  See https://hexdocs.pm/phoenix/Phoenix.ChannelTest.html for more information.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import McpWeb.ChannelCase

      # The default endpoint for testing
      @endpoint McpWeb.Endpoint
    end
  end

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Mcp.Repo)
    {:ok, socket: Phoenix.ChannelTest.socket()}
  end
end