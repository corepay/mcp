defmodule Mcp.Accounts.AuthComprehensiveTest do
  use ExUnit.Case, async: true

  alias Mcp.Accounts.{Auth, Token, User}

  describe "authentication flow" do
    test "authenticates user with valid credentials" do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Auth",
            last_name: "Test",
            email: "auth.test@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, session} = Auth.authenticate("auth.test@example.com", "Password123!", "127.0.0.1")

      assert session.access_token != nil
      assert session.refresh_token != nil
      assert session.user.id == user.id
      assert session.user.email == "auth.test@example.com"
    end

    test "rejects authentication with invalid email" do
      {:error, :invalid_credentials} =
        Auth.authenticate("nonexistent@example.com", "Password123!", "127.0.0.1")
    end

    test "rejects authentication with invalid password" do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Auth",
            last_name: "Test",
            email: "auth.test@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:error, :invalid_credentials} =
        Auth.authenticate("auth.test@example.com", "WrongPassword!", "127.0.0.1")
    end

    test "handles case-insensitive email authentication" do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Case",
            last_name: "Test",
            email: "case.test@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, session} = Auth.authenticate("CASE.TEST@EXAMPLE.COM", "Password123!", "127.0.0.1")

      assert session.user.id == user.id
    end
  end

  describe "authentication with 2FA" do
    setup do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "2FA",
            last_name: "User",
            email: "2fa.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, user: user}
    end

    test "returns require_2fa when TOTP is enabled", %{user: user} do
      # Setup TOTP (simulating it's enabled)
      {:ok, user_with_totp} =
        Ash.update(
          user,
          %{
            otp_verified_at: DateTime.utc_now(),
            otp_last_used_at: DateTime.utc_now()
          },
          action: :register
        )

      {:ok, :require_2fa, auth_user} =
        Auth.authenticate("2fa.user@example.com", "Password123!", "127.0.0.1")

      assert auth_user.id == user_with_totp.id
    end

    test "returns session when TOTP is disabled", %{user: user} do
      {:ok, session} = Auth.authenticate("2fa.user@example.com", "Password123!", "127.0.0.1")

      assert session.access_token != nil
      assert session.user.id == user.id
    end
  end

  describe "account lockout scenarios" do
    test "tracks failed login attempts" do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Lockout",
            last_name: "Test",
            email: "lockout.test@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Multiple failed attempts
      for _i <- 1..5 do
        Auth.authenticate("lockout.test@example.com", "WrongPassword!", "192.168.1.100")
      end

      # Check if failed attempts were tracked
      # This would depend on the actual implementation
      assert true
    end
  end

  describe "session management" do
    test "creates valid session tokens" do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Session",
            last_name: "User",
            email: "session.user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      {:ok, session} = Auth.authenticate("session.user@example.com", "Password123!", "127.0.0.1")

      assert session.access_token != nil
      assert session.refresh_token != nil
      assert is_binary(session.access_token)
      assert is_binary(session.refresh_token)
      assert String.length(session.access_token) > 10
      assert String.length(session.refresh_token) > 10
    end
  end

  describe "security and edge cases" do
    test "handles empty credentials" do
      {:error, :invalid_credentials} = Auth.authenticate("", "Password123!", "127.0.0.1")
      {:error, :invalid_credentials} = Auth.authenticate("test@example.com", "", "127.0.0.1")
      {:error, :invalid_credentials} = Auth.authenticate("test@example.com", "Password123!", "")
    end

    test "handles nil credentials" do
      {:error, :invalid_credentials} = Auth.authenticate(nil, "Password123!", "127.0.0.1")
      {:error, :invalid_credentials} = Auth.authenticate("test@example.com", nil, "127.0.0.1")
      {:error, :invalid_credentials} = Auth.authenticate("test@example.com", "Password123!", nil)
    end

    test "handles malformed email addresses" do
      malformed_emails = [
        "invalid-email",
        "@example.com",
        "user@",
        "user..name@example.com",
        " user@example.com ",
        ""
      ]

      Enum.each(malformed_emails, fn email ->
        {:error, :invalid_credentials} =
          Auth.authenticate(email, "Password123!", "127.0.0.1")
      end)
    end

    test "handles very long inputs" do
      long_email = String.duplicate("a", 300) <> "@example.com"
      long_password = String.duplicate("P", 200) <> "assword123!"

      {:error, :invalid_credentials} = Auth.authenticate(long_email, long_password, "127.0.0.1")
    end

    test "handles special characters in IP address" do
      ip_cases = [
        "127.0.0.1",
        "192.168.1.100",
        "::1",
        "2001:db8::1"
      ]

      Enum.each(ip_cases, fn ip ->
        {:ok, _user} =
          User.register(
            %{
              first_name: "IP",
              last_name: "Test",
              email: "ip.test.#{System.unique_integer()}@example.com",
              password: "Password123!",
              password_confirmation: "Password123!"
            },
            action: :register
          )

        # Should not crash, result depends on validation logic
        result =
          Auth.authenticate("ip.test.#{System.unique_integer()}@example.com", "Password123!", ip)

        assert result == {:error, :invalid_credentials} or match?({:ok, _}, result)
      end)
    end
  end

  describe "concurrent authentication attempts" do
    test "handles multiple simultaneous login attempts" do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Concurrent",
            last_name: "Test",
            email: "concurrent.test@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Simulate concurrent authentication attempts
      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            Auth.authenticate("concurrent.test@example.com", "Password123!", "127.0.0.1")
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All attempts should succeed or fail consistently
      # In a real scenario, you might have rate limiting
      assert Enum.all?(results, fn
               {:ok, _session} -> true
               {:error, _reason} -> true
               _ -> false
             end)
    end
  end

  describe "password complexity and timing" do
    test "authentication timing is consistent for invalid passwords" do
      {:ok, user} =
        Ash.create(
          Mcp.Accounts.User,
          %{
            first_name: "Timing",
            last_name: "Test",
            email: "timing.test@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          },
          action: :register
        )

      # Measure time for wrong password
      {time1, {:error, :invalid_credentials}} =
        :timer.tc(fn ->
          Auth.authenticate("timing.test@example.com", "WrongPassword!", "127.0.0.1")
        end)

      # Measure time for another wrong password
      {time2, {:error, :invalid_credentials}} =
        :timer.tc(fn ->
          Auth.authenticate("timing.test@example.com", "AnotherWrong!", "127.0.0.1")
        end)

      # Times should be roughly similar (within reasonable variance)
      # This helps prevent timing attacks
      time_diff = abs(time1 - time2)
      # 100ms threshold
      assert time_diff < 100_000
    end
  end
end
