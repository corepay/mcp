# Underwriting Strategy: The "Gateway" Business Model

## 1. Executive Summary

We are adopting the **Gateway Pattern** for underwriting. Just as we abstract
payment processors (Stripe, QorPay) behind a single API, we will abstract
Identity Verification (IDV) and Compliance vendors behind a unified
**Underwriting Gateway**.

**The Goal**:

1. **Vendor Agnosticism**: Switch between ComplyCube, Veriff, or Persona without
   changing application code.
2. **Cost Arbitrage**: Route checks to the most cost-effective provider for a
   specific region or check type.
3. **Resiliency**: Fallback to a secondary provider if the primary API goes
   down.

## 2. Architecture: The Underwriting Gateway

We will replicate the `Mcp.Payments.Gateways` pattern in
`Mcp.Merchants.Underwriting`.

### 2.1. The Behaviour (`Mcp.Merchants.Underwriting.Adapter`)

Defines the contract that all vendors must fulfill.

```elixir
defmodule Mcp.Merchants.Underwriting.Adapter do
  @callback verify_identity(applicant_data :: map(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
  @callback screen_business(business_data :: map(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
  @callback check_watchlist(name :: String.t(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
  @callback document_check(document_image :: binary(), type :: atom(), context :: map()) :: {:ok, result :: map()} | {:error, any()}
end
```

### 2.2. The Factory (`Mcp.Merchants.Underwriting.Factory`)

Routes requests based on tenant configuration or "Smart Routing" rules.

```elixir
def get_adapter(tenant_config) do
  case tenant_config.preferred_provider do
    :complycube -> Mcp.Merchants.Underwriting.Adapters.ComplyCube
    :veriff -> Mcp.Merchants.Underwriting.Adapters.Veriff
    _ -> Mcp.Merchants.Underwriting.Adapters.Mock # For dev/test
  end
end
```

## 3. Vendor Analysis: ComplyCube

Based on the provided pricing, ComplyCube is a strong primary candidate.

### 3.1. Cost Analysis (Per Application)

A standard "Low Risk" application might require:

1. **Standard Screening (Watchlist/PEP)**: $0.35
2. **Document Check (ID)**: $0.80
3. **Liveness Check (Photo)**: $0.20
4. **Company Lookup (KYB)**: $0.90 (if applicable)

**Total Cost of Goods Sold (COGS)**: ~$1.35 - $2.25 per merchant.

### 3.2. Revenue Opportunity (The Arbitrage)

We charge tenants a "Compliance Fee" or bundle it into the SaaS subscription.

- **Model A (Per-App Fee)**: Charge Tenant $5.00 per application.
  - _Margin_: ~$3.00 (60% margin).
- **Model B (SaaS Bundle)**: "Pro Plan" includes 50 free checks/month.
  - _Benefit_: Predictable revenue, breakage (unused checks).

## 4. Implementation Strategy

### Phase 1: The "Mock" Gateway

- Implement the `Adapter` behaviour.
- Create a `MockAdapter` that returns simulated "Approved" or "Rejected"
  results.
- **Benefit**: Allows us to build the UI and Flow (OLA) without incurring vendor
  costs or waiting for API keys.

### Phase 2: ComplyCube Integration

- Implement `Mcp.Merchants.Underwriting.Adapters.ComplyCube`.
- Map ComplyCube webhooks to our `RiskAssessment` resource.
- **Focus**: "Standard Screening" and "Document Check" first.

### Phase 3: Smart Routing (Future)

- "If region == 'EU', use Veriff (better EU coverage)."
- "If check_type == 'KYB', use Middesk."
