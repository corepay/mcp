defmodule Mcp.Payments.TransactionReactor do
  @moduledoc """
  Reactor module to orchestrate payment transactions.
  """

  use Ash.Reactor

  def process_payment(inputs, context \\ %{}) do
    Reactor.run(__MODULE__, inputs, context)
  end

  ash do
    default_domain Mcp.Payments
  end

  input(:amount)
  input(:currency)
  input(:customer_id)
  input(:payment_method_id)
  input(:provider)

  # 1. Validate Payment Method
  read_one :get_payment_method, Mcp.Payments.PaymentMethod, :by_id do
    inputs %{id: input(:payment_method_id)}
    fail_on_not_found? true
  end

  # 1.5 Fetch Customer
  read_one :get_customer, Mcp.Payments.Customer, :by_id do
    inputs %{id: input(:customer_id)}
    fail_on_not_found? true
  end

  # 2. Create Charge Record (Pending)
  create :create_charge, Mcp.Payments.Charge, :create do
    inputs %{
      amount: input(:amount),
      currency: input(:currency),
      customer_id: input(:customer_id),
      payment_method_id: input(:payment_method_id),
      provider: input(:provider)
    }
  end

  # 3. Execute Gateway Transaction (Custom Step)
  step :execute_gateway, Mcp.Payments.Steps.ExecuteGateway do
    argument :amount, input(:amount)
    argument :currency, input(:currency)
    argument :provider, input(:provider)
    argument :charge_id, result(:create_charge, [:id])
    argument :payment_method, result(:get_payment_method)
    argument :customer, result(:get_customer)
  end

  # 4. Update Charge Status
  step :update_charge_status, Mcp.Payments.Steps.UpdateChargeStatus do
    argument :charge, result(:create_charge)
    argument :gateway_result, result(:execute_gateway)
    argument :action, value(:capture)
  end

  # 5. Calculate Audit Status
  step :calculate_audit_status, Mcp.Payments.Steps.CalculateAuditStatus do
    argument :gateway_result, result(:execute_gateway)
  end

  # 6. Create Audit Log
  create :create_audit_log, Mcp.Payments.GatewayTransaction, :create do
    inputs %{
      charge_id: result(:create_charge, [:id]),
      provider: input(:provider),
      type: value(:authorize),
      amount: input(:amount),
      currency: input(:currency),
      status: result(:calculate_audit_status),
      raw_response: result(:execute_gateway, [:raw])
    }
  end

  return :update_charge_status
end
