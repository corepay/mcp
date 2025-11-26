defmodule McpWeb.VoidsControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Payments.Charge
  alias Mcp.Payments.Customer
  alias Mcp.Payments.Gateways.Factory
  alias Mcp.Payments.PaymentMethod

  @moduletag :integration

  setup %{conn: conn} do
    # Ensure no mocks are active for this test
    Application.delete_env(:mcp, :req_options)
    %{conn: Plug.Conn.put_req_header(conn, "x-forwarded-host", "localhost")}
  end

  describe "POST /api/voids" do
    test "voids a pending charge successfully", %{conn: conn} do
      # 1. Create a Customer
      customer =
        Customer
        |> Ash.Changeset.for_create(:create, %{
          email: "void_test_#{System.unique_integer()}@example.com",
          name: "Void Test User"
        })
        |> Ash.create!()

      # 2. Create a Payment Method (using a test card that authorizes successfully)
      # For QorPay sandbox, we might need a specific token or just use the card details directly
      # in the charge if we haven't implemented full tokenization flow yet.
      # But our PaymentMethod resource expects a provider_token or card details.
      # Let's assume we can create a payment method with a dummy token that works,
      # OR we rely on the fact that our current implementation might not validate the token
      # strictly against QorPay until we use it.
      # Actually, the TransactionReactor uses the payment method to authorize.
      # We need a valid token or card.
      # Since we don't have a "Create Token" flow fully integrated and tested with real QorPay
      # yet (it was mocked), we might need to rely on the "store_card=true" behavior in authorize.

      # Let's create a PaymentMethod with raw card data if our implementation supports it,
      # or a dummy token if QorPay sandbox accepts it.
      # Looking at QorPay adapter, it merges source.
      payment_method =
        PaymentMethod
        |> Ash.Changeset.for_create(:create, %{
          customer_id: customer.id,
          provider: :qorpay,
          type: :card,
          last4: "1111",
          brand: "visa",
          exp_month: 12,
          exp_year: 2025
        })
        |> Ash.create!()

      # 3. Create and Authorize a Charge (Real API Call)
      # We need to hit the PaymentsController to create the charge first.
      # But we can also just use the Reactor directly or create the resource if we have the provider_ref.
      # To be a true integration test, let's go through the API.

      # Wait, we need to pass card details for the first transaction if we don't have a token.
      # Our PaymentMethod resource doesn't store raw card details (good!).
      # So we need to simulate a "new card" transaction or use a known test token.
      # For this test, let's assume we can create a charge with a "new" payment method
      # via the API if we had that endpoint, but we only have `POST /payments` which takes `payment_method_id`.

      # WORKAROUND: For this test, we will manually create a Charge that has a valid provider_ref
      # from a real QorPay authorization.
      # To get that provider_ref, we'll make a direct call to QorPay adapter first, or use the TransactionReactor.

      # Let's use the QorPay adapter directly to get a valid transaction to void.
      adapter = Factory.get_adapter(:qorpay)

      # Use a test card number for QorPay Sandbox
      card_source = %{
        card: %{
          # Visa Test Card
          number: "4111111111111111",
          cvv: "123",
          exp_month: 12,
          exp_year: 2025,
          zip: "12345",
          cardfullname: "Test User"
        }
      }

      {:ok, auth_result} = adapter.authorize(1000, "USD", card_source, %{})

      transaction_id = auth_result["transaction_id"]
      # Now create the Charge record in our DB representing this authorization
      charge =
        Charge
        |> Ash.Changeset.for_create(:create, %{
          amount: 1000,
          currency: "USD",
          customer_id: customer.id,
          payment_method_id: payment_method.id,
          provider: :qorpay,
          # Initially pending, then we update it
          status: :pending,
          provider_ref: transaction_id
        })
        |> Ash.create!()

      # Manually set it to succeeded/pending (authorized) so we can void it.
      # Our Charge resource defaults to pending.
      # 4. Call Void Endpoint
      params = %{"charge_id" => charge.id}
      conn = post(conn, ~p"/api/voids", params)

      assert %{"status" => "success", "data" => data} = json_response(conn, 201)
      assert data["status"] == "voided"
      # 5. Verify Charge is updated in DB
      updated_charge = Charge.get_by_id!(charge.id)
      assert updated_charge.status == :voided
    end
  end
end
