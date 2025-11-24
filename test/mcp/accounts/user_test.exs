defmodule Mcp.Accounts.UserTest do
  use ExUnit.Case, async: false

  alias Mcp.Accounts.User

  describe "user registration" do
    test "creates a user with valid data" do
      email = "john.doe@example.com"
      password = "Password123!"

      assert {:ok, user} = User.register(email, password, password)
      assert user.email == email
      assert user.status == :active
      assert user.hashed_password != nil
      assert user.confirmed_at == nil
      assert user.totp_secret == nil
      assert user.backup_codes == []
    end

    test "requires password confirmation to match" do
      email = "john.doe@example.com"
      password = "Password123!"
      wrong_confirmation = "DifferentPassword!"

      assert {:error, error} = User.register(email, password, wrong_confirmation)
      assert %Ash.Error.Invalid{} = error
      # Check that the error is about password confirmation
      error_message = inspect(error)
      assert String.contains?(error_message, "confirmation")
    end

    test "requires valid email format" do
      email = "invalid-email"
      password = "Password123!"

      assert {:error, error} = User.register(email, password, password)
      assert %Ash.Error.Invalid{} = error
      # Check that the error is about email validation
      error_message = inspect(error)
      assert String.contains?(error_message, "email")
    end

    test "validates email uniqueness" do
      email = "unique@example.com"
      password = "Password123!"

      assert {:ok, _user1} = User.register(email, password, password)
      assert {:error, changeset} = User.register(email, password, password)
      refute changeset.valid?
    end

    test "handles different email cases correctly" do
      email1 = "test@example.com"
      email2 = "TEST@EXAMPLE.COM"
      password = "Password123!"

      assert {:ok, _user1} = User.register(email1, password, password)
      assert {:error, changeset} = User.register(email2, password, password)
      refute changeset.valid?
    end
  end

  describe "user lookup" do
    setup do
      {:ok, user} = User.register("lookup@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "finds user by email", %{user: user} do
      assert {:ok, found_user} = User.by_email("lookup@example.com")
      assert found_user.id == user.id
    end

    test "finds user by id", %{user: user} do
      assert {:ok, found_user} = User.by_id(user.id)
      assert found_user.id == user.id
    end

    test "returns error for non-existent user" do
      assert {:error, _} = User.by_email("nonexistent@example.com")
      assert {:error, _} = User.by_id(Ecto.UUID.generate())
    end

    test "finds only active users", %{user: user} do
      # User should be active by default
      active_users = User.active_users()
      assert length(active_users.results) > 0
      assert Enum.any?(active_users.results, fn u -> u.id == user.id end)
    end
  end

  describe "user status management" do
    setup do
      {:ok, user} = User.register("status@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "suspends user", %{user: user} do
      assert {:ok, suspended_user} = User.suspend(user)
      assert suspended_user.status == :suspended
    end

    test "activates user", %{user: user} do
      # First suspend
      assert {:ok, suspended_user} = User.suspend(user)
      assert suspended_user.status == :suspended

      # Then activate
      assert {:ok, active_user} = User.activate(suspended_user)
      assert active_user.status == :active
    end

    test "soft deletes user", %{user: user} do
      assert {:ok, deleted_user} = User.soft_delete(user)
      assert deleted_user.status == :deleted
    end

    test "updates sign in information", %{user: user} do
      ip_address = "192.168.1.1"

      assert {:ok, updated_user} = User.update_sign_in(user, ip_address)
      assert updated_user.last_sign_in_ip == ip_address
      assert updated_user.sign_in_count == 1
      assert updated_user.last_sign_in_at != nil
    end
  end

  describe "user updates" do
    setup do
      {:ok, user} = User.register("update@example.com", "Password123!", "Password123!")
      {:ok, user: user}
    end

    test "updates user email", %{user: user} do
      new_email = "updated@example.com"

      assert {:ok, updated_user} = User.update(user, %{email: new_email})
      assert updated_user.email == new_email
    end

    test "updates user status", %{user: user} do
      assert {:ok, updated_user} = User.update(user, %{status: :suspended})
      assert updated_user.status == :suspended
    end

    test "rejects invalid status values", %{user: user} do
      assert {:error, error} = User.update(user, %{status: :invalid_status})
      assert %Ash.Error.Invalid{} = error
      error_message = inspect(error)
      assert String.contains?(error_message, "status")
    end
  end

  describe "user deletion" do
    test "hard deletes user" do
      {:ok, user} = User.register("delete@example.com", "Password123!", "Password123!")

      assert {:ok, _} = User.destroy(user)

      # Verify user is gone
      assert {:error, _} = User.by_id(user.id)
    end
  end

  describe "compatibility functions" do
    test "get/1 works as alias for by_id/1" do
      {:ok, user} = User.register("compat@example.com", "Password123!", "Password123!")

      assert User.get(user.id) == User.by_id(user.id)
    end

    test "get_by_email/1 works as alias for by_email/1" do
      {:ok, _user} = User.register("compat2@example.com", "Password123!", "Password123!")

      assert User.get_by_email("compat2@example.com") == User.by_email("compat2@example.com")
    end

    test "create/1 works with map interface" do
      attrs = %{
        "email" => "create@example.com",
        "password" => "Password123!",
        "password_confirmation" => "Password123!"
      }

      assert {:ok, user} = User.create(attrs)
      assert user.email == "create@example.com"
    end
  end

  describe "2FA fields" do
    test "user has TOTP fields initialized correctly" do
      {:ok, user} = User.register("2fa@example.com", "Password123!", "Password123!")

      assert user.totp_secret == nil
      assert user.backup_codes == []
    end

    test "OAuth tokens are initialized correctly" do
      {:ok, user} = User.register("oauth@example.com", "Password123!", "Password123!")

      assert user.oauth_tokens == %{}
    end

    test "session tracking fields are initialized correctly" do
      {:ok, user} = User.register("session@example.com", "Password123!", "Password123!")

      assert user.last_sign_in_at == nil
      assert user.last_sign_in_ip == nil
      assert user.sign_in_count == 0
    end
  end

  describe "pagination and filtering" do
    setup do
      # Create multiple users for testing
      users = for i <- 1..5 do
        {:ok, user} = User.register("user#{i}@example.com", "Password123!", "Password123!")
        user
      end

      {:ok, users: users}
    end

    test "read action returns paginated results" do
      result = User.read()
      assert is_map(result)
      assert is_list(result.results)
      assert length(result.results) >= 5
    end

    test "active_users filter works correctly", %{users: users} do
      result = User.active_users()
      assert length(result.results) >= length(users)

      # All users should be active by default
      Enum.each(users, fn user ->
        assert Enum.any?(result.results, fn u -> u.id == user.id end)
      end)
    end
  end
end