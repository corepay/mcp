defmodule Mcp.Payments.Gateways.QorPayTest do
  use ExUnit.Case, async: true
  alias Mcp.Payments.Gateways.QorPay

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "authorize/4 sends correct request and handles success" do
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/payment/authorize"
      {:ok, body, _} = Plug.Conn.read_body(conn)
      params = Jason.decode!(body)

      assert params["transaction_data"]["amount"] == 1000
      assert params["transaction_data"]["currency"] == "USD"
      assert params["transaction_data"]["store_card"] == true

      Req.Test.json(conn, %{
        "status" => "approved",
        "code" => "GW00",
        "message" => "Approved",
        "transaction_id" => "qor_txn_123",
        "token" => "qor_tok_123"
      })
    end)

    # Configure Req to use the stub
    Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})

    card = %{card: %{number: "4242", cvv: "123", exp_month: "12", exp_year: "25", zip: "12345"}}
    assert {:ok, result} = QorPay.authorize(1000, "USD", card, %{})
    assert result["status"] == "approved"
    assert result["transaction_id"] == "qor_txn_123"
  end

  test "capture/3 sends correct request" do
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/payment/capture"

      Req.Test.json(conn, %{
        "status" => "approved",
        "transaction_id" => "qor_txn_123"
      })
    end)

    Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})

    assert {:ok, result} = QorPay.capture("qor_txn_123", 1000, %{})
    assert result["status"] == "approved"
  end
end
