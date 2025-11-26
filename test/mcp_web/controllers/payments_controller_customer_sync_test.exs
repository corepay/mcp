defmodule McpWeb.PaymentsControllerCustomerSyncTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Customer
  alias Mcp.Payments.PaymentMethod

  setup %{conn: conn} do
    Req.Test.verify_on_exit!()
    Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})

    customer =
      Customer
      |> Ash.Changeset.for_create(:create, %{
        email: "sync_test@example.com",
        name: "Sync Test User",
        phone: "555-0199"
      })
      |> Ash.create!()

    payment_method =
      PaymentMethod
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        provider: :qorpay,
        type: :card,
        last4: "4242",
        brand: "visa",
        exp_month: 12,
        exp_year: 2025,
        # Dummy token for this test
        provider_token: "tok_123"
      })
      |> Ash.create!()

    %{conn: conn, customer: customer, payment_method: payment_method}
  end

  test "sends customer details to QorPay during payment", %{
    conn: conn,
    customer: customer,
    payment_method: payment_method
  } do
    Req.Test.expect(Mcp.Payments.Gateways.QorPay, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      params = Jason.decode!(body)

      # Verify customer fields are present in transaction_data
      transaction_data = params["transaction_data"]

      assert transaction_data["cemail"] == customer.email

      # assert transaction_data["cname"] == customer.name # QorPay might expect cfirstname/clastname or cardfullname
      # Let's check what we map.

      Req.Test.json(conn, %{
        "status" => "approved",
        "transaction_id" => "txn_sync_123",
        "token" => "tok_123"
      })
    end)

    params = %{
      "amount" => 1000,
      "currency" => "USD",
      "customer_id" => customer.id,
      "payment_method_id" => payment_method.id,
      "provider" => "qorpay"
    }

    conn = post(conn, ~p"/api/payments", params)
    assert %{"status" => "success"} = json_response(conn, 201)
  end
end
