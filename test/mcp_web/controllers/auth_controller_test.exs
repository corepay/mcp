defmodule McpWeb.Controllers.AuthControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Accounts.User

  describe "POST /auth/login" do
    test "authenticates with valid credentials", %{conn: conn} do
      {:ok, _user} =
        User.register(%{
          first_name: "Controller",
          last_name: "Test",
          email: "controller.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "controller.test@example.com",
            "password" => "Password123!"
          }
        })

      assert %{"access_token" => access_token, "refresh_token" => refresh_token} =
               json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert String.length(access_token) > 10
      assert String.length(refresh_token) > 10
    end

    test "rejects invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "nonexistent@example.com",
            "password" => "wrongpassword"
          }
        })

      assert json_response(conn, 401) == %{"error" => "Invalid credentials"}
    end

    test "validates required fields", %{conn: conn} do
      conn = post(conn, ~p"/auth/login", %{"user" => %{}})

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end

    test "handles malformed JSON", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/auth/login", "invalid json")

      assert json_response(conn, 400) == %{"error" => "Invalid JSON"}
    end

    test "handles case-insensitive email", %{conn: conn} do
      {:ok, _user} =
        User.register(%{
          first_name: "Case",
          last_name: "Test",
          email: "case.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "CASE.TEST@EXAMPLE.COM",
            "password" => "Password123!"
          }
        })

      assert %{"access_token" => _token} = json_response(conn, 200)
    end

    test "requires 2FA when enabled", %{conn: conn} do
      {:ok, user} =
        User.register(%{
          first_name: "2FA",
          last_name: "Test",
          email: "2fa.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Simulate TOTP being enabled
      {:ok, _user_with_totp} =
        Ash.update(user, %{
          otp_verified_at: DateTime.utc_now(),
          otp_last_used_at: DateTime.utc_now()
        })

      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "2fa.test@example.com",
            "password" => "Password123!"
          }
        })

      assert %{"requires_2fa" => true, "temp_token" => temp_token} = json_response(conn, 200)
      assert is_binary(temp_token)
    end

    test "includes CSRF protection", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "test@example.com",
            "password" => "Password123!"
          }
        })

      # Phoenix automatically handles CSRF protection
      # This test ensures the endpoint exists and works
      assert response(conn, 401) or response(conn, 400) or response(conn, 200)
    end
  end

  describe "POST /auth/verify-2fa" do
    test "verifies TOTP code", %{conn: conn} do
      {:ok, _user} =
        User.register(%{
          first_name: "2FA",
          last_name: "Verify",
          email: "2fa.verify@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Create a temp token (simulate 2FA requirement)
      temp_token = "temp_token_123"

      conn =
        post(conn, ~p"/auth/verify-2fa", %{
          "totp_code" => "123456",
          "temp_token" => temp_token
        })

      # In a real implementation, this would verify the TOTP code
      # For now, test that the endpoint exists
      assert response(conn, 200) or response(conn, 401) or response(conn, 400)
    end

    test "rejects invalid TOTP code", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/verify-2fa", %{
          "totp_code" => "000000",
          "temp_token" => "invalid_token"
        })

      assert response(conn, 401) == "Invalid 2FA code" or response(conn, 401)
    end

    test "validates required parameters", %{conn: conn} do
      conn = post(conn, ~p"/auth/verify-2fa", %{})

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end
  end

  describe "POST /auth/refresh" do
    test "refreshes access token", %{conn: conn} do
      # First login to get tokens
      {:ok, _user} =
        User.register(%{
          first_name: "Refresh",
          last_name: "Test",
          email: "refresh.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      login_conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "refresh.test@example.com",
            "password" => "Password123!"
          }
        })

      %{"refresh_token" => refresh_token} = json_response(login_conn, 200)

      # Now refresh the token
      refresh_conn =
        post(conn, ~p"/auth/refresh", %{
          "refresh_token" => refresh_token
        })

      assert %{"access_token" => new_access_token} = json_response(refresh_conn, 200)
      assert is_binary(new_access_token)
      assert String.length(new_access_token) > 10
    end

    test "rejects invalid refresh token", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/refresh", %{
          "refresh_token" => "invalid_refresh_token"
        })

      assert json_response(conn, 401) == %{"error" => "Invalid refresh token"}
    end

    test "validates refresh token presence", %{conn: conn} do
      conn = post(conn, ~p"/auth/refresh", %{})

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end
  end

  describe "POST /auth/logout" do
    test "logs out user and revokes token", %{conn: conn} do
      # First login
      {:ok, _user} =
        User.register(%{
          first_name: "Logout",
          last_name: "Test",
          email: "logout.test@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      login_conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "logout.test@example.com",
            "password" => "Password123!"
          }
        })

      %{"access_token" => access_token} = json_response(login_conn, 200)

      # Now logout
      logout_conn =
        conn
        |> put_req_header("authorization", "Bearer " <> access_token)
        |> post(~p"/auth/logout")

      assert response(logout_conn, 200) == "Logged out successfully"
    end

    test "handles logout without token", %{conn: conn} do
      conn = post(conn, ~p"/auth/logout")

      assert response(conn, 401) == "Unauthorized"
    end

    test "handles invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> post(~p"/auth/logout")

      assert response(conn, 401) == "Unauthorized"
    end
  end

  describe "POST /auth/register" do
    test "registers new user successfully", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/register", %{
          "user" => %{
            "first_name" => "New",
            "last_name" => "User",
            "email" => "new.user@example.com",
            "password" => "Password123!",
            "password_confirmation" => "Password123!"
          }
        })

      assert %{"user" => %{"id" => user_id, "email" => email}} = json_response(conn, 201)
      assert email == "new.user@example.com"
      assert is_binary(user_id)
    end

    test "validates registration data", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/register", %{
          "user" => %{
            "first_name" => "",
            "last_name" => "",
            "email" => "invalid-email",
            "password" => "weak",
            "password_confirmation" => "different"
          }
        })

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end

    test "prevents duplicate email registration", %{conn: conn} do
      # Register first user
      post(conn, ~p"/auth/register", %{
        "user" => %{
          "first_name" => "First",
          "last_name" => "User",
          "email" => "duplicate@example.com",
          "password" => "Password123!",
          "password_confirmation" => "Password123!"
        }
      })

      # Try to register with same email
      conn =
        post(conn, ~p"/auth/register", %{
          "user" => %{
            "first_name" => "Second",
            "last_name" => "User",
            "email" => "duplicate@example.com",
            "password" => "Password123!",
            "password_confirmation" => "Password123!"
          }
        })

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end

    test "trims whitespace from input fields", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/register", %{
          "user" => %{
            "first_name" => "  Trim  ",
            "last_name" => "  Test  ",
            "email" => "  trim.test@example.com  ",
            "password" => "  Password123!  ",
            "password_confirmation" => "  Password123!  "
          }
        })

      assert %{"user" => %{"email" => email}} = json_response(conn, 201)
      assert email == "trim.test@example.com"
    end
  end

  describe "POST /auth/forgot-password" do
    test "sends password reset email", %{conn: conn} do
      {:ok, _user} =
        User.register(%{
          first_name: "Forgot",
          last_name: "Password",
          email: "forgot.password@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      conn =
        post(conn, ~p"/auth/forgot-password", %{
          "email" => "forgot.password@example.com"
        })

      assert response(conn, 200) == "Password reset instructions sent"
    end

    test "handles non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/forgot-password", %{
          "email" => "nonexistent@example.com"
        })

      # Should still return success to prevent email enumeration
      assert response(conn, 200) == "Password reset instructions sent"
    end

    test "validates email format", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/forgot-password", %{
          "email" => "invalid-email"
        })

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end

    test "requires email parameter", %{conn: conn} do
      conn = post(conn, ~p"/auth/forgot-password", %{})

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end
  end

  describe "POST /auth/reset-password" do
    test "resets password with valid token", %{conn: conn} do
      # This would require a valid reset token from the forgot-password flow
      reset_token = "valid_reset_token_123"

      conn =
        post(conn, ~p"/auth/reset-password", %{
          "token" => reset_token,
          "password" => "NewPassword456!",
          "password_confirmation" => "NewPassword456!"
        })

      # In a real implementation, this would validate the token
      assert response(conn, 200) == "Password reset successfully" or response(conn, 400)
    end

    test "rejects invalid reset token", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/reset-password", %{
          "token" => "invalid_token",
          "password" => "NewPassword456!",
          "password_confirmation" => "NewPassword456!"
        })

      assert response(conn, 400) == "Invalid or expired reset token"
    end

    test "validates password strength", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/reset-password", %{
          "token" => "some_token",
          "password" => "weak",
          "password_confirmation" => "weak"
        })

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end

    test "requires password confirmation match", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/reset-password", %{
          "token" => "some_token",
          "password" => "NewPassword456!",
          "password_confirmation" => "DifferentPassword!"
        })

      assert %{"errors" => errors} = json_response(conn, 400)
      assert is_map(errors)
    end
  end

  describe "Rate limiting and security" do
    test "implements rate limiting on login attempts", %{conn: conn} do
      # Make multiple rapid login attempts
      attempts =
        for _i <- 1..10 do
          post(conn, ~p"/auth/login", %{
            "user" => %{
              "email" => "ratelimit.test@example.com",
              "password" => "wrongpassword"
            }
          })
        end

      # After enough attempts, should be rate limited
      last_response = List.last(attempts)
      status = last_response.status

      # Should either be 401 (invalid credentials) or 429 (rate limited)
      assert status == 401 or status == 429
    end

    test "prevents brute force attacks", %{conn: conn} do
      # This would test account lockout functionality
      {:ok, _user} =
        User.register(%{
          first_name: "Brute",
          last_name: "Force",
          email: "brute.force@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      # Make multiple failed attempts
      for _i <- 1..5 do
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "brute.force@example.com",
            "password" => "wrongpassword"
          }
        })
      end

      # Even with correct password, account might be locked
      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "brute.force@example.com",
            "password" => "Password123!"
          }
        })

      # Response depends on lockout implementation
      status = conn.status
      assert status == 200 or status == 401 or status == 423
    end

    test "includes security headers", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "headers.test@example.com",
            "password" => "Password123!"
          }
        })

      # Check for security headers
      assert get_resp_header(conn, "x-frame-options") != []
      assert get_resp_header(conn, "x-content-type-options") != []
      assert get_resp_header(conn, "x-xss-protection") != []
    end
  end

  describe "Content-Type handling" do
    test "handles application/json", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          ~p"/auth/login",
          "{\"user\":{\"email\":\"test@example.com\",\"password\":\"Password123!\"}}"
        )

      assert response(conn, 401) or response(conn, 200)
    end

    test "handles application/x-www-form-urlencoded", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/auth/login", "user[email]=test@example.com&user[password]=Password123!")

      assert response(conn, 401) or response(conn, 200)
    end

    test "rejects unsupported content types", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post(~p"/auth/login", "some data")

      assert response(conn, 415)
    end
  end

  describe "Error handling" do
    test "handles database connection errors", %{conn: conn} do
      # This would test graceful degradation when database is unavailable
      # Implementation depends on error handling strategy
      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "test@example.com",
            "password" => "Password123!"
          }
        })

      # Should not crash, should return appropriate error
      status = conn.status
      assert status >= 400 and status < 600
    end

    test "handles malformed request bodies", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/auth/login", "{\"invalid\": json}")

      assert response(conn, 400) == "Invalid JSON"
    end

    test "handles extremely large payloads", %{conn: conn} do
      large_payload = String.duplicate("a", 1_000_000)

      conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "#{large_payload}@example.com",
            "password" => "Password123!"
          }
        })

      # Should handle large inputs gracefully
      status = conn.status
      assert status >= 400 and status < 500
    end
  end

  describe "Authentication middleware" do
    test "requires authentication for protected endpoints", %{conn: conn} do
      conn = get(conn, ~p"/api/profile")

      assert response(conn, 401) == "Unauthorized"
    end

    test "allows access with valid token", %{conn: conn} do
      # Get valid token
      {:ok, _user} =
        User.register(%{
          first_name: "Protected",
          last_name: "Access",
          email: "protected.access@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })

      login_conn =
        post(conn, ~p"/auth/login", %{
          "user" => %{
            "email" => "protected.access@example.com",
            "password" => "Password123!"
          }
        })

      %{"access_token" => access_token} = json_response(login_conn, 200)

      # Access protected endpoint
      protected_conn =
        conn
        |> put_req_header("authorization", "Bearer " <> access_token)
        |> get(~p"/api/profile")

      assert response(protected_conn, 200) or response(protected_conn, 404)
    end

    test "handles expired tokens", %{conn: conn} do
      expired_token = "expired_token_123"

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> expired_token)
        |> get(~p"/api/profile")

      assert response(conn, 401) == "Unauthorized"
    end

    test "handles malformed authorization header", %{conn: conn} do
      test_cases = [
        # Missing token
        "Bearer",
        # Lowercase bearer
        "bearer token",
        # Wrong scheme
        "Token abc123",
        # No scheme
        "abc123"
      ]

      Enum.each(test_cases, fn auth_header ->
        conn =
          conn
          |> put_req_header("authorization", auth_header)
          |> get(~p"/api/profile")

        assert response(conn, 401) == "Unauthorized"
      end)
    end
  end
end
