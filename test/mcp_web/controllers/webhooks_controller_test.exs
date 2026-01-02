defmodule McpWeb.WebhooksControllerTest do
  use McpWeb.ConnCase

  setup %{conn: conn} do
    # Create API Key using test factory
    raw_key = Mcp.TestFactories.create_api_key(["webhooks:write", "webhooks:read"])

    conn =
      conn
      |> Plug.Conn.put_req_header("x-forwarded-host", "localhost")
      |> Plug.Conn.put_req_header("x-api-key", raw_key)

    %{conn: conn}
  end

  test "handles qorpay webhook", %{conn: conn} do
    payload = %{
      "type" => "sale.approved",
      "data" => %{"id" => "txn_123"}
    }

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/webhooks/qorpay", Jason.encode!(payload))

    assert %{"status" => "received"} = json_response(conn, 200)
  end
end
