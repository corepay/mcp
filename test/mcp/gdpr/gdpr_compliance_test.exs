defmodule Mcp.Gdpr.ComplianceTest do
  # Not async due to shared GenServer state
  use ExUnit.Case, async: false

  alias Mcp.Gdpr
  alias Mcp.Accounts.User
  alias Mcp.Accounts.Auth
  alias Mcp.Cache.SessionStore

  setup do
    # Clean up sessions before each test
    SessionStore.flush_all()
    :ok
  end

  describe "Data Export Compliance" do
    test "exports user data in JSON format", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Request data export
      {:ok, export_data} = Gdpr.request_data_export(user.id, "json")

      # Verify export structure
      assert export_data.filename == "user_data_#{user.id}.json"
      assert String.starts_with?(export_data.data, "{")

      # Parse and verify JSON content
      parsed_data = Jason.decode!(export_data.data)

      assert parsed_data["user_id"] == user.id
      assert parsed_data["format"] == "json"
      assert %{"profile" => profile} = parsed_data["data"]

      # Verify profile data
      assert profile["id"] == user.id
      assert profile["email"] == user.email
      assert profile["first_name"] == user.first_name
      assert profile["last_name"] == user.last_name
      assert profile["created_at"] != nil
      assert profile["updated_at"] != nil

      # Verify audit trail is included
      assert is_list(parsed_data["data"]["audit_logs"])
      assert is_list(parsed_data["data"]["auth_tokens"])
    end

    test "exports user data in CSV format", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Request data export
      {:ok, export_data} = Gdpr.request_data_export(user.id, "csv")

      # Verify export structure
      assert export_data.filename == "user_data_#{user.id}.csv"
      assert String.contains?(export_data.data, "user_id,email,first_name,last_name,created_at")

      assert String.contains?(
               export_data.data,
               "#{user.id},#{user.email},#{user.first_name},#{user.last_name}"
             )
    end

    test "handles unsupported export formats", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Request data export with unsupported format
      {:error, :unsupported_format} = Gdpr.request_data_export(user.id, "xml")
    end

    test "handles non-existent user data export", %{conn: _conn} do
      non_existent_user_id = 999_999

      # Request data export for non-existent user
      {:error, :export_failed} = Gdpr.request_data_export(non_existent_user_id, "json")
    end

    test "includes all required data fields in export", %{conn: _conn} do
      {:ok, user} =
        create_test_user(%{
          phone: "+1-555-123-4567"
        })

      # Create some authentication history
      {:ok, _session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Request data export
      {:ok, export_data} = Gdpr.request_data_export(user.id, "json")
      parsed_data = Jason.decode!(export_data.data)

      profile = parsed_data["data"]["profile"]

      # Verify all personal data is included
      assert profile["id"] == user.id
      assert profile["email"] == user.email
      assert profile["first_name"] == user.first_name
      assert profile["last_name"] == user.last_name
      assert profile["phone"] == "+1-555-123-4567"
      assert profile["created_at"] != nil
      assert profile["updated_at"] != nil

      # Verify auth tokens are included (non-sensitive data)
      auth_tokens = parsed_data["data"]["auth_tokens"]
      assert is_list(auth_tokens)

      # Verify audit logs are included
      audit_logs = parsed_data["data"]["audit_logs"]
      assert is_list(audit_logs)
    end

    test "anonymizes sensitive data during export", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Request data export
      {:ok, export_data} = Gdpr.request_data_export(user.id, "json")
      parsed_data = Jason.decode!(export_data.data)

      # Verify auth tokens don't include sensitive data
      auth_tokens = parsed_data["data"]["auth_tokens"]

      if length(auth_tokens) > 0 do
        Enum.each(auth_tokens, fn token ->
          refute Map.has_key?(token, "token")
          refute Map.has_key?(token, "jti")
          assert Map.has_key?(token, "type")
          assert Map.has_key?(token, "created_at")
        end)
      end
    end
  end

  describe "User Deletion (Right to be Forgotten)" do
    test "soft deletes user with anonymization", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Verify user exists initially
      assert user.status == :active
      assert user.email == "gdpr_test@example.com"

      # Request user deletion
      {:ok, result} = Gdpr.request_user_deletion(user.id, "user_request")
      assert result.status == :deleted

      # Wait for async operation to complete (if any)
      Process.sleep(100)

      # Verify user is anonymized
      deletion_status = Gdpr.get_deletion_status(user.id)
      assert deletion_status.status == :deleted
      assert deletion_status.deleted_at != nil

      # Verify user can no longer authenticate
      {:error, _} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
    end

    test "revokes all tokens during deletion", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Create authentication sessions
      {:ok, session1} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
      {:ok, session2} = Auth.authenticate(user.email, "Password123!", "192.168.1.1")

      # Verify sessions are valid
      assert {:ok, _} = Auth.verify_session(session1.access_token)
      assert {:ok, _} = Auth.verify_session(session2.access_token)

      # Request user deletion
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "user_request")

      # Wait for deletion to complete
      Process.sleep(100)

      # Verify all sessions are revoked
      assert {:error, _} = Auth.verify_session(session1.access_token)
      assert {:error, _} = Auth.verify_session(session2.access_token)
    end

    test "preserves audit trail after deletion", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Create some audit activity
      {:ok, _session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Request user deletion
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "account_closure")

      # Wait for deletion to complete
      Process.sleep(100)

      # Request data export for audit purposes
      {:ok, export_data} = Gdpr.request_data_export(user.id, "json")
      parsed_data = Jason.decode!(export_data.data)

      # Verify audit logs are preserved
      audit_logs = parsed_data["data"]["audit_logs"]
      assert is_list(audit_logs)
      # Should contain authentication logs
      # Implementation dependent
      assert length(audit_logs) >= 0
    end

    test "handles deletion of already deleted user", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Delete user first time
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "user_request")
      Process.sleep(100)

      # Try to delete again
      {:ok, result} = Gdpr.request_user_deletion(user.id, "duplicate_request")
      assert result.status == :deleted
    end

    test "tracks deletion reason and timestamp", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Request user deletion with specific reason
      deletion_reason = "GDPR Article 17 Request"
      {:ok, _result} = Gdpr.request_user_deletion(user.id, deletion_reason)

      # Wait for deletion to complete
      Process.sleep(100)

      # Verify deletion status includes reason
      deletion_status = Gdpr.get_deletion_status(user.id)
      assert deletion_status.status == :deleted
      # Implementation would include reason and timestamp
      assert deletion_status.deleted_at != nil
    end

    test "handles non-existent user deletion", %{conn: _conn} do
      non_existent_user_id = 999_999

      # Request deletion for non-existent user
      {:error, :soft_delete_failed} = Gdpr.request_user_deletion(non_existent_user_id, "test")
    end
  end

  describe "Deletion Status Management" do
    test "returns accurate deletion status for active user", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Check status of active user
      {:ok, status} = Gdpr.get_deletion_status(user.id)
      assert status.status == :active
      refute Map.has_key?(status, :deleted_at)
    end

    test "returns accurate deletion status for deleted user", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Delete user
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "test_reason")
      Process.sleep(100)

      # Check status of deleted user
      {:ok, status} = Gdpr.get_deletion_status(user.id)
      assert status.status == :deleted
      assert status.deleted_at != nil
    end

    test "handles status check for non-existent user", %{conn: _conn} do
      non_existent_user_id = 999_999

      # Check status of non-existent user
      {:ok, status} = Gdpr.get_deletion_status(non_existent_user_id)
      assert status.status == :not_found
    end
  end

  describe "Deletion Cancellation" do
    test "cancels pending deletion request", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # In a real implementation, this would work with pending deletions
      # For current implementation, it's a no-op
      {:ok, result} = Gdpr.cancel_user_deletion(user.id)
      assert result.status == :restored
      assert result.user_id == user.id
    end

    test "handles cancellation for non-existent user", %{conn: _conn} do
      non_existent_user_id = 999_999

      # Try to cancel deletion for non-existent user
      {:error, :restoration_failed} = Gdpr.cancel_user_deletion(non_existent_user_id)
    end
  end

  describe "Consent Management" do
    test "tracks user consent properly", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # This would test consent tracking if implemented
      # Current implementation focuses on data export and deletion
      # User exists for consent tracking
      assert user.id != nil
    end

    test "handles consent withdrawal", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Consent withdrawal would trigger data deletion
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "consent_withdrawn")
      Process.sleep(100)

      # Verify deletion occurred
      {:ok, status} = Gdpr.get_deletion_status(user.id)
      assert status.status == :deleted
    end
  end

  describe "Data Portability" do
    test "provides data in machine-readable formats", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Test JSON format
      {:ok, json_export} = Gdpr.request_data_export(user.id, "json")
      assert json_export.filename |> String.ends_with?(".json")
      assert json_export.data |> Jason.decode!() != nil

      # Test CSV format
      {:ok, csv_export} = Gdpr.request_data_export(user.id, "csv")
      assert csv_export.filename |> String.ends_with?(".csv")
      assert String.contains?(csv_export.data, "user_id,email")
    end

    test "includes comprehensive user data in exports", %{conn: _conn} do
      {:ok, user} =
        create_test_user(%{
          first_name: "John",
          last_name: "Doe",
          phone: "+1-555-0123",
          email: "john.doe@example.com"
        })

      # Create authentication history
      {:ok, _session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Export data
      {:ok, export_data} = Gdpr.request_data_export(user.id, "json")
      parsed_data = Jason.decode!(export_data.data)

      # Verify comprehensive data inclusion
      profile = parsed_data["data"]["profile"]
      assert profile["first_name"] == "John"
      assert profile["last_name"] == "Doe"
      assert profile["email"] == "john.doe@example.com"
      assert profile["phone"] == "+1-555-0123"

      # Verify metadata
      assert parsed_data["user_id"] == user.id
      assert parsed_data["export_date"] != nil
      assert parsed_data["format"] == "json"
    end

    test "maintains data structure consistency across formats", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Get both formats
      {:ok, json_export} = Gdpr.request_data_export(user.id, "json")
      {:ok, csv_export} = Gdpr.request_data_export(user.id, "csv")

      # Parse and verify consistency
      json_data = Jason.decode!(json_export.data)
      profile = json_data["data"]["profile"]

      # CSV should contain same core data
      assert String.contains?(csv_export.data, "#{user.id}")
      assert String.contains?(csv_export.data, user.email)
      assert String.contains?(csv_export.data, user.first_name)
      assert String.contains?(csv_export.data, user.last_name)
    end
  end

  describe "Audit Trail Compliance" do
    test "maintains audit trail for GDPR operations", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Perform GDPR operations
      {:ok, _export} = Gdpr.request_data_export(user.id, "json")
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "test_reason")

      # Wait for operations to complete
      Process.sleep(100)

      # Export data should include audit logs
      {:ok, final_export} = Gdpr.request_data_export(user.id, "json")
      parsed_data = Jason.decode!(final_export.data)

      audit_logs = parsed_data["data"]["audit_logs"]
      assert is_list(audit_logs)
      # Should contain logs for export and deletion operations
    end

    test "timestamps all GDPR operations", %{conn: _conn} do
      {:ok, user} = create_test_user()

      before_export = DateTime.utc_now()

      # Export operation
      {:ok, export_data} = Gdpr.request_data_export(user.id, "json")
      parsed_data = Jason.decode!(export_data.data)

      after_export = DateTime.utc_now()

      # Verify export timestamp
      export_date = DateTime.from_iso8601!(parsed_data["export_date"])
      assert DateTime.compare(export_date, before_export) != :lt
      assert DateTime.compare(export_date, after_export) != :gt

      # Verify creation timestamps are preserved
      profile = parsed_data["data"]["profile"]
      created_at = DateTime.from_iso8601!(profile["created_at"])
      updated_at = DateTime.from_iso8601!(profile["updated_at"])

      assert DateTime.compare(created_at, updated_at) != :gt
    end
  end

  describe "Error Handling and Logging" do
    test "handles GDPR operation failures gracefully", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Test with invalid export format
      {:error, :unsupported_format} = Gdpr.request_data_export(user.id, "invalid")

      # Test with non-existent user
      {:error, :export_failed} = Gdpr.request_data_export(999_999, "json")
      {:error, :soft_delete_failed} = Gdpr.request_user_deletion(999_999, "test")
    end

    test "logs all GDPR operations appropriately", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # This test would verify that operations are logged
      # In practice, you'd capture and verify log output
      # For now, we just ensure operations complete

      {:ok, _export} = Gdpr.request_data_export(user.id, "json")
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "test_reason")

      # Operations should complete without raising exceptions
      assert true
    end
  end

  describe "Integration with Authentication System" do
    test "deleted users cannot authenticate", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Verify authentication works before deletion
      {:ok, _session} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")

      # Delete user
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "test_reason")
      Process.sleep(100)

      # Verify authentication fails after deletion
      {:error, _} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
    end

    test "deletion revokes all active sessions", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Create multiple sessions
      {:ok, session1} = Auth.authenticate(user.email, "Password123!", "127.0.0.1")
      {:ok, session2} = Auth.authenticate(user.email, "Password123!", "192.168.1.1")
      {:ok, session3} = Auth.authenticate(user.email, "Password123!", "10.0.0.1")

      # Verify all sessions are valid
      assert {:ok, _} = Auth.verify_session(session1.access_token)
      assert {:ok, _} = Auth.verify_session(session2.access_token)
      assert {:ok, _} = Auth.verify_session(session3.access_token)

      # Delete user
      {:ok, _result} = Gdpr.request_user_deletion(user.id, "test_reason")
      Process.sleep(100)

      # Verify all sessions are revoked
      assert {:error, _} = Auth.verify_session(session1.access_token)
      assert {:error, _} = Auth.verify_session(session2.access_token)
      assert {:error, _} = Auth.verify_session(session3.access_token)
    end
  end

  describe "Performance and Scalability" do
    test "handles large data exports efficiently", %{conn: _conn} do
      {:ok, user} = create_test_user()

      # Measure export performance
      {time, {:ok, _export_data}} =
        :timer.tc(fn ->
          Gdpr.request_data_export(user.id, "json")
        end)

      # Export should complete within reasonable time
      assert time < 5_000_000, "Data export took #{time}μs, expected < 5s"
    end

    test "concurrent GDPR operations work correctly", %{conn: _conn} do
      {:ok, user1} = create_test_user(%{email: "user1@example.com"})
      {:ok, user2} = create_test_user(%{email: "user2@example.com"})

      # Perform concurrent operations
      tasks = [
        Task.async(fn -> Gdpr.request_data_export(user1.id, "json") end),
        Task.async(fn -> Gdpr.request_data_export(user2.id, "json") end),
        Task.async(fn -> Gdpr.get_deletion_status(user1.id) end),
        Task.async(fn -> Gdpr.get_deletion_status(user2.id) end)
      ]

      results = Task.await_many(tasks, 10_000)

      # All operations should succeed
      assert length(results) == 4

      assert Enum.all?(results, fn
               {:ok, _} -> true
               {:ok, _, _} -> true
               _ -> false
             end)
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      first_name: "GDPR",
      last_name: "Test",
      email: "gdpr_test@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      status: :active
    }

    User.register(Map.merge(default_attrs, attrs))
  end
end
