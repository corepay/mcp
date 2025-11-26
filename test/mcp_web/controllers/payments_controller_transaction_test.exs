defmodule McpWeb.PaymentsControllerTransactionTest do
  use McpWeb.ConnCase

  setup do
    Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})
    on_exit(fn -> Application.put_env(:mcp, :req_options, []) end)
    :ok
  end

  test "retrieves transaction from gateway", %{conn: conn} do
    # Mock QorPay Transaction Retrieval
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      case conn.request_path do
        "/v3/payment/transaction/txn_123" ->
          Req.Test.json(conn, %{
            "status" => "approved",
            "transaction_id" => "txn_123",
            "amount" => "100.00",
            "currency" => "USD"
          })

        _ ->
          conn
          |> Plug.Conn.put_status(404)
          |> Req.Test.json(%{})
      end
    end)

    conn = get(conn, ~p"/api/payments/transactions/txn_123?provider=qorpay")

    assert %{"status" => "success", "data" => data} = json_response(conn, 200)
    assert data["transaction_id"] == "txn_123"
    assert data["amount"] == "100.00"
  end
end
