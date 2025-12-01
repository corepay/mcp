defmodule McpWeb.PaymentMethodsControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Customer
  alias Mcp.Payments.PaymentMethod

  alias Mcp.Accounts.ApiKey

  setup %{conn: conn} do
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

    Application.put_env(:mcp, :req_options, plug: {Req.Test, Mcp.Payments.Gateways.QorPay})
    on_exit(fn -> Application.put_env(:mcp, :req_options, []) end)

    %{conn: conn}
  end

  describe "POST /api/payment_methods" do
    test "creates a payment method successfully", %{conn: conn} do
      # Mock QorPay Card Tokenization/Auth
      Req.Test.stub(Mcp.Payments.Gateways.QorPay, fn conn ->
        Req.Test.json(conn, %{
          "status" => "approved",
          "transaction_id" => "trans_123",
          "auth_code" => "auth_123"
        })
      end)

      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
        |> Ash.create!()

      params = %{
        "customer_id" => customer.id,
        "provider" => "qorpay",
        "type" => "card",
        "card" => %{
          "number" => "4242424242424242",
          "exp_month" => 12,
          "exp_year" => 2025,
          "cvv" => "123"
        }
      }

      conn = post(conn, ~p"/api/payment_methods", params)

      assert %{"status" => "success", "data" => data} = json_response(conn, 201)
      assert data["provider"] == "qorpay"
      assert data["last4"] == "4242"
    end
  end

  describe "GET /api/payment_methods/:id" do
    test "retrieves a payment method", %{conn: conn} do
      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
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
          exp_year: 2025
        })
        |> Ash.create!()

      conn = get(conn, ~p"/api/payment_methods/#{payment_method.id}")

      assert %{"status" => "success", "data" => data} = json_response(conn, 200)
      assert data["id"] == payment_method.id
      assert data["last4"] == "4242"
    end
  end

  describe "DELETE /api/payment_methods/:id" do
    test "deletes a payment method", %{conn: conn} do
      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
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
          exp_year: 2025
        })
        |> Ash.create!()

      conn = delete(conn, ~p"/api/payment_methods/#{payment_method.id}")

      assert %{"status" => "success", "message" => "Payment method deleted"} =
               json_response(conn, 200)

      assert {:error, _} = PaymentMethod.by_id(payment_method.id)
    end
  end
end
