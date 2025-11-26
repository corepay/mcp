defmodule McpWeb.RefundsControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Charge
  alias Mcp.Payments.Customer
  alias Mcp.Payments.Gateways.QorPay
  alias Mcp.Payments.PaymentMethod

  setup %{conn: conn} do
    Req.Test.verify_on_exit!()
    # Remove mock setup
    Req.Test.verify_on_exit!()
    # Ensure we are using real requests, not mocks from other tests
    Application.put_env(:mcp, :req_options, [])

    customer =
      Customer
      |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
      |> Ash.create!()

    # 1. Create a PaymentMethod with a valid token (or just use card details for auth)
    # We need a valid transaction_id to refund.
    # Let's use the adapter directly to create a transaction.

    card_source = %{
      card: %{
        number: "4111111111111111",
        cvv: "123",
        exp_month: 12,
        exp_year: 2025,
        zip: "12345",
        cardfullname: "Test User"
      }
    }

    # Perform a real authorization/sale to get a transaction ID
    {:ok, auth_result} = QorPay.authorize(1000, "USD", card_source, %{})
    transaction_id = auth_result["transaction_id"]

    # Capture the charge so it can be refunded
    {:ok, _capture_result} = QorPay.capture(transaction_id, 1000, %{})

    payment_method =
      PaymentMethod
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        provider: :qorpay,
        type: :card,
        last4: "1111",
        brand: "visa",
        exp_month: 12,
        exp_year: 2025,
        # Save the token
        provider_token: auth_result["token"]
      })
      |> Ash.create!()

    charge =
      Charge
      |> Ash.Changeset.for_create(:create, %{
        amount: 1000,
        currency: "USD",
        customer_id: customer.id,
        payment_method_id: payment_method.id,
        provider: :qorpay,
        status: :succeeded,
        # Use real transaction ID
        provider_ref: transaction_id
      })
      |> Ash.create!()

    %{conn: Plug.Conn.put_req_header(conn, "x-forwarded-host", "localhost"), charge: charge}
  end

  describe "POST /api/refunds" do
    test "creates a refund successfully", %{conn: conn, charge: charge} do
      params = %{
        "charge_id" => charge.id,
        "amount" => 500,
        "reason" => "requested_by_customer"
      }

      conn = post(conn, ~p"/api/refunds", params)

      assert %{"status" => "success", "data" => data} = json_response(conn, 201)

      if data["status"] == "failed" do
      end

      assert data["status"] == "succeeded"
      assert data["amount"] == 500
      assert is_binary(data["provider_ref"])
    end
  end

  describe "GET /api/refunds/:id" do
    test "retrieves a refund", %{conn: conn, charge: charge} do
      refund =
        Mcp.Payments.Refund
        |> Ash.Changeset.for_create(:create, %{
          charge_id: charge.id,
          amount: 200,
          currency: "USD",
          reason: "duplicate"
        })
        |> Ash.create!()

      conn = get(conn, ~p"/api/refunds/#{refund.id}")

      assert %{"status" => "success", "data" => data} = json_response(conn, 200)
      assert data["id"] == refund.id
      assert data["amount"] == 200
    end
  end
end
