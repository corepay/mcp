defmodule Mcp.Payments.PaymentMethodReactor do
  @moduledoc """
  Reactor module to orchestrate payment method creation and tokenization.
  """

  use Ash.Reactor

  def create_payment_method(inputs, context \\ %{}) do
    Reactor.run(__MODULE__, inputs, context)
  end

  ash do
    default_domain Mcp.Payments
  end

  input(:customer_id)
  input(:provider)
  input(:type)
  # Map with number, exp_month, exp_year, cvv, etc.
  input(:card)
  input(:bank_account)

  # 1. Tokenize Card via Gateway
  step :tokenize_card, Mcp.Payments.Steps.TokenizeCard do
    argument :provider, input(:provider)
    argument :card, input(:card)
    argument :bank_account, input(:bank_account)
    argument :customer_id, input(:customer_id)
  end

  # 2. Create Payment Method Resource
  step :create_resource do
    argument :customer_id, input(:customer_id)
    argument :provider, input(:provider)
    argument :type, input(:type)
    argument :token_data, result(:tokenize_card)

    run fn arguments, context ->
      token_data = arguments.token_data

      Mcp.Payments.PaymentMethod
      |> Ash.Changeset.for_create(:create, %{
        customer_id: arguments.customer_id,
        provider: arguments.provider,
        type: arguments.type,
        provider_token: token_data.provider_token,
        # Card fields
        last4: token_data[:last4],
        brand: token_data[:brand],
        exp_month: token_data[:exp_month],
        exp_year: token_data[:exp_year],
        # ACH fields
        last4_account: token_data[:last4_account],
        bank_name: token_data[:bank_name],
        account_type: token_data[:account_type],
        account_holder_name: token_data[:account_holder_name]
      })
      |> Ash.create()
    end
  end

  return :create_resource
end
