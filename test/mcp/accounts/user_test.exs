defmodule Mcp.Accounts.UserTest do
  use ExUnit.Case, async: true

  alias Mcp.Accounts.User

  describe "user registration" do
    test "creates a user with valid data" do
      attrs = %{
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      }

      assert {:ok, user} = User.register(attrs)
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.email == "john.doe@example.com"
      assert user.status == :active
      assert user.hashed_password != nil
      assert user.sign_in_count == 0
      assert user.failed_attempts == 0
      assert user.password_change_required == false
    end

    test "requires password confirmation to match" do
      attrs = %{
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        password: "Password123!",
        password_confirmation: "DifferentPassword!"
      }

      assert {:error, changeset} = User.register(attrs)
      assert %{"password_confirmation" => ["does not match"]} = Ash.Changeset.errors(changeset)
    end

    test "requires strong password" do
      test_cases = [
        {"weak", "too short"},
        {"password", "no uppercase, no number, no special"},
        {"Password", "no number, no special"},
        {"Password1", "no special character"},
        {"12345678", "no letters, no special"},
        {"PASSWORD!", "no lowercase"}
      ]

      Enum.each(test_cases, fn {password, description} ->
        attrs = %{
          first_name: "John",
          last_name: "Doe",
          email: "#{System.unique_integer()}@example.com",
          password: password,
          password_confirmation: password
        }

        assert {:error, changeset} = User.register(attrs), "Should fail for: #{description}"
        assert has_password_strength_error?(changeset)
      end)
    end

    test "requires valid email format" do
      invalid_emails = [
        "invalid-email",
        "@example.com",
        "user@",
        "user..name@example.com",
        "user@.com",
        " user@example.com",
        "user@domain.com ",
        ""
      ]

      Enum.each(invalid_emails, fn email ->
        attrs = %{
          first_name: "John",
          last_name: "Doe",
          email: email,
          password: "Password123!",
          password_confirmation: "Password123!"
        }

        assert {:error, changeset} = User.register(attrs)
        assert %{"email" => ["has invalid format"]} = Ash.Changeset.errors(changeset)
      end)
    end

    test "validates required fields" do
      required_fields = [:first_name, :last_name, :email, :password, :password_confirmation]

      Enum.each(required_fields, fn field ->
        attrs = %{
          first_name: "John",
          last_name: "Doe",
          email: "john.doe@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        }

        attrs = Map.delete(attrs, field)

        assert {:error, changeset} = User.register(attrs)
        assert has_required_field_error?(changeset, field)
      end)
    end

    test "trims whitespace from string fields" do
      attrs = %{
        first_name: "  John  ",
        last_name: "  Doe  ",
        email: "  john.doe@example.com  ",
        password: "Password123!  ",
        password_confirmation: "  Password123!  "
      }

      assert {:ok, user} = User.register(attrs)
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.email == "john.doe@example.com"
    end

    test "validates field length constraints" do
      # Test first_name length
      long_name = String.duplicate("a", 101)

      attrs = %{
        first_name: long_name,
        last_name: "Doe",
        email: "test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      }

      assert {:error, changeset} = User.register(attrs)
      assert has_length_error?(changeset, :first_name)
    end

    test "enforces unique email constraint" do
      attrs = %{
        first_name: "John",
        last_name: "Doe",
        email: "unique.test@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      }

      # Create first user
      assert {:ok, _user1} = User.register(attrs)

      # Try to create second user with same email
      assert {:error, changeset} = User.register(attrs)
      assert has_unique_error?(changeset, :email)
    end
  end

  describe "password management" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Test",
            last_name: "User",
            email: "password.test@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "changes password with correct current password", %{user: user} do
      attrs = %{
        current_password: "Password123!",
        password: "NewPassword456!",
        password_confirmation: "NewPassword456!"
      }

      assert {:ok, updated_user} = User.change_password(user, attrs)
      assert updated_user.password_change_required == false
      # Verify new password works by checking it's different
      assert updated_user.hashed_password != user.hashed_password
    end

    test "rejects password change with incorrect current password", %{user: user} do
      attrs = %{
        current_password: "WrongPassword!",
        password: "NewPassword456!",
        password_confirmation: "NewPassword456!"
      }

      assert {:error, changeset} = User.change_password(user, attrs)
      assert %{"current_password" => ["is incorrect"]} = Ash.Changeset.errors(changeset)
    end

    test "requires new password confirmation match", %{user: user} do
      attrs = %{
        current_password: "Password123!",
        password: "NewPassword456!",
        password_confirmation: "DifferentPassword!"
      }

      assert {:error, changeset} = User.change_password(user, attrs)
      assert %{"password_confirmation" => ["does not match"]} = Ash.Changeset.errors(changeset)
    end

    test "enforces password strength on password change", %{user: user} do
      attrs = %{
        current_password: "Password123!",
        password: "weak",
        password_confirmation: "weak"
      }

      assert {:error, changeset} = User.change_password(user, attrs)
      assert has_password_strength_error?(changeset)
    end

    test "resets password_change_required flag on successful change", %{user: user} do
      # First set the flag to true
      {:ok, user_with_flag} =
        Ash.update(user, %{password_change_required: true}, action: :register)

      assert user_with_flag.password_change_required == true

      # Change password
      attrs = %{
        current_password: "Password123!",
        password: "NewPassword456!",
        password_confirmation: "NewPassword456!"
      }

      assert {:ok, updated_user} = User.change_password(user_with_flag, attrs)
      assert updated_user.password_change_required == false
    end
  end

  describe "user lookup and queries" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Alice",
            last_name: "Smith",
            email: "alice.smith@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "finds user by email", %{user: user} do
      {:ok, found_user} = User.by_email(email: "alice.smith@example.com")
      assert found_user.id == user.id
      assert found_user.email == "alice.smith@example.com"
    end

    test "case-insensitive email lookup", %{user: user} do
      {:ok, found_user} = User.by_email(email: "ALICE.SMITH@EXAMPLE.COM")
      assert found_user.id == user.id
    end

    test "returns empty for non-existent email" do
      {:ok, []} = User.by_email(email: "nonexistent@example.com")
    end
  end

  describe "GDPR compliance actions" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "GDPR",
            last_name: "User",
            email: "gdpr.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "requests account deletion with reason", %{user: user} do
      attrs = %{
        reason: "User requested data deletion",
        request_ip: "127.0.0.1",
        request_user_agent: "Test Browser"
      }

      assert {:ok, updated_user} = User.request_deletion(user, attrs)
      assert updated_user.status == :deletion_requested
      assert updated_user.gdpr_deletion_requested_at != nil
      assert updated_user.gdpr_deletion_reason == "User requested data deletion"
      assert updated_user.gdpr_deletion_request_ip == "127.0.0.1"
      assert updated_user.gdpr_deletion_request_user_agent == "Test Browser"
    end

    test "soft deletes user account", %{user: user} do
      retention_expires = DateTime.add(DateTime.utc_now(), 30, :day)

      attrs = %{
        reason: "Account closure",
        retention_expires_at: retention_expires,
        request_ip: "192.168.1.1"
      }

      assert {:ok, deleted_user} = User.soft_delete(user, attrs)
      assert deleted_user.status == :deleted
      assert deleted_user.gdpr_deletion_requested_at != nil
      assert deleted_user.gdpr_deletion_reason == "Account closure"
      assert deleted_user.gdpr_retention_expires_at == retention_expires
    end

    test "restores user from deletion request", %{user: user} do
      # First request deletion
      {:ok, deleted_user} = User.request_deletion(user, %{reason: "Test"}, action: :register)

      # Then restore
      assert {:ok, restored_user} = User.restore_user(deleted_user)
      assert restored_user.status == :active
      assert restored_user.gdpr_deletion_requested_at == nil
      assert restored_user.gdpr_deletion_reason == nil
      assert restored_user.gdpr_retention_expires_at == nil
    end

    test "anonymizes user data", %{user: user} do
      {:ok, user_with_totp} =
        Ash.update(
          user,
          %{
            totp_secret: "test_secret",
            backup_codes: ["code1", "code2"]
          },
          action: :register
        )

      assert {:ok, anonymized_user} = User.anonymize_user(user_with_totp)
      assert anonymized_user.status == :anonymized
      assert anonymized_user.gdpr_anonymized_at != nil
      assert anonymized_user.first_name == "Deleted"
      assert anonymized_user.last_name == "User"
      assert anonymized_user.hashed_password == ""
      assert anonymized_user.totp_secret == nil
      assert anonymized_user.backup_codes == []
      assert String.starts_with?(anonymized_user.email, "deleted-")
      assert String.ends_with?(anonymized_user.email, "@deleted.local")
    end

    test "purges user data completely", %{user: user} do
      {:ok, user_with_data} =
        Ash.update(
          user,
          %{
            first_name: "John",
            last_name: "Doe",
            email: "john.doe@example.com",
            totp_secret: "secret",
            backup_codes: ["code1"],
            last_sign_in_at: DateTime.utc_now(),
            last_sign_in_ip: "127.0.0.1",
            sign_in_count: 5,
            gdpr_marketing_consent: true,
            gdpr_analytics_consent: true
          },
          action: :register
        )

      assert {:ok, purged_user} = User.purge_user(user_with_data)
      assert purged_user.status == :purged
      assert purged_user.email == nil
      assert purged_user.first_name == nil
      assert purged_user.last_name == nil
      assert purged_user.hashed_password == nil
      assert purged_user.totp_secret == nil
      assert purged_user.backup_codes == []
      assert purged_user.last_sign_in_at == nil
      assert purged_user.last_sign_in_ip == nil
      assert purged_user.sign_in_count == 0
      assert purged_user.failed_attempts == 0
      assert purged_user.gdpr_marketing_consent == false
      assert purged_user.gdpr_analytics_consent == false
    end

    test "updates GDPR consent preferences", %{user: user} do
      attrs = %{
        marketing_consent: true,
        analytics_consent: false
      }

      assert {:ok, updated_user} = User.update_gdpr_consent(user, attrs)
      assert updated_user.gdpr_marketing_consent == true
      assert updated_user.gdpr_analytics_consent == false
    end
  end

  describe "GDPR status queries" do
    test "finds users by GDPR status" do
      # Create users with different statuses
      {:ok, active_user} =
        User.register(
          %{
            first_name: "Active",
            last_name: "User",
            email: "active@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, deleted_user} =
        User.register(
          %{
            first_name: "Deleted",
            last_name: "User",
            email: "deleted@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, _deleted} = User.soft_delete(deleted_user, %{reason: "Test"}, action: :register)

      # Query by status
      {:ok, active_users} = User.by_gdpr_status(status: :active)
      {:ok, deleted_users} = User.by_gdpr_status(status: :deleted)

      assert length(active_users) >= 1
      assert Enum.any?(active_users, &(&1.id == active_user.id))
      assert length(deleted_users) >= 1
      assert Enum.any?(deleted_users, &(&1.id == deleted_user.id))
    end

    test "finds users overdue for anonymization" do
      # Create a user with past retention date
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Overdue",
            last_name: "User",
            email: "overdue@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      past_date = DateTime.add(DateTime.utc_now(), -1, :day)

      {:ok, deleted_user} =
        User.soft_delete(
          user,
          %{
            reason: "Test",
            retention_expires_at: past_date
          },
          action: :register
        )

      overdue_users = User.users_overdue_for_anonymization()

      assert length(overdue_users) >= 1
      assert Enum.any?(overdue_users, &(&1.id == deleted_user.id))
    end
  end

  describe "account lockout and security" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Security",
            last_name: "User",
            email: "security@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "initializes security fields correctly", %{user: user} do
      assert user.failed_attempts == 0
      assert user.locked_at == nil
      assert user.unlock_token == nil
      assert user.unlock_token_expires_at == nil
      assert user.sign_in_count == 0
      assert user.last_sign_in_at == nil
      assert user.last_sign_in_ip == nil
    end

    test "tracks sign-in information", %{user: user} do
      sign_in_time = DateTime.utc_now()
      sign_in_ip = "192.168.1.100"

      {:ok, updated_user} =
        Ash.update(
          user,
          %{
            last_sign_in_at: sign_in_time,
            last_sign_in_ip: sign_in_ip,
            sign_in_count: 1
          },
          action: :register
        )

      assert updated_user.last_sign_in_at == sign_in_time
      assert updated_user.last_sign_in_ip == sign_in_ip
      assert updated_user.sign_in_count == 1
    end
  end

  # Helper functions

  defp has_password_strength_error?(changeset) do
    errors = Ash.Changeset.errors(changeset)

    Enum.any?(errors, fn {field, messages} ->
      field == "password" and
        Enum.any?(
          messages,
          &String.contains?(&1, "uppercase, 1 lowercase, 1 number, and 1 special character")
        )
    end)
  end

  defp has_required_field_error?(changeset, field) do
    errors = Ash.Changeset.errors(changeset)

    Enum.any?(errors, fn {error_field, messages} ->
      error_field == to_string(field) and
        Enum.any?(messages, &String.contains?(&1, "must be present"))
    end)
  end

  defp has_length_error?(changeset, field) do
    errors = Ash.Changeset.errors(changeset)

    Enum.any?(errors, fn {error_field, messages} ->
      error_field == to_string(field) and
        Enum.any?(messages, &String.contains?(&1, "must be less than"))
    end)
  end

  defp has_unique_error?(changeset, field) do
    errors = Ash.Changeset.errors(changeset)

    Enum.any?(errors, fn {error_field, messages} ->
      error_field == to_string(field) and
        Enum.any?(messages, &String.contains?(&1, "has already been taken"))
    end)
  end
end
