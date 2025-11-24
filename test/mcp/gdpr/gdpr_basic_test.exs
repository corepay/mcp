defmodule Mcp.Gdpr.GdprBasicTest do
  use Mcp.DataCase, async: false

  alias Mcp.Gdpr.Supervisor

  @moduletag :gdpr
  @moduletag :unit

  describe "GDPR Supervisor starts correctly" do
    test "supervisor module exists and compiles" do
      assert function_exported?(Supervisor, :start_link, 1)
    end
  end
end