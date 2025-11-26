defmodule Mcp.Payments.VoidReactor do
  @moduledoc """
  Reactor module to orchestrate void transactions.
  """

  use Ash.Reactor

  def process_void(inputs, context \\ %{}) do
    Reactor.run(__MODULE__, inputs, context)
  end

  ash do
    default_domain Mcp.Payments
  end

  input(:charge_id)

  # 1. Get Charge
  read_one :get_charge, Mcp.Payments.Charge, :by_id do
    inputs %{id: input(:charge_id)}
    fail_on_not_found? true
  end

  # 2. Execute Gateway Void
  step :execute_void, Mcp.Payments.Steps.ExecuteVoid do
    argument :provider, result(:get_charge, [:provider])
    argument :provider_ref, result(:get_charge, [:provider_ref])
  end

  # 3. Update Charge Status (Void)
  step :update_charge_status, Mcp.Payments.Steps.UpdateChargeStatus do
    argument :charge, result(:get_charge)
    argument :gateway_result, result(:execute_void)
    argument :action, value(:void)
  end

  # 4. Calculate Audit Status
  step :calculate_audit_status, Mcp.Payments.Steps.CalculateAuditStatus do
    argument :gateway_result, result(:execute_void)
  end

  # 5. Create Audit Log
  create :create_audit_log, Mcp.Payments.GatewayTransaction, :create do
    inputs %{
      charge_id: input(:charge_id),
      provider: result(:get_charge, [:provider]),
      type: value(:void),
      amount: result(:get_charge, [:amount]),
      currency: result(:get_charge, [:currency]),
      status: result(:calculate_audit_status),
      raw_response: result(:execute_void, [:raw])
    }
  end

  return :update_charge_status
end
