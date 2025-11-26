defmodule Mcp.Payments.TransactionReactorTest do
  use Mcp.DataCase
  alias Mcp.Payments.Charge
  alias Mcp.Payments.TransactionReactor

  describe "run/1" do
    test "successfully processes a payment via QorPay" do
      # Create a customer and payment method first
      customer =
        Mcp.Payments.Customer
        |> Ash.Changeset.for_create(:create, %{email: "test@example.com", name: "Test User"})
        |> Ash.create!()

      payment_method =
        Mcp.Payments.PaymentMethod
        |> Ash.Changeset.for_create(:create, %{
          customer_id: customer.id,
          type: :card,
          provider: :qorpay,
          provider_token: "tok_123",
          last4: "4242",
          brand: "visa"
        })
        |> Ash.create!()

      inputs = %{
        amount: 1000,
        currency: "USD",
        customer_id: customer.id,
        payment_method_id: payment_method.id,
        provider: :qorpay
      }

      {:ok, result} = TransactionReactor.process_payment(inputs, %{})

      # Verify the result is the updated charge
      assert result.status == :succeeded
      assert result.amount == 1000
      assert result.currency == "USD"
      assert result.provider == :qorpay
      assert result.captured_at != nil

      # Verify the charge exists in DB
      charge = Ash.get!(Charge, result.id)
      assert charge.status == :succeeded
    end
  end
end
