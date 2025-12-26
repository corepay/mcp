defmodule McpWeb.Plugs.ApiAuthPlugTest do
  use McpWeb.ConnCase

  alias Mcp.Platform.ApiKey
  alias McpWeb.Plugs.ApiAuthPlug

  setup do
    tenant =
      Mcp.Platform.Tenant
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Tenant",
        slug: "test-tenant-#{System.unique_integer()}",
        subdomain: "test-#{System.unique_integer()}"
      })
      |> Ash.create!()

    {:ok, api_key} =
      ApiKey.create(%{
        prefix: "mcp_test",
        type: :developer,
        owner_id: tenant.id,
        owner_type: :tenant
      })

    raw_key = api_key.__metadata__.raw_key
    {:ok, tenant: tenant, api_key: api_key, raw_key: raw_key}
  end

  test "authenticates with valid X-API-Key header", %{
    conn: conn,
    raw_key: raw_key,
    tenant: tenant,
    api_key: api_key
  } do
    conn =
      conn
      |> put_req_header("x-api-key", raw_key)
      |> ApiAuthPlug.call(%{})

    refute conn.halted
    assert conn.assigns.current_api_key.id == api_key.id
    # Since owner_type is tenant, it should assign current_tenant_id
    assert conn.assigns.current_tenant_id == tenant.id
  end

  test "authenticates with Bearer token", %{conn: conn, raw_key: raw_key, api_key: api_key} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> raw_key)
      |> ApiAuthPlug.call(%{})

    refute conn.halted
    assert conn.assigns.current_api_key.id == api_key.id
  end

  test "returns 401 with missing key", %{conn: conn} do
    conn = ApiAuthPlug.call(conn, %{})

    assert conn.halted
    assert conn.status == 401
    assert conn.resp_body =~ "Unauthorized: Missing API Key"
  end

  test "returns 401 with invalid key", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-api-key", "invalid_key")
      |> ApiAuthPlug.call(%{})

    assert conn.halted
    assert conn.status == 401
    assert conn.resp_body =~ "Unauthorized: Invalid API Key"
  end
end
