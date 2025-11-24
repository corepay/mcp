defmodule McpWeb.HealthControllerTest do
  use McpWeb.ConnCase

  @moduletag :health

  describe "Health Check Endpoints" do
    test "GET /api/health returns basic health status", %{conn: conn} do
      conn = get(conn, "/api/health")

      assert conn.status == 200
      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert is_binary(response["timestamp"])
      assert response["service"] == "mcp-gdpr"
      assert is_binary(response["version"])

      # Verify cache control headers
      assert get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]
    end

    test "GET /api/health/live returns liveness information", %{conn: conn} do
      conn = get(conn, "/api/health/live")

      assert conn.status == 200
      response = json_response(conn, 200)

      assert response["alive"] == true
      assert is_binary(response["timestamp"])
      assert is_number(response["uptime"])
      assert response["uptime"] >= 0

      # Verify resource stats are included
      assert is_map(response["memory"])
      assert is_map(response["processes"])

      # Verify cache control headers
      assert get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]
    end

    test "GET /api/health/ready returns readiness status", %{conn: conn} do
      conn = get(conn, "/api/health/ready")

      # Should return 200 if ready, 503 if not ready
      assert conn.status in [200, 503]
      response = json_response(conn, conn.status)

      assert is_boolean(response["ready"])
      assert is_map(response["checks"])
      assert is_binary(response["timestamp"])

      # Verify individual checks
      checks = response["checks"]
      assert is_boolean(checks["database"])
      assert is_boolean(checks["redis"])
      assert is_boolean(checks["job_queue"])
      assert is_boolean(checks["migrations"])

      # Verify cache control headers
      assert get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]
    end

    test "GET /api/health/detailed returns comprehensive health information", %{conn: conn} do
      conn = get(conn, "/api/health/detailed")

      # Should return 200 if ready, 503 if not ready
      assert conn.status in [200, 503]
      response = json_response(conn, conn.status)

      # Basic health info
      assert response["status"] == "healthy"
      assert response["service"] == "mcp-gdpr"
      assert is_binary(response["timestamp"])
      assert is_binary(response["version"])

      # System information
      assert is_number(response["uptime"])
      assert is_atom(response["environment"]) or is_binary(response["environment"])

      # Readiness checks
      assert is_map(response["readiness"])
      assert is_boolean(response["readiness"]["ready"])

      # Dependencies
      assert is_map(response["dependencies"])
      deps = response["dependencies"]

      assert is_map(deps["database"])
      assert is_boolean(deps["database"]["connected"])

      assert is_map(deps["redis"])
      assert is_boolean(deps["redis"]["connected"])

      assert is_map(deps["oban"])
      assert is_boolean(deps["oban"]["configured"])

      # Resources
      assert is_map(response["resources"])
      resources = response["resources"]

      assert is_map(resources["memory"])
      assert is_map(resources["processes"])
      assert is_map(resources["scheduler"])

      # GDPR-specific health
      assert is_map(response["gdpr"])
      gdpr = response["gdpr"]

      assert is_boolean(gdpr["audit_trail_enabled"])
      assert is_boolean(gdpr["rate_limiting_enabled"])
      assert is_boolean(gdpr["encryption_enabled"])
      assert is_boolean(gdpr["compliance_monitoring"])

      # Verify cache control headers
      assert get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]
    end

    test "health endpoints work without authentication", %{conn: conn} do
      # Health checks should not require authentication
      health_endpoints = [
        "/api/health",
        "/api/health/live",
        "/api/health/ready",
        "/api/health/detailed"
      ]

      for endpoint <- health_endpoints do
        conn = get(conn, endpoint)
        # Should not redirect to login
        refute conn.status in [302, 401, 403]
        assert conn.status in [200, 503]
      end
    end

    test "health endpoints have appropriate content-type", %{conn: conn} do
      conn = get(conn, "/api/health")

      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end

    test "database connectivity check works correctly", %{conn: conn} do
      conn = get(conn, "/api/health/detailed")
      response = json_response(conn, conn.status)

      db_info = response["dependencies"]["database"]

      if db_info["connected"] do
        # If connected, should have version info
        assert is_binary(db_info["version"]) or db_info["version"] == nil
        assert is_number(db_info["pool_size"])
      else
        # If not connected, should indicate connection failure
        refute db_info["connected"]
        assert db_info["version"] == nil
      end
    end

    test "memory stats return valid information", %{conn: conn} do
      conn = get(conn, "/api/health/detailed")
      response = json_response(conn, conn.status)

      memory = response["resources"]["memory"]

      # Memory stats should be positive numbers
      assert is_number(memory["total"])
      assert is_number(memory["processes"])
      assert is_number(memory["system"])
      assert is_number(memory["atom"])
      assert is_number(memory["ets"])

      assert memory["total"] > 0
      assert memory["processes"] > 0
    end

    test "process stats return valid information", %{conn: conn} do
      conn = get(conn, "/api/health/detailed")
      response = json_response(conn, conn.status)

      processes = response["resources"]["processes"]

      # Process stats should be valid
      assert is_number(processes["count"])
      assert is_number(processes["limit"])
      assert is_number(processes["run_queue"])

      assert processes["count"] > 0
      assert processes["limit"] > processes["count"]
      assert processes["run_queue"] >= 0
    end

    test "scheduler stats return valid information", %{conn: conn} do
      conn = get(conn, "/api/health/detailed")
      response = json_response(conn, conn.status)

      scheduler = response["resources"]["scheduler"]

      # Scheduler stats should be valid
      assert is_number(scheduler["logical_processors"])
      assert is_number(scheduler["online_processors"])

      assert scheduler["logical_processors"] > 0
      assert scheduler["online_processors"] > 0
      assert scheduler["online_processors"] <= scheduler["logical_processors"]
    end
  end

  describe "Health Check Security" do
    test "health endpoints do not expose sensitive information", %{conn: conn} do
      conn = get(conn, "/api/health/detailed")
      response = json_response(conn, conn.status)

      # Should not expose sensitive system details
      response_str = inspect(response)

      # These should not be in health responses
      refute String.contains?(response_str, "password")
      refute String.contains?(response_str, "secret")
      refute String.contains?(response_str, "key")
      refute String.contains?(response_str, "token")

      # But should include general health info
      assert String.contains?(response_str, "healthy")
      assert String.contains?(response_str, "uptime")
    end

    test "health endpoints have security headers", %{conn: conn} do
      conn = get(conn, "/api/health")

      # Should have security headers from ApiSecurityHeaders plug
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-frame-options") == ["DENY"]
      assert get_resp_header(conn, "x-xss-protection") == ["1; mode=block"]
      assert get_resp_header(conn, "strict-transport-security") |> length() > 0
    end
  end
end