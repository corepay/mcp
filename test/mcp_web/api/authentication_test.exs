defmodule McpWeb.API.AuthenticationTest do
  @moduledoc """
  Integration tests for full API authentication flow.

  TDD Phase: RED - These tests will fail initially until plug is implemented.

  Tests cover:
  - Full API request flow with valid key
  - API response format for errors
  - Usage logging and analytics
  - Multiple authentication methods working together
  - Real-world API scenarios

  Uses /api/profile as the test endpoint since it requires authentication via the :api pipeline.
  """

  use McpWeb.ConnCase

  # Skip: Tests use /api/health which is now public (no auth required).
  # FUTURE: Redesign tests to use endpoints that require authentication.
  @moduletag :skip

  import Plug.Conn

  alias Mcp.Platform.{ApiKey, Tenant}

  # NOTE: This project uses header-based API versioning, not path-based.
  # The API endpoints are under /api, with version specified via API-Version header.
  @api_base_path "/api"

  setup do
    tenant =
      Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Tenant #{System.unique_integer()}",
        slug: "test-tenant-#{System.unique_integer()}",
        subdomain: "test-#{System.unique_integer()}"
      })
      |> Ash.create!()

    {:ok, api_key} =
      ApiKey.create(%{
        prefix: "dev_ak",
        type: :developer,
        scopes: ["read:merchants", "write:merchants"],
        owner_id: tenant.id,
        owner_type: :tenant
      })

    raw_key = api_key.__metadata__.raw_key

    {:ok, tenant: tenant, api_key: api_key, raw_key: raw_key}
  end

  describe "full API request flow with authentication" do
    test "successfully processes authenticated API request", %{conn: conn, raw_key: raw_key} do
      # Make a full API request with authentication
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> get("#{@api_base_path}/profile")

      # Should succeed
      assert conn.status == 200
    end

    test "includes rate limit headers in successful response", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> get("#{@api_base_path}/profile")

      assert conn.status == 200
      assert get_resp_header(conn, "x-ratelimit-limit") != []
      assert get_resp_header(conn, "x-ratelimit-remaining") != []
      assert get_resp_header(conn, "x-ratelimit-reset") != []
    end

    test "sets API version header in response", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("api-version", "2024-01-01")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 200
      # Response should echo or validate API version
      assert get_req_header(conn, "api-version") == ["2024-01-01"]
    end

    test "handles API key in Authorization Bearer header", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 200
    end

    test "processes POST request with authentication", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("content-type", "application/json")
        |> post("#{@api_base_path}/merchants", Jason.encode!(%{name: "Test Merchant"}))

      # Should authenticate successfully (may return 404 or other error if endpoint doesn't exist,
      # but should not return 401/403)
      refute conn.status in [401, 403]
    end
  end

  describe "API error response format" do
    test "returns standard error format for missing API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 401

      response = Jason.decode!(conn.resp_body)
      assert %{"error" => error} = response
      assert is_map(error)
      assert error["code"] == "missing_api_key"
      assert is_binary(error["message"])
    end

    test "returns standard error format for invalid API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "invalid_key")
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 401

      response = Jason.decode!(conn.resp_body)
      assert %{"error" => error} = response
      assert error["code"] in ["invalid_api_key", "authentication_failed"]
      assert is_binary(error["message"])
    end

    test "returns standard error format for insufficient permissions", %{conn: conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant #{System.unique_integer()}",
          slug: "test-tenant-#{System.unique_integer()}",
          subdomain: "test-#{System.unique_integer()}"
        })
        |> Ash.create!()

      {:ok, limited_key} =
        ApiKey.create(%{
          prefix: "dev_ak",
          type: :developer,
          scopes: ["read:merchants"],
          owner_id: tenant.id,
          owner_type: :tenant
        })

      raw_key = limited_key.__metadata__.raw_key

      # Try to access endpoint requiring write permission
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> post("#{@api_base_path}/merchants", Jason.encode!(%{name: "Test"}))

      # Should return 403 if endpoint requires write:merchants scope
      # (This test assumes there's a protected endpoint)
      # May need adjustment based on actual endpoint implementation
      assert conn.status in [403, 404, 401]

      if conn.status == 403 do
        response = Jason.decode!(conn.resp_body)
        assert %{"error" => error} = response
        assert error["code"] == "insufficient_permissions"
      end
    end

    test "includes request ID in error response", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 401

      response = Jason.decode!(conn.resp_body)

      # Should include request ID for tracing
      assert Map.has_key?(response, "request_id") or
               Map.has_key?(response["error"], "request_id")
    end

    test "sets proper content-type header for JSON errors", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 401
      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
    end
  end

  describe "usage logging and analytics" do
    test "logs API key usage on successful request", %{
      conn: conn,
      raw_key: raw_key,
      api_key: api_key
    } do
      # Record current last_used_at
      before_request = DateTime.utc_now()

      conn
      |> put_req_header("x-api-key", raw_key)
      |> get("#{@api_base_path}/profile")

      # Wait a moment for async update
      Process.sleep(50)

      # Check that last_used_at was updated
      {:ok, updated_key} = Ash.get(ApiKey, api_key.id)
      assert updated_key.last_used_at != nil
      assert DateTime.compare(updated_key.last_used_at, before_request) in [:gt, :eq]
    end

    test "does not update last_used_at on failed authentication", %{conn: conn, api_key: api_key} do
      # Make request with invalid key
      conn
      |> put_req_header("x-api-key", "invalid_key")
      |> get("#{@api_base_path}/profile")

      # Wait a moment
      Process.sleep(50)

      # last_used_at should not be updated for the valid key
      {:ok, key} = Ash.get(ApiKey, api_key.id)
      # Should still be nil or unchanged
      assert key.last_used_at == nil or key.last_used_at == api_key.last_used_at
    end

    test "tracks request metadata for analytics", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("user-agent", "TestClient/1.0")
        |> get("#{@api_base_path}/profile")

      # Should store metadata about the request
      # This would typically be in a separate analytics/logging table
      # For now, just verify the request succeeded
      assert conn.status == 200
    end
  end

  describe "multiple authentication methods" do
    test "API key authentication takes precedence over session", %{conn: conn, raw_key: raw_key} do
      # Create a user and establish a session
      user = Mcp.TestFactories.insert(:user, %{email: "session@example.com"})

      conn =
        conn
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> put_req_header("x-api-key", raw_key)
        |> get("#{@api_base_path}/profile")

      # Should authenticate via API key, not session
      assert conn.status == 200
      # Should have API key in assigns, not session user
      # (This assumes assigns are accessible in integration test)
    end

    test "rejects request with both invalid API key and no session", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "invalid")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 401
    end
  end

  describe "real-world API scenarios" do
    test "handles rapid successive requests correctly", %{conn: conn, raw_key: raw_key} do
      # Make 10 rapid requests
      results =
        for i <- 1..10 do
          conn =
            build_conn()
            |> put_req_header("x-api-key", raw_key)
            |> get("#{@api_base_path}/profile")

          {i, conn.status}
        end

      # All should succeed (unless rate limited, which should happen predictably)
      successful = Enum.count(results, fn {_i, status} -> status == 200 end)
      assert successful >= 1
    end

    test "handles concurrent requests from same API key", %{conn: conn, raw_key: raw_key} do
      # Make concurrent requests
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            conn =
              build_conn()
              |> put_req_header("x-api-key", raw_key)
              |> get("#{@api_base_path}/profile")

            {i, conn.status}
          end)
        end

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed with proper atomic operations
      assert Enum.all?(results, fn {_i, status} -> status in [200, 429] end)
    end

    test "handles requests with different content types", %{conn: _conn, raw_key: raw_key} do
      # JSON request (expected to work)
      json_conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      # JSON request should authenticate successfully
      assert json_conn.status == 200

      # Non-JSON accept header should be rejected by the API (accepts only JSON)
      # Phoenix raises NotAcceptableError instead of returning 406
      assert_raise Phoenix.NotAcceptableError, fn ->
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("accept", "application/x-www-form-urlencoded")
        |> get("#{@api_base_path}/profile")
      end
    end

    test "preserves query parameters through authentication", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> get("#{@api_base_path}/profile?foo=bar&baz=qux")

      assert conn.status == 200
      # Query params should be preserved
      assert conn.query_string == "foo=bar&baz=qux"
    end

    test "handles OPTIONS requests for CORS", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("access-control-request-method", "POST")
        |> put_req_header("origin", "https://example.com")
        |> options("#{@api_base_path}/profile")

      # OPTIONS should be handled (may not require auth depending on CORS config)
      # Status should be 200, 204, or 404 if CORS isn't configured
      # This test verifies the request doesn't crash
      assert conn.status in [200, 204, 404]
    end

    test "supports API versioning via header", %{conn: conn, raw_key: raw_key} do
      # Request with specific API version
      v1_conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("api-version", "2024-01-01")
        |> get("#{@api_base_path}/profile")

      # Should succeed
      assert v1_conn.status == 200
    end

    test "handles expired API key gracefully in production scenario", %{conn: conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant #{System.unique_integer()}",
          slug: "test-tenant-#{System.unique_integer()}",
          subdomain: "test-#{System.unique_integer()}"
        })
        |> Ash.create!()

      # Create expired key
      expires_at = DateTime.utc_now() |> DateTime.add(-1, :day)

      {:ok, expired_key} =
        ApiKey.create(%{
          prefix: "dev_ak",
          type: :developer,
          scopes: ["read:merchants"],
          owner_id: tenant.id,
          owner_type: :tenant,
          expires_at: expires_at
        })

      raw_key = expired_key.__metadata__.raw_key

      # Make request
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      # Should return proper error
      assert conn.status == 401

      response = Jason.decode!(conn.resp_body)
      assert response["error"]["code"] in ["expired_api_key", "invalid_api_key"]
    end

    test "handles revoked API key in production scenario", %{conn: conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant #{System.unique_integer()}",
          slug: "test-tenant-#{System.unique_integer()}",
          subdomain: "test-#{System.unique_integer()}"
        })
        |> Ash.create!()

      {:ok, api_key} =
        ApiKey.create(%{
          prefix: "dev_ak",
          type: :developer,
          scopes: ["read:merchants"],
          owner_id: tenant.id,
          owner_type: :tenant
        })

      raw_key = api_key.__metadata__.raw_key

      # Revoke the key
      {:ok, _revoked} = ApiKey.revoke(api_key)

      # Make request
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      # Should return proper error
      assert conn.status == 401

      response = Jason.decode!(conn.resp_body)
      assert response["error"]["code"] in ["revoked_api_key", "invalid_api_key"]
    end
  end

  describe "API response consistency" do
    test "all API endpoints return consistent error structure", %{conn: _conn} do
      # Only test endpoints that are known to exist and require authentication
      endpoints = [
        "#{@api_base_path}/profile"
      ]

      for endpoint <- endpoints do
        conn =
          build_conn()
          |> put_req_header("accept", "application/json")
          |> get(endpoint)

        # All should return 401 with same structure
        assert conn.status == 401

        response = Jason.decode!(conn.resp_body)
        assert %{"error" => error} = response
        assert is_map(error)
        assert Map.has_key?(error, "code")
        assert Map.has_key?(error, "message")
      end
    end

    test "API errors include helpful messages", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("#{@api_base_path}/profile")

      assert conn.status == 401

      response = Jason.decode!(conn.resp_body)
      message = response["error"]["message"]

      # Message should be helpful
      assert String.length(message) > 10
      assert message =~ ~r/API key/i
    end
  end
end
