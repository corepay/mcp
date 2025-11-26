defmodule McpWeb.PaymentMethodsControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Customer
  alias Mcp.Payments.PaymentMethod

  setup %{conn: conn} do
    %{conn: Plug.Conn.put_req_header(conn, "x-forwarded-host", "localhost")}
  end

  describe "POST /api/payment_methods" do
    test "creates a payment method successfully", %{conn: conn} do
      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
        |> Ash.create!()

      params = %{
        "customer_id" => customer.id,
        "provider" => "qorpay",
        "type" => "card",
        "last4" => "4242",
        "brand" => "visa",
        "exp_month" => 12,
        "exp_year" => 2025
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
