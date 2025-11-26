defmodule Mcp.Accounts.AuthRealTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  alias Ecto.Adapters.SQL.Sandbox
  alias Mcp.Accounts.{Auth, User}
  alias Mcp.Repo

  setup do
    Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  describe "authenticate/3" do
    test "authenticates user with valid credentials" do
      # RED - First write a test that should fail
      # Create a user with known password
      email = "test@example.com"
      password = "TestPassword123!"

      {:ok, user} = User.register(email, password, password)

      # Test authentication
      assert {:ok, authenticated_user} = Auth.authenticate(email, password)
      assert authenticated_user.id == user.id
      assert to_string(authenticated_user.email) == email
    end

    test "rejects authentication with invalid password" do
      # Create a user
      email = "test2@example.com"
      password = "CorrectPassword123!"

      {:ok, _user} = User.register(email, password, password)

      # Test with wrong password
      assert {:error, :invalid_credentials} = Auth.authenticate(email, "WrongPassword")
    end

    test "rejects authentication for non-existent user" do
      assert {:error, :invalid_credentials} =
               Auth.authenticate("nonexistent@example.com", "anypassword")
    end

    test "rejects authentication for suspended user" do
      # Create and suspend a user
      email = "suspended@example.com"
      password = "Password123!"

      {:ok, user} = User.register(email, password, password)
      User.suspend(user)

      # Test authentication
      assert {:error, :account_suspended} = Auth.authenticate(email, password)
    end

    test "rejects authentication for deleted user" do
      # Create and soft delete a user
      email = "deleted@example.com"
      password = "Password123!"

      {:ok, user} = User.register(email, password, password)
      User.soft_delete(user)

      # Test authentication
      assert {:error, :account_deleted} = Auth.authenticate(email, password)
    end
  end

  describe "create_user_session/2" do
    test "creates session for authenticated user" do
      # Create a user
      email = "session@example.com"
      password = "Password123!"

      {:ok, user} = User.register(email, password, password)

      # Create session
      assert {:ok, session} = Auth.create_user_session(user, "127.0.0.1")
      assert session.user_id == user.id
      assert is_binary(session.session_id)
    end

    test "updates sign-in information" do
      # Create a user
      email = "signin@example.com"
      password = "Password123!"

      {:ok, user} = User.register(email, password, password)

      # Create session with IP
      ip_address = "192.168.1.100"
      assert {:ok, _session} = Auth.create_user_session(user, ip_address)

      # Verify user's sign-in info was updated
      updated_user = User.by_id(user.id)
      assert updated_user.last_sign_in_ip == ip_address
      assert updated_user.sign_in_count == 1
      assert updated_user.last_sign_in_at != nil
    end
  end

  describe "verify_jwt_access_token/1" do
    test "verifies valid JWT token" do
      # Create a user
      email = "jwt@example.com"
      password = "Password123!"

      {:ok, user} = User.register(email, password, password)

      # Create session with JWT
      assert {:ok, session} = Auth.create_user_session(user)

      # Verify the JWT token
      assert {:ok, claims} = Auth.verify_jwt_access_token(session.access_token)
      assert claims["sub"] == user.id
      assert claims["type"] == "access"
    end

    test "rejects invalid JWT token" do
      assert {:error, :invalid_token} = Auth.verify_jwt_access_token("invalid.token.here")
    end
  end
end
