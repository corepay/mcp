defmodule McpWeb.PaymentMethodsControllerTokenizationTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Customer

  setup %{conn: conn} do
    Req.Test.verify_on_exit!()
    Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})

    customer =
      Customer
      |> Ash.Changeset.for_create(:create, %{
        email: "token_test@example.com",
        name: "Token Test User"
      })
      |> Ash.create!()

    %{conn: conn, customer: customer}
  end

  test "tokenizes card and creates payment method", %{conn: conn, customer: customer} do
    Req.Test.expect(Mcp.Payments.Gateways.QorPay, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      params = Jason.decode!(body)

      # Verify it calls authorize/token endpoint
      assert params["transaction_data"]["creditcard"] == "4111111111111111"

      Req.Test.json(conn, %{
        "status" => "approved",
        "token" => "tok_generated_123",
        "authcode" => "123456"
      })
    end)

    params = %{
      "customer_id" => customer.id,
      "provider" => "qorpay",
      "type" => "card",
      "card" => %{
        "number" => "4111111111111111",
        "exp_month" => 12,
        "exp_year" => 2025,
        "cvv" => "123"
      }
    }

    conn = post(conn, ~p"/api/payment_methods", params)

    assert %{"status" => "success", "data" => data} = json_response(conn, 201)
    assert data["provider_token"] == "tok_generated_123"
    assert data["last4"] == "1111"
    assert data["brand"] == "visa"
  end
end
