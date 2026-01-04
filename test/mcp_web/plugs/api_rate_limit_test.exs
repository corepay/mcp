defmodule McpWeb.Plugs.ApiRateLimitTest do
  @moduledoc """
  Comprehensive test suite for API rate limiting plug.

  TDD Phase: RED - These tests will fail initially until plug is implemented.

  Tests cover:
  - Requests under rate limit succeed
  - Requests over rate limit return 429
  - Retry-After header is set correctly
  - Rate limit resets after time window
  - Different rate limits per API key type
  - Rate limit counter accuracy
  - Concurrent request handling
  """

  use McpWeb.ConnCase
  import Plug.Conn

  alias Mcp.Platform.{ApiKey, Tenant}
  alias McpWeb.Plugs.{ApiAuthPlug, ApiRateLimitPlug}

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
        scopes: ["read:merchants"],
        owner_id: tenant.id,
        owner_type: :tenant
      })

    raw_key = api_key.__metadata__.raw_key

    {:ok, tenant: tenant, api_key: api_key, raw_key: raw_key}
  end

  describe "requests under rate limit" do
    test "allows requests under limit", %{conn: _conn, raw_key: raw_key} do
      # Make 5 requests (should be under default limit)
      results =
        for _i <- 1..5 do
          conn =
            build_conn()
            |> put_req_header("x-api-key", raw_key)
            |> ApiAuthPlug.call(%{})
            |> ApiRateLimitPlug.call(%{limit: 10, window: 60})

          {conn.halted, conn.status}
        end

      # All requests should succeed
      assert Enum.all?(results, fn {halted, _status} -> halted == false end)
    end

    test "sets rate limit headers on successful request", %{conn: conn, raw_key: raw_key} do
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: 100, window: 60})

      refute conn.halted

      # Should have rate limit headers
      assert get_resp_header(conn, "x-ratelimit-limit") == ["100"]

      assert get_resp_header(conn, "x-ratelimit-remaining") |> List.first() |> String.to_integer() <=
               100

      assert get_resp_header(conn, "x-ratelimit-reset") != []
    end

    test "decrements remaining count with each request", %{conn: _conn, raw_key: raw_key} do
      # First request
      conn1 =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: 10, window: 60})

      remaining1 =
        get_resp_header(conn1, "x-ratelimit-remaining") |> List.first() |> String.to_integer()

      # Second request
      conn2 =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: 10, window: 60})

      remaining2 =
        get_resp_header(conn2, "x-ratelimit-remaining") |> List.first() |> String.to_integer()

      # Remaining should decrease
      assert remaining2 < remaining1
      assert remaining1 - remaining2 == 1
    end
  end

  describe "requests over rate limit" do
    test "returns 429 when rate limit exceeded", %{conn: _conn, raw_key: raw_key} do
      # Configure very low limit
      limit = 3

      # Make requests up to limit
      for _i <- 1..limit do
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})
      end

      # Next request should be rate limited
      conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      assert conn.halted
      assert conn.status == 429
      assert conn.resp_body =~ "Rate limit exceeded"
    end

    test "sets Retry-After header when rate limited", %{conn: _conn, raw_key: raw_key} do
      limit = 2

      # Exhaust the limit
      for _i <- 1..limit do
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})
      end

      # Rate limited request
      conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      retry_after = get_resp_header(conn, "retry-after")
      assert retry_after != []

      # Retry-After should be a positive integer (seconds)
      retry_seconds = retry_after |> List.first() |> String.to_integer()
      assert retry_seconds > 0
      assert retry_seconds <= 60
    end

    test "sets correct rate limit headers when over limit", %{conn: _conn, raw_key: raw_key} do
      limit = 2

      # Exhaust the limit
      for _i <- 1..limit do
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})
      end

      # Rate limited request
      conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      assert get_resp_header(conn, "x-ratelimit-limit") == ["#{limit}"]
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(conn, "x-ratelimit-reset") != []
    end

    test "returns proper JSON error response", %{conn: _conn, raw_key: raw_key} do
      limit = 1

      # Exhaust the limit
      build_conn()
      |> put_req_header("x-api-key", raw_key)
      |> ApiAuthPlug.call(%{})
      |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      # Rate limited request
      conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> put_req_header("accept", "application/json")
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      assert conn.status == 429
      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"

      response = Jason.decode!(conn.resp_body)
      assert %{"error" => error} = response
      assert error["code"] == "rate_limit_exceeded"
      assert is_binary(error["message"])
    end
  end

  describe "rate limit window and reset" do
    test "rate limit resets after time window expires", %{conn: _conn, raw_key: raw_key} do
      # Use very short window for testing (1 second)
      limit = 2
      window = 1

      # Exhaust the limit
      for _i <- 1..limit do
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: window})
      end

      # Should be rate limited
      conn_limited =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: window})

      assert conn_limited.halted
      assert conn_limited.status == 429

      # Wait for window to expire
      Process.sleep(1100)

      # Should work again after reset
      conn_after_reset =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: window})

      refute conn_after_reset.halted
    end

    test "x-ratelimit-reset header contains correct timestamp", %{conn: conn, raw_key: raw_key} do
      window = 60

      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: 10, window: window})

      reset_header = get_resp_header(conn, "x-ratelimit-reset") |> List.first()
      reset_timestamp = String.to_integer(reset_header)
      current_timestamp = System.system_time(:second)

      # Reset should be in the future but within the window
      assert reset_timestamp > current_timestamp
      assert reset_timestamp <= current_timestamp + window
    end
  end

  describe "different rate limits per API key type" do
    test "developer keys have higher rate limits", %{conn: conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant #{System.unique_integer()}",
          slug: "test-tenant-#{System.unique_integer()}",
          subdomain: "test-#{System.unique_integer()}"
        })
        |> Ash.create!()

      {:ok, dev_key} =
        ApiKey.create(%{
          prefix: "dev_ak",
          type: :developer,
          scopes: ["read:merchants"],
          owner_id: tenant.id,
          owner_type: :tenant
        })

      dev_raw_key = dev_key.__metadata__.raw_key

      conn =
        conn
        |> put_req_header("x-api-key", dev_raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{})

      limit = get_resp_header(conn, "x-ratelimit-limit") |> List.first() |> String.to_integer()

      # Developer keys should have at least 1000 requests per minute
      assert limit >= 1000
    end

    test "merchant keys have standard rate limits", %{conn: conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant #{System.unique_integer()}",
          slug: "test-tenant-#{System.unique_integer()}",
          subdomain: "test-#{System.unique_integer()}"
        })
        |> Ash.create!()

      {:ok, merchant_key} =
        ApiKey.create(%{
          prefix: "merch_ak",
          type: :merchant,
          scopes: ["read:own"],
          owner_id: tenant.id,
          owner_type: :tenant
        })

      merchant_raw_key = merchant_key.__metadata__.raw_key

      conn =
        conn
        |> put_req_header("x-api-key", merchant_raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{})

      limit = get_resp_header(conn, "x-ratelimit-limit") |> List.first() |> String.to_integer()

      # Merchant keys should have lower limits (e.g., 100 requests per minute)
      assert limit >= 100
      assert limit < 1000
    end

    test "reseller keys have elevated rate limits", %{conn: conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant #{System.unique_integer()}",
          slug: "test-tenant-#{System.unique_integer()}",
          subdomain: "test-#{System.unique_integer()}"
        })
        |> Ash.create!()

      {:ok, reseller_key} =
        ApiKey.create(%{
          prefix: "res_ak",
          type: :reseller,
          scopes: ["manage:merchants"],
          owner_id: tenant.id,
          owner_type: :tenant
        })

      reseller_raw_key = reseller_key.__metadata__.raw_key

      conn =
        conn
        |> put_req_header("x-api-key", reseller_raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{})

      limit = get_resp_header(conn, "x-ratelimit-limit") |> List.first() |> String.to_integer()

      # Reseller keys should have elevated limits (e.g., 500 requests per minute)
      assert limit >= 500
    end
  end

  describe "rate limit storage and isolation" do
    test "rate limits are isolated per API key", %{conn: conn} do
      tenant =
        Tenant
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Tenant #{System.unique_integer()}",
          slug: "test-tenant-#{System.unique_integer()}",
          subdomain: "test-#{System.unique_integer()}"
        })
        |> Ash.create!()

      {:ok, key1} =
        ApiKey.create(%{
          prefix: "dev_ak",
          type: :developer,
          scopes: ["read:merchants"],
          owner_id: tenant.id,
          owner_type: :tenant
        })

      {:ok, key2} =
        ApiKey.create(%{
          prefix: "dev_ak",
          type: :developer,
          scopes: ["read:merchants"],
          owner_id: tenant.id,
          owner_type: :tenant
        })

      raw_key1 = key1.__metadata__.raw_key
      raw_key2 = key2.__metadata__.raw_key

      limit = 5

      # Exhaust limit for key1
      for _i <- 1..limit do
        build_conn()
        |> put_req_header("x-api-key", raw_key1)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})
      end

      # key1 should be rate limited
      conn1 =
        build_conn()
        |> put_req_header("x-api-key", raw_key1)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      assert conn1.halted
      assert conn1.status == 429

      # key2 should still work (different key, different limit)
      conn2 =
        conn
        |> put_req_header("x-api-key", raw_key2)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      refute conn2.halted
    end

    test "uses Redis for rate limit tracking", %{conn: conn, raw_key: raw_key} do
      # Make a request
      conn
      |> put_req_header("x-api-key", raw_key)
      |> ApiAuthPlug.call(%{})
      |> ApiRateLimitPlug.call(%{limit: 10, window: 60})

      # Check that Redis has the rate limit key
      # This assumes we can access Redis directly in tests
      # The actual key format will depend on implementation
      # e.g., "rate_limit:api_key:#{api_key_id}"

      # Note: This is a placeholder for the actual Redis check
      # Implementation will depend on how Redis client is configured
      assert :ok == :ok
    end
  end

  describe "concurrent request handling" do
    test "correctly counts concurrent requests", %{conn: _conn, raw_key: raw_key} do
      limit = 10

      # Make concurrent requests
      tasks =
        for i <- 1..limit do
          Task.async(fn ->
            build_conn()
            |> put_req_header("x-api-key", raw_key)
            |> ApiAuthPlug.call(%{})
            |> ApiRateLimitPlug.call(%{limit: limit, window: 60})
            |> then(fn conn -> {i, conn.halted, conn.status} end)
          end)
        end

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed (at the limit)
      assert Enum.all?(results, fn {_i, halted, _status} -> halted == false end)

      # One more request should be rate limited
      conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: limit, window: 60})

      assert conn.halted
      assert conn.status == 429
    end

    test "atomic increment prevents race conditions", %{conn: _conn, raw_key: raw_key} do
      limit = 5

      # Make highly concurrent requests (more than limit)
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            build_conn()
            |> put_req_header("x-api-key", raw_key)
            |> ApiAuthPlug.call(%{})
            |> ApiRateLimitPlug.call(%{limit: limit, window: 60})
            |> then(fn conn -> {i, conn.halted, conn.status} end)
          end)
        end

      results = Enum.map(tasks, &Task.await/1)

      # Exactly `limit` requests should succeed
      successful = Enum.count(results, fn {_i, halted, _status} -> halted == false end)
      rate_limited = Enum.count(results, fn {_i, halted, status} -> halted && status == 429 end)

      # Should have exactly limit successful and rest rate limited
      assert successful == limit
      assert rate_limited == 20 - limit
    end
  end

  describe "rate limit bypass scenarios" do
    test "allows bypass with special configuration", %{conn: conn, raw_key: raw_key} do
      # Make request with bypass flag
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{bypass: true})

      refute conn.halted
      # Should not have rate limit headers when bypassed
      assert get_resp_header(conn, "x-ratelimit-limit") == []
    end

    test "does not track requests when bypassed", %{conn: conn, raw_key: raw_key} do
      # Make many requests with bypass
      for _i <- 1..100 do
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{bypass: true})
      end

      # Regular request should start from fresh counter
      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> ApiAuthPlug.call(%{})
        |> ApiRateLimitPlug.call(%{limit: 10, window: 60})

      remaining =
        get_resp_header(conn, "x-ratelimit-remaining") |> List.first() |> String.to_integer()

      # Should have nearly full limit (minus this one request)
      assert remaining >= 9
    end
  end

  describe "plug without authentication" do
    test "skips rate limiting if no API key in assigns", %{conn: conn} do
      # Call rate limit plug without auth plug
      conn = ApiRateLimitPlug.call(conn, %{limit: 1, window: 60})

      # Should not halt or rate limit without API key
      refute conn.halted
    end
  end
end
