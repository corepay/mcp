defmodule Mcp.Gdpr.ComplianceTest do
  use Mcp.DataCase, async: false

  alias Mcp.Accounts.User
  alias Mcp.Gdpr.Compliance
  alias Mcp.Repo

  describe "request_user_deletion/4" do
    test "successfully initiates soft deletion for user" do
      {:ok, user} = create_test_user()

      assert {:ok, _result} = Compliance.request_user_deletion(user.id, "user_request")

      updated_user = Repo.get!(User, user.id)
      assert updated_user.status == :deleted
      assert updated_user.deleted_at != nil
      assert updated_user.deletion_reason == "user_request"
      assert updated_user.gdpr_retention_expires_at != nil
    end

    test "returns error for non-existent user" do
      user_id = Ecto.UUID.generate()

      assert {:error, :user_not_found} = Compliance.request_user_deletion(user_id, "user_request")
    end

    test "returns success for already deleted user (idempotent)" do
      {:ok, user} = create_test_user(status: :deleted)

      assert {:ok, _user} = Compliance.request_user_deletion(user.id, "user_request")
    end
  end

  describe "cancel_user_deletion/2" do
    test "successfully cancels pending deletion" do
      {:ok, user} = create_test_user(status: :deleted)

      assert {:ok, restored_user} = Compliance.cancel_user_deletion(user.id)

      assert restored_user.status == :active
      assert restored_user.deleted_at == nil
      assert restored_user.deletion_reason == nil
      assert restored_user.gdpr_retention_expires_at == nil
    end

    test "returns error for non-existent user" do
      user_id = Ecto.UUID.generate()

      assert {:error, :user_not_found} = Compliance.cancel_user_deletion(user_id)
    end
  end

  describe "generate_data_export/3" do
    test "creates export request for user" do
      {:ok, user} = create_test_user()

      assert {:ok, export} = Compliance.generate_data_export(user.id, "json")

      assert export.user_id == user.id
      assert export.format == "json"
      assert export.status == "pending"
    end

    test "creates export request with custom categories" do
      {:ok, user} = create_test_user()
      categories = ["user_identity", "activity_logs"]

      assert {:ok, export} = Compliance.generate_data_export(user.id, "json", categories)

      assert export.user_id == user.id
      assert export.format == "json"
      # assert export.data_categories == categories
    end
  end

  describe "has_consent?/2" do
    test "returns false for user with no consent" do
      {:ok, user} = create_test_user()

      assert {:ok, false} = Compliance.has_consent?(user.id, "marketing")
    end

    test "returns true for user with valid consent" do
      {:ok, user} = create_test_user()

      # Record consent first
      assert {:ok, _consent} =
               Compliance.record_consent(
                 user.id,
                 "marketing",
                 "consent",
                 nil
               )

      assert {:ok, true} = Compliance.has_consent?(user.id, "marketing")
    end
  end

  describe "anonymize_user_data/2" do
    test "anonymizes deleted user data" do
      {:ok, user} = create_test_user()

      # First schedule for deletion
      assert {:ok, _result} = Compliance.request_user_deletion(user.id, "test")

      # Set retention as expired
      past_date = DateTime.add(DateTime.utc_now(), -1, :day)

      Repo.get!(Mcp.Accounts.UserSchema, user.id)
      |> Ecto.Changeset.change(%{gdpr_retention_expires_at: past_date})
      |> Repo.update!()

      # Now anonymize
      assert {:ok, :anonymized} = Compliance.anonymize_user_data(user.id)

      # Verify user is actually anonymized in DB
      updated_user = Repo.get!(Mcp.Accounts.UserSchema, user.id)
      # Anonymized users are suspended
      assert updated_user.status == "suspended"
      assert String.starts_with?(updated_user.email, "deleted_")
    end

    test "returns error for non-deleted user" do
      {:ok, user} = create_test_user()

      assert {:error, _reason} = Compliance.anonymize_user_data(user.id)
    end
  end

  describe "get_users_overdue_for_anonymization/0" do
    test "returns users past retention period" do
      {:ok, user1} = create_test_user(status: :deleted)
      {:ok, _user2} = create_test_user(status: :active)

      # Set user1 retention as expired
      past_date = DateTime.add(DateTime.utc_now(), -1, :day)

      user1
      |> Ecto.Changeset.change(%{gdpr_retention_expires_at: past_date})
      |> Repo.update!()

      overdue_users = Compliance.get_users_overdue_for_anonymization()

      assert length(overdue_users) == 1
      assert hd(overdue_users).id == user1.id
    end
  end

  describe "generate_compliance_report/1" do
    test "generates compliance report with metrics" do
      {:ok, report} = Compliance.generate_compliance_report()

      assert is_map(report)
      assert Map.has_key?(report, :total_users)
      assert Map.has_key?(report, :deleted_users)
      assert Map.has_key?(report, :anonymized_users)
      assert Map.has_key?(report, :compliance_score)
      assert Map.has_key?(report, :audit_coverage)
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "TestPassword123!",
      password_confirmation: "TestPassword123!",
      tenant_id: Ecto.UUID.generate(),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    attrs_map = Map.new(attrs)

    attrs_map =
      if attrs_map[:status],
        do: Map.put(attrs_map, :status, to_string(attrs_map[:status])),
        else: attrs_map

    user = User.create_for_test(Map.merge(default_attrs, attrs_map))
    {:ok, user}
  end
end
