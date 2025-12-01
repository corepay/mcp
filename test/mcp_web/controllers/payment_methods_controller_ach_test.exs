defmodule McpWeb.PaymentMethodsControllerAchTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Customer

  alias Mcp.Accounts.ApiKey

  setup %{conn: conn} do
    customer =
      Customer
      |> Ash.Changeset.for_create(:create, %{email: "ach@example.com", name: "ACH User"})
      |> Ash.create!()

    Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})
    on_exit(fn -> Application.put_env(:mcp, :req_options, []) end)

    # Create API Key
    key = "mcp_sk_#{Ecto.UUID.generate()}"

    ApiKey.create!(%{
      name: "Test Key",
      key: key,
      permissions: ["payment_methods:write", "payment_methods:read"]
    })

    conn =
      conn
      |> Plug.Conn.put_req_header("x-forwarded-host", "localhost")
      |> Plug.Conn.put_req_header("x-api-key", key)

    %{customer: customer, conn: conn}
  end

  test "tokenizes bank account and creates payment method", %{conn: conn, customer: customer} do
    # Mock QorPay ACH Tokenization
    Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
      case conn.request_path do
        "/payment/ach/token" ->
          Req.Test.json(conn, %{
            "status" => "approved",
            "token" => "tok_ach_123"
          })

        _ ->
          conn
          |> Plug.Conn.put_status(404)
          |> Req.Test.json(%{})
      end
    end)

    params = %{
      "customer_id" => customer.id,
      "provider" => "qorpay",
      "type" => "bank_account",
      "bank_account" => %{
        "routing_number" => "123456789",
        "account_number" => "9876543210",
        "account_type" => "checking",
        "account_holder_name" => "ACH User",
        "bank_name" => "Test Bank"
      }
    }

    conn = post(conn, ~p"/api/payment_methods", params)

    assert %{"status" => "success", "data" => data} = json_response(conn, 201)
    assert data["provider_token"] == "tok_ach_123"
    assert data["type"] == "bank_account"
    # Last 4 of 9876543210
    assert data["last4_account"] == "3210"
    assert data["bank_name"] == "Test Bank"
    assert data["account_type"] == "checking"
  end
end
