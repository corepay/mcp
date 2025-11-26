defmodule Mcp.Gdpr.ComplianceTest do
  use Mcp.DataCase, async: true

  alias Mcp.Accounts.User
  alias Mcp.Gdpr.Compliance
  alias Mcp.Repo

  import Ecto.Query

  describe "request_user_deletion/4" do
    test "successfully initiates soft deletion for user" do
      {:ok, user} = create_test_user()

      assert {:ok, result} = Compliance.request_user_deletion(user.id, "user_request")

      updated_user = Repo.get!(User, user.id)
      assert updated_user.status == :deleted
      assert updated_user.gdpr_deletion_requested_at != nil
      assert updated_user.gdpr_deletion_reason == "user_request"
      assert updated_user.gdpr_retention_expires_at != nil
    end

    test "returns error for non-existent user" do
      user_id = Ecto.UUID.generate()

      assert {:error, :user_not_found} = Compliance.request_user_deletion(user_id, "user_request")
    end

    test "returns error for already deleted user" do
      {:ok, user} = create_test_user(status: :deleted)

      assert {:error, :already_deleted} =
               Compliance.request_user_deletion(user.id, "user_request")
    end
  end

  describe "cancel_user_deletion/2" do
    test "successfully cancels pending deletion" do
      {:ok, user} = create_test_user(status: :deleted)

      assert {:ok, restored_user} = Compliance.cancel_user_deletion(user.id)

      assert restored_user.status == :active
      assert restored_user.gdpr_deletion_requested_at == nil
      assert restored_user.gdpr_deletion_reason == nil
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
      assert export.requested_format == "json"
      assert export.status == "requested"
    end

    test "creates export request with custom categories" do
      {:ok, user} = create_test_user()
      categories = ["user_identity", "activity_logs"]

      assert {:ok, export} = Compliance.generate_data_export(user.id, "json", categories)

      assert export.user_id == user.id
      assert export.requested_format == "json"
      assert export.data_categories == categories
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
                 "Marketing communications"
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

      user
      |> Ecto.Changeset.change(%{gdpr_retention_expires_at: past_date})
      |> Repo.update!()

      # Now anonymize
      assert {:ok, anonymized_user} = Compliance.anonymize_user_data(user.id)

      assert anonymized_user.status == :anonymized
      assert anonymized_user.gdpr_anonymized_at != nil
      assert anonymized_user.first_name == "Deleted"
      assert anonymized_user.last_name == "User"
      assert String.starts_with?(anonymized_user.email, "deleted-")
    end

    test "returns error for non-deleted user" do
      {:ok, user} = create_test_user()

      assert {:error, _reason} = Compliance.anonymize_user_data(user.id)
    end
  end

  describe "get_users_overdue_for_anonymization/0" do
    test "returns users past retention period" do
      {:ok, user1} = create_test_user(status: :deleted)
      {:ok, user2} = create_test_user(status: :active)

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
      report = Compliance.generate_compliance_report()

      assert is_map(report)
      assert Map.has_key?(report, :deletion_requests)
      assert Map.has_key?(report, :data_exports)
      assert Map.has_key?(report, :consent_records)
      assert Map.has_key?(report, :retention_status)
      assert Map.has_key?(report, :audit_summary)
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "TestPassword123!",
      password_confirmation: "TestPassword123!"
    }

    final_attrs = Map.merge(default_attrs, attrs)

    %User{}
    |> Ecto.Changeset.change(final_attrs)
    |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt(final_attrs.password))
    |> Repo.insert()
  end
end
