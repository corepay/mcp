defmodule Mcp.Gdpr.RetentionTest do
  use ExUnit.Case, async: true
  alias Ecto.Adapters.SQL
  alias Mcp.Gdpr.Anonymizer
  alias Mcp.Repo

  test "Anonymizer can be used directly" do
    # Test that the Anonymizer module works correctly
    test_email = "test@example.com"
    test_user_id = UUID.uuid4()

    {:ok, anonymized_email} = Anonymizer.anonymize_field(test_email, :email, test_user_id)
    assert String.contains?(anonymized_email, "@anonymized.local")
    assert String.starts_with?(anonymized_email, "deleted_")

    {:ok, anonymized_name} = Anonymizer.anonymize_field(test_email, :name, test_user_id)
    assert anonymized_name == "Deleted User"

    {:ok, anonymized_phone} = Anonymizer.anonymize_field("+15551234567", :phone, test_user_id)
    assert String.contains?(anonymized_phone, "XXXXXXX")
  end

  test "Phase 3 GDPR components compile successfully" do
    # Test that all the key Phase 3 components can be compiled
    # This is a basic smoke test to ensure the implementation is working

    assert function_exported?(Anonymizer, :anonymize_user, 1)
    assert function_exported?(Anonymizer, :anonymize_field, 3)

    # Verify the retention policies table exists
    assert {:ok, _} =
             SQL.query(Repo, "SELECT COUNT(*) FROM gdpr_retention_policies")
  end
end
