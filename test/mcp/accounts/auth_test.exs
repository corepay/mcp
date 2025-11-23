defmodule Mcp.Accounts.AuthTest do
  use ExUnit.Case, async: true

  alias Mcp.Accounts.{User, Auth}

  describe "authentication" do
    test "authenticates user with valid credentials" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "John",
            last_name: "Doe",
            email: "john.doe@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Test authentication
      assert {:ok, session} =
               Auth.authenticate("john.doe@example.com", "Password123!", "127.0.0.1")

      assert session.access_token != nil
      assert session.refresh_token != nil
      assert session.user.id == user.id
      assert session.user.email == "john.doe@example.com"
    end

    test "fails authentication with invalid password" do
      # Create a test user
      {:ok, _user} =
        User.register(
          %{
            first_name: "Jane",
            last_name: "Smith",
            email: "jane.smith@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Test authentication with wrong password
      assert {:error, :invalid_credentials} =
               Auth.authenticate("jane.smith@example.com", "wrongpassword", "127.0.0.1")
    end

    test "fails authentication with non-existent email" do
      # Test authentication with non-existent email
      assert {:error, :invalid_credentials} =
               Auth.authenticate("nonexistent@example.com", "Password123!", "127.0.0.1")
    end

    test "fails authentication for inactive account" do
      # Create a test user and then suspend it
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Bob",
            last_name: "Wilson",
            email: "bob.wilson@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Suspend the user
      {:ok, _user} = User.update(user, %{status: :suspended}, action: :register)

      # Test authentication
      assert {:error, :account_inactive} =
               Auth.authenticate("bob.wilson@example.com", "Password123!", "127.0.0.1")
    end
  end

  describe "account lockout" do
    test "locks account after 5 failed attempts" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Alice",
            last_name: "Johnson",
            email: "alice.johnson@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Record 5 failed attempts
      for _i <- 1..5 do
        Auth.record_failed_attempt("alice.johnson@example.com")
      end

      # Try to authenticate - should fail due to lockout
      assert {:error, :account_locked} =
               Auth.authenticate("alice.johnson@example.com", "Password123!", "127.0.0.1")

      # Verify user is locked
      {:ok, updated_user} =
        User.by_email(%{email: "alice.johnson@example.com"}, action: :register) |> Ash.read()

      assert hd(updated_user).locked_at != nil
      assert hd(updated_user).failed_attempts >= 5
      assert hd(updated_user).unlock_token != nil
    end

    test "does not lock account with less than 5 failed attempts" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Charlie",
            last_name: "Brown",
            email: "charlie.brown@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Record 3 failed attempts
      for _i <- 1..3 do
        Auth.record_failed_attempt("charlie.brown@example.com")
      end

      # Should still be able to authenticate
      assert {:ok, _session} =
               Auth.authenticate("charlie.brown@example.com", "Password123!", "127.0.0.1")
    end
  end

  describe "session management" do
    test "creates valid session tokens" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "David",
            last_name: "Lee",
            email: "david.lee@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Create session
      {:ok, session} = Auth.authenticate("david.lee@example.com", "Password123!", "127.0.0.1")

      # Verify access token
      assert {:ok, _token} = Auth.verify_session(session.access_token)

      # Verify refresh token
      assert {:ok, _token} = Auth.verify_session(session.refresh_token)
    end

    test "revokes session tokens" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Eva",
            last_name: "Garcia",
            email: "eva.garcia@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Create session
      {:ok, session} = Auth.authenticate("eva.garcia@example.com", "Password123!", "127.0.0.1")

      # Revoke session
      assert :ok = Auth.revoke_session(session.access_token)

      # Token should now be invalid
      assert {:error, :token_revoked} = Auth.verify_session(session.access_token)
    end

    test "revokes all user sessions" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Frank",
            last_name: "Miller",
            email: "frank.miller@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Create multiple sessions
      {:ok, session1} = Auth.authenticate("frank.miller@example.com", "Password123!", "127.0.0.1")

      {:ok, session2} =
        Auth.authenticate("frank.miller@example.com", "Password123!", "192.168.1.1")

      # Revoke all sessions
      Auth.revoke_user_sessions(user.id)

      # Both tokens should now be invalid
      assert {:error, :token_revoked} = Auth.verify_session(session1.access_token)
      assert {:error, :token_revoked} = Auth.verify_session(session2.access_token)
    end
  end

  describe "sign-in tracking" do
    test "updates sign-in information on successful login" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Grace",
            last_name: "Kim",
            email: "grace.kim@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Authenticate
      {:ok, _session} =
        Auth.authenticate("grace.kim@example.com", "Password123!", "192.168.1.100")

      # Check that sign-in info was updated
      {:ok, updated_user} =
        User.by_email(%{email: "grace.kim@example.com"}, action: :register) |> Ash.read()

      updated_user = hd(updated_user)

      assert updated_user.last_sign_in_at != nil
      assert updated_user.last_sign_in_ip == "192.168.1.100"
      assert updated_user.sign_in_count == 1
      assert updated_user.failed_attempts == 0
    end

    test "increments sign-in count on multiple logins" do
      # Create a test user
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Henry",
            last_name: "Davis",
            email: "henry.davis@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # First login
      {:ok, _session1} = Auth.authenticate("henry.davis@example.com", "Password123!", "127.0.0.1")

      # Second login
      {:ok, _session2} =
        Auth.authenticate("henry.davis@example.com", "Password123!", "192.168.1.1")

      # Check that sign-in count was incremented
      {:ok, updated_user} =
        User.by_email(%{email: "henry.davis@example.com"}, action: :register) |> Ash.read()

      assert hd(updated_user).sign_in_count == 2
    end
  end
end
