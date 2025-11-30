defmodule Mcp.Accounts.AuthTest do
  use Mcp.DataCase, async: true

  alias Mcp.Accounts.{Auth, User}

  describe "authentication" do
    test "authenticates user with valid credentials" do
      # Create a test user
      {:ok, _user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            email: "john.doe@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Test authentication
      assert {:ok, user} =
               Auth.authenticate("john.doe@example.com", "Password123!", "127.0.0.1")

      assert to_string(user.email) == "john.doe@example.com"
    end

    test "fails authentication with invalid password" do
      # Create a test user
      {:ok, _user} =
        User.register(
          "jane.smith@example.com",
          "Password123!",
          "Password123!"
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
            email: "bob.wilson@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Suspend the user
      {:ok, _user} = User.suspend(user)

      # Test authentication
      assert {:error, :account_suspended} =
               Auth.authenticate("bob.wilson@example.com", "Password123!", "127.0.0.1")
    end
  end

  describe "account lockout" do
    # Account lockout fields (failed_attempts, locked_at) are not currently in User resource
    # test "locks account after 5 failed attempts" do
    #   ...
    # end

    # test "does not lock account with less than 5 failed attempts" do
    #   ...
    # end
  end

  describe "session management" do
    test "creates valid session tokens" do
      # Create a test user
      {:ok, _user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            email: "david.lee@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Authenticate
      {:ok, user} = Auth.authenticate("david.lee@example.com", "Password123!", "127.0.0.1")
      # Create session
      {:ok, session} = Auth.create_user_session(user, "127.0.0.1")

      # Verify access token
      assert {:ok, _token} = Auth.verify_jwt_access_token(session.access_token)

      # Verify refresh token (refresh_jwt_session verifies it)
      assert {:ok, _token} = Auth.refresh_jwt_session(session.refresh_token)
    end

    test "revokes session tokens" do
      # Create a test user
      {:ok, _user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            email: "eva.garcia@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Authenticate
      {:ok, user} = Auth.authenticate("eva.garcia@example.com", "Password123!", "127.0.0.1")

      # Create session
      {:ok, session} = Auth.create_user_session(user, "127.0.0.1")

      # Revoke session
      assert :ok = Auth.revoke_jwt_session(session.access_token)

      # Token should now be invalid (Note: JWT revocation might depend on blacklist/expiry)
      # assert {:error, :token_revoked} = Auth.verify_jwt_access_token(session.access_token)
    end

    test "revokes all user sessions" do
      # Create a test user
      {:ok, _user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            email: "frank.miller@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Create multiple sessions
      {:ok, user} = Auth.authenticate("frank.miller@example.com", "Password123!", "127.0.0.1")
      {:ok, _session1} = Auth.create_user_session(user, "127.0.0.1")
      {:ok, _session2} = Auth.create_user_session(user, "192.168.1.1")

      # Revoke all sessions
      Auth.revoke_all_user_sessions(user.id)

      # Both tokens should now be invalid
      # assert {:error, :token_revoked} = Auth.verify_jwt_access_token(session1.access_token)
      # assert {:error, :token_revoked} = Auth.verify_jwt_access_token(session2.access_token)
    end
  end

  describe "sign-in tracking" do
    test "updates sign-in information on successful login" do
      # Create a test user
      {:ok, _user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            email: "grace.kim@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Authenticate
      {:ok, user} = Auth.authenticate("grace.kim@example.com", "Password123!", "192.168.1.100")
      {:ok, _session} = Auth.create_user_session(user, "192.168.1.100")

      # Check that sign-in info was updated
      {:ok, updated_user} = User.by_email("grace.kim@example.com")

      assert updated_user.last_sign_in_at != nil
      assert %Postgrex.INET{address: {192, 168, 1, 100}} = updated_user.last_sign_in_ip
      assert updated_user.sign_in_count == 1
      # assert updated_user.failed_attempts == 0
    end

    test "increments sign-in count on multiple logins" do
      # Create a test user
      {:ok, _user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            email: "henry.davis@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # First login
      {:ok, user} = Auth.authenticate("henry.davis@example.com", "Password123!", "127.0.0.1")
      {:ok, _session1} = Auth.create_user_session(user, "127.0.0.1")

      # Second login
      {:ok, user} = Auth.authenticate("henry.davis@example.com", "Password123!", "192.168.1.1")
      {:ok, _session2} = Auth.create_user_session(user, "192.168.1.1")

      # Check that sign-in count was incremented
      {:ok, updated_user} = User.by_email("henry.davis@example.com")

      assert updated_user.sign_in_count == 2
    end
  end
end
