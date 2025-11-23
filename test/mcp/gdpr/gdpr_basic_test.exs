defmodule Mcp.Gdpr.GdprBasicTest do
  use Mcp.DataCase, async: false

  alias Mcp.Gdpr.Application
  alias Mcp.Gdpr.Supervisor

  @moduletag :gdpr
  @moduletag :unit

  describe "GDPR Application starts correctly" do
    test "application module exists and compiles" do
      assert function_exported?(Application, :start, 2)
    end

    test "supervisor module exists and compiles" do
      assert function_exported?(Supervisor, :start_link, 1)
    end
  end
end