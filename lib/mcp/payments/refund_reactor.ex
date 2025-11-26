defmodule Mcp.Payments.RefundReactor do
  @moduledoc """
  Reactor module to orchestrate refund transactions.
  """

  use Ash.Reactor

  def process_refund(inputs, context \\ %{}) do
    Reactor.run(__MODULE__, inputs, context)
  end

  ash do
    default_domain Mcp.Payments
  end

  input(:charge_id)
  input(:amount)
  input(:reason)

  # 1. Get Charge
  read_one :get_charge, Mcp.Payments.Charge, :by_id do
    inputs %{id: input(:charge_id)}
    fail_on_not_found? true
  end

  # 2. Create Refund Record (Pending)
  create :create_refund, Mcp.Payments.Refund, :create do
    inputs %{
      charge_id: input(:charge_id),
      amount: input(:amount),
      reason: input(:reason),
      currency: result(:get_charge, [:currency])
    }
  end

  # 3. Execute Gateway Refund
  step :execute_refund, Mcp.Payments.Steps.ExecuteRefund do
    argument :provider, result(:get_charge, [:provider])
    argument :amount, input(:amount)
    argument :provider_ref, result(:get_charge, [:provider_ref])
  end

  # 4. Update Refund Status
  step :update_refund_status, Mcp.Payments.Steps.UpdateRefundStatus do
    argument :refund, result(:create_refund)
    argument :gateway_result, result(:execute_refund)
  end

  # 5. Calculate Audit Status
  step :calculate_audit_status, Mcp.Payments.Steps.CalculateAuditStatus do
    argument :gateway_result, result(:execute_refund)
  end

  # 6. Create Audit Log
  create :create_audit_log, Mcp.Payments.GatewayTransaction, :create do
    inputs %{
      charge_id: input(:charge_id),
      provider: result(:get_charge, [:provider]),
      type: value(:refund),
      amount: input(:amount),
      currency: result(:get_charge, [:currency]),
      status: result(:calculate_audit_status),
      raw_response: result(:execute_refund, [:raw])
    }
  end

  return :update_refund_status
end
