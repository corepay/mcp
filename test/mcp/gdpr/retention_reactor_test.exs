defmodule Mcp.Gdpr.RetentionReactorTest do
  use Mcp.DataCase, async: false

  alias Mcp.Gdpr.RetentionReactor

  describe "retention reactor execution" do
    test "reactor can be started and executed" do
      # Test that the reactor can be constructed and run without errors
      args = %{}

      # Note: This is a basic smoke test
      # In a real scenario, you'd have test data and policies set up
      case Reactor.run(RetentionReactor, args, async?: false) do
        {:ok, _result} -> assert true
        {:error, reason} -> flunk("Reactor failed: #{inspect(reason)}")
      end
    end
  end

  describe "private functions" do
    test "create_retention_audit function exists and can be called" do
      # Test the private audit function directly
      record_id = Ecto.UUID.generate()
      action = "anonymize"
      policy_id = Ecto.UUID.generate()
      details = %{"reason" => "test"}

      # This should not raise an exception
      result = RetentionReactor.create_retention_audit(record_id, action, policy_id, details)
      assert result == :ok
    end
  end
end
