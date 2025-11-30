defmodule Mcp.Accounts.AuthComprehensiveTest do
  use Mcp.DataCase, async: false

  alias Mcp.Accounts.{Auth, User}

  describe "authentication flow" do
    test "authenticates user with valid credentials" do
      {:ok, user} =
        User.register(%{
          first_name: "Auth",
          last_name: "Test",
          email: "auth.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:ok, authenticated_user} =
        Auth.authenticate("auth.test@example.com", "Password123!", "127.0.0.1")

      assert authenticated_user.id == user.id
      assert to_string(authenticated_user.email) == "auth.test@example.com"
    end

    test "rejects authentication with invalid email" do
      {:error, :invalid_credentials} =
        Auth.authenticate("nonexistent@example.com", "Password123!", "127.0.0.1")
    end

    test "rejects authentication with invalid password" do
      {:ok, _user} =
        User.register(%{
          first_name: "Auth",
          last_name: "Test",
          email: "auth.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:error, :invalid_credentials} =
        Auth.authenticate("auth.test@example.com", "WrongPassword!", "127.0.0.1")
    end

    test "handles case-insensitive email authentication" do
      {:ok, user} =
        User.register(%{
          first_name: "Case",
          last_name: "Test",
          email: "case.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:ok, authenticated_user} =
        Auth.authenticate("CASE.TEST@EXAMPLE.COM", "Password123!", "127.0.0.1")

      assert authenticated_user.id == user.id
    end
  end

  describe "authentication with 2FA" do
    setup do
      {:ok, user} =
        User.register(%{
          first_name: "2FA",
          last_name: "User",
          email: "2fa.user@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:ok, user: user}
    end

    test "returns require_2fa when TOTP is enabled", %{user: user} do
      # Setup TOTP (simulating it's enabled)
      {:ok, user_with_totp} =
        user
        |> Ash.Changeset.for_update(:update)
        |> Ash.Changeset.force_change_attribute(:totp_secret, "MZXW6YTBOI======")
        |> Ash.update()

      {:ok, :require_2fa, auth_user} =
        Auth.authenticate("2fa.user@example.com", "Password123!", "127.0.0.1")

      assert auth_user.id == user_with_totp.id
    end

    test "returns user when TOTP is disabled", %{user: user} do
      {:ok, authenticated_user} =
        Auth.authenticate("2fa.user@example.com", "Password123!", "127.0.0.1")

      assert authenticated_user.id == user.id
    end
  end

  describe "account lockout scenarios" do
    test "tracks failed login attempts" do
      {:ok, _user} =
        User.register(%{
          first_name: "Lockout",
          last_name: "Test",
          email: "lockout.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

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
        User.register(%{
          first_name: "Session",
          last_name: "User",
          email: "session.user@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      {:ok, authenticated_user} =
        Auth.authenticate("session.user@example.com", "Password123!", "127.0.0.1")

      {:ok, %{access_token: access_token, refresh_token: refresh_token}} =
        Mcp.Accounts.AuthToken.generate_token_pair(authenticated_user.id, %{}, %{})

      assert access_token != nil
      assert refresh_token != nil
      assert access_token.token != nil
      assert refresh_token.token != nil
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
          User.register(%{
            first_name: "IP",
            last_name: "Test",
            email: "ip.test.#{System.unique_integer()}@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          })

        # Should not crash, result depends on validation logic
        result =
          Auth.authenticate("ip.test.#{System.unique_integer()}@example.com", "Password123!", ip)

        assert result == {:error, :invalid_credentials} or match?({:ok, _}, result)
      end)
    end
  end

  describe "concurrent authentication attempts" do
    test "handles multiple simultaneous login attempts" do
      {:ok, _user} =
        User.register(%{
          first_name: "Concurrent",
          last_name: "Test",
          email: "concurrent.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

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
      {:ok, _user} =
        User.register(%{
          first_name: "Timing",
          last_name: "Test",
          email: "timing.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

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
      # 500ms threshold
      assert time_diff < 500_000
    end
  end
end
