defmodule Mcp.OlaTest do
  use Mcp.DataCase, async: true

  describe "domain" do
    test "Mcp.Ola is a valid Ash domain" do
      # Verify the module is loaded
      assert {:module, Mcp.Ola} = Code.ensure_loaded(Mcp.Ola)

      # Ash.Domain modules have spark dsl functions
      assert function_exported?(Mcp.Ola, :__spark_placeholder__, 0)

      # Verify it's configured in ash_domains
      domains = Application.get_env(:mcp, :ash_domains, [])
      assert Mcp.Ola in domains
    end
  end
end
