defmodule McpWeb.WebhooksControllerTest do
  use McpWeb.ConnCase

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
