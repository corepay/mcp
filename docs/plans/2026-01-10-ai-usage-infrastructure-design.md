# AI Usage & Billing Infrastructure Design

> **Created**: 2026-01-10 | **Status**: Design Complete
> **Track**: AI Infrastructure | **Depends On**: None
> **Related**: [AI Portal UX Design](./complete/2026-01-10-ai-portal-ux-design.md)

## Overview

Design for the AI usage metering, quota management, and billing surface area.
This infrastructure enables future monetization without costly refactors.

**Principle**: All AI interactions flow through a Gateway that handles access
control, metering, and cost tracking.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AI Gateway Architecture                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ AI Entry Points ────────────────────────────────────────────────────┐   │
│  │  Command Palette │ Page AI │ Component AI │ Proactive │ Search       │   │
│  └──────────────────────────────┬────────────────────────────────────────┘   │
│                                 │                                            │
│                                 ▼                                            │
│  ┌─ Mcp.Ai.Gateway ─────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │   execute(tenant_id, feature, opts, fun)                              │   │
│  │   │                                                                   │   │
│  │   ├── 1. check_feature_enabled(tenant_id, feature)                    │   │
│  │   │      └── Is this AI feature turned on for this tenant?            │   │
│  │   │                                                                   │   │
│  │   ├── 2. check_quota(tenant_id, feature)                              │   │
│  │   │      └── Has tenant exceeded monthly/daily limits?                │   │
│  │   │                                                                   │   │
│  │   ├── 3. check_rate_limit(tenant_id)                                  │   │
│  │   │      └── Too many requests per minute?                            │   │
│  │   │                                                                   │   │
│  │   ├── 4. measure(fun)                                                 │   │
│  │   │      └── Execute and capture tokens, latency                      │   │
│  │   │                                                                   │   │
│  │   └── 5. track_usage(tenant_id, feature, usage, opts)                 │   │
│  │          └── Write to LlmUsage with cost calculation                  │   │
│  │                                                                       │   │
│  └──────────────────────────────┬────────────────────────────────────────┘   │
│                                 │                                            │
│         ┌───────────────────────┼───────────────────────┐                    │
│         ▼                       ▼                       ▼                    │
│  ┌─────────────┐    ┌───────────────────┐    ┌─────────────────┐            │
│  │ Feature     │    │ LlmUsage          │    │ TenantAiConfig  │            │
│  │ Registry    │    │ (tracking)        │    │ (quotas)        │            │
│  └─────────────┘    └───────────────────┘    └─────────────────┘            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Feature Registry

AI features that can be individually enabled/disabled and metered:

| Feature Key | Description | Default |
|-------------|-------------|---------|
| `:command_palette` | Global ⌘K AI interface | enabled |
| `:page_ai` | Page-level Ask AI panel | enabled |
| `:component_ai` | Inline component AI actions | enabled |
| `:proactive_insights` | AI-generated dashboard insights | disabled |
| `:semantic_search` | AI-powered search | enabled |
| `:document_analysis` | Document/receipt analysis | enabled |

---

## Data Models

### Mcp.Ai.LlmUsage (Enhanced)

Tracks every AI interaction for billing and analytics.

```elixir
defmodule Mcp.Ai.LlmUsage do
  use Ash.Resource,
    domain: Mcp.Ai,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "llm_usage"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    # === WHO ===
    attribute :tenant_id, :uuid, allow_nil?: false
    attribute :merchant_id, :uuid  # optional granularity
    attribute :store_id, :uuid     # optional granularity
    attribute :user_id, :uuid

    # === WHAT ===
    attribute :feature, :atom do
      constraints one_of: [
        :command_palette,
        :page_ai,
        :component_ai,
        :proactive_insights,
        :semantic_search,
        :document_analysis
      ]
      allow_nil? false
    end

    attribute :model, :string, allow_nil?: false  # "llama3", "gpt-4-turbo"
    attribute :action, :string  # "chat", "embed", "analyze", "search"

    # === METERING ===
    attribute :tokens_in, :integer, default: 0
    attribute :tokens_out, :integer, default: 0
    attribute :total_tokens, :integer, default: 0  # computed
    attribute :latency_ms, :integer

    # === BILLING ===
    attribute :cost_cents, :integer, default: 0  # pre-calculated
    attribute :billing_period, :string  # "2026-01" for aggregation

    # === CONTEXT ===
    attribute :metadata, :map, default: %{}
    # metadata contains: page, conversation_id, tool_calls, error, etc.

    attribute :success, :boolean, default: true

    create_timestamp :inserted_at
  end

  calculations do
    calculate :total_tokens, :integer, expr(tokens_in + tokens_out)
  end

  actions do
    defaults [:read]

    create :track do
      accept [
        :tenant_id, :merchant_id, :store_id, :user_id,
        :feature, :model, :action,
        :tokens_in, :tokens_out, :latency_ms,
        :cost_cents, :metadata, :success
      ]

      change fn changeset, _ ->
        # Auto-set billing period
        period = Calendar.strftime(DateTime.utc_now(), "%Y-%m")
        Ash.Changeset.force_change_attribute(changeset, :billing_period, period)
      end
    end

    read :monthly_summary do
      argument :tenant_id, :uuid, allow_nil?: false
      argument :billing_period, :string, allow_nil?: false

      filter expr(
        tenant_id == ^arg(:tenant_id) and
        billing_period == ^arg(:billing_period)
      )
    end

    read :by_feature do
      argument :tenant_id, :uuid, allow_nil?: false
      argument :feature, :atom, allow_nil?: false
      argument :since, :utc_datetime, allow_nil?: false

      filter expr(
        tenant_id == ^arg(:tenant_id) and
        feature == ^arg(:feature) and
        inserted_at >= ^arg(:since)
      )
    end
  end
end
```

### Mcp.Ai.TenantAiConfig

Per-tenant AI configuration and quotas.

```elixir
defmodule Mcp.Ai.TenantAiConfig do
  use Ash.Resource,
    domain: Mcp.Ai,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tenant_ai_configs"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid, allow_nil?: false

    # === FEATURE FLAGS ===
    attribute :features_enabled, {:array, :atom} do
      default [
        :command_palette,
        :page_ai,
        :component_ai,
        :semantic_search,
        :document_analysis
      ]
    end

    # === QUOTAS (nil = unlimited) ===
    attribute :monthly_token_limit, :integer
    attribute :daily_token_limit, :integer
    attribute :rate_limit_rpm, :integer, default: 60  # requests per minute

    # === OVERAGE STRATEGY ===
    attribute :overage_strategy, :atom do
      constraints one_of: [:hard_block, :soft_warn, :allow_overage, :upgrade_prompt]
      default :soft_warn
    end

    # === PLAN REFERENCE (for future billing) ===
    attribute :ai_plan, :atom do
      constraints one_of: [:free, :basic, :pro, :unlimited, :enterprise]
      default :basic
    end

    timestamps()
  end

  identities do
    identity :unique_tenant, [:tenant_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:tenant_id, :features_enabled, :monthly_token_limit,
              :daily_token_limit, :rate_limit_rpm, :overage_strategy, :ai_plan]
      upsert? true
      upsert_identity :unique_tenant
    end

    update :update do
      accept [:features_enabled, :monthly_token_limit, :daily_token_limit,
              :rate_limit_rpm, :overage_strategy, :ai_plan]
    end
  end

  code_interface do
    domain Mcp.Ai
    define :get_for_tenant, action: :read, args: [:tenant_id], get?: true
    define :upsert, action: :create
  end
end
```

---

## Gateway Implementation

```elixir
defmodule Mcp.Ai.Gateway do
  @moduledoc """
  Central gateway for all AI operations.
  Handles access control, rate limiting, metering, and cost tracking.
  """

  alias Mcp.Ai.{TenantAiConfig, LlmUsage}
  require Logger

  @model_costs %{
    # Cost per 1K tokens in cents
    "llama3" => %{input: 0, output: 0},  # Local, free
    "gpt-4-turbo" => %{input: 1, output: 3},
    "gpt-4o" => %{input: 0.5, output: 1.5},
    "text-embedding-3-small" => %{input: 0.002, output: 0}
  }

  @doc """
  Execute an AI operation with full metering and access control.

  ## Options
  - `:user_id` - The user making the request
  - `:merchant_id` - Optional merchant context
  - `:store_id` - Optional store context
  - `:model` - The model being used (for cost calculation)
  - `:metadata` - Additional context to store

  ## Returns
  - `{:ok, result}` - Operation succeeded
  - `{:error, :feature_disabled}` - Feature not enabled for tenant
  - `{:error, :quota_exceeded, status}` - Monthly/daily limit hit
  - `{:error, :rate_limited, retry_after_ms}` - Too many requests
  """
  def execute(tenant_id, feature, opts \\ [], fun) when is_function(fun, 0) do
    config = get_config(tenant_id)

    with :ok <- check_feature_enabled(config, feature),
         :ok <- check_quota(tenant_id, config),
         :ok <- check_rate_limit(tenant_id, config) do

      {duration_ms, result} = :timer.tc(fn -> safe_execute(fun) end, :millisecond)

      case result do
        {:ok, value, usage_info} ->
          track_usage(tenant_id, feature, opts, usage_info, duration_ms, true)
          {:ok, value}

        {:ok, value} ->
          # No usage info returned, track with defaults
          track_usage(tenant_id, feature, opts, %{}, duration_ms, true)
          {:ok, value}

        {:error, reason} ->
          track_usage(tenant_id, feature, opts, %{error: reason}, duration_ms, false)
          {:error, reason}
      end
    end
  end

  @doc "Check if a feature is enabled without executing"
  def feature_enabled?(tenant_id, feature) do
    config = get_config(tenant_id)
    feature in (config.features_enabled || [])
  end

  @doc "Get current quota status for a tenant"
  def quota_status(tenant_id) do
    config = get_config(tenant_id)
    period = Calendar.strftime(DateTime.utc_now(), "%Y-%m")

    usage = Ash.read!(LlmUsage,
      action: :monthly_summary,
      args: [tenant_id: tenant_id, billing_period: period]
    )

    total_tokens = Enum.reduce(usage, 0, & &1.total_tokens + &2)
    total_cost = Enum.reduce(usage, 0, & &1.cost_cents + &2)

    %{
      monthly_tokens_used: total_tokens,
      monthly_token_limit: config.monthly_token_limit,
      monthly_cost_cents: total_cost,
      features_enabled: config.features_enabled,
      overage_strategy: config.overage_strategy,
      ai_plan: config.ai_plan
    }
  end

  # === Private ===

  defp get_config(tenant_id) do
    case Mcp.Ai.TenantAiConfig.get_for_tenant(tenant_id) do
      {:ok, config} -> config
      _ -> default_config()
    end
  end

  defp default_config do
    %{
      features_enabled: [:command_palette, :page_ai, :component_ai, :semantic_search],
      monthly_token_limit: nil,
      daily_token_limit: nil,
      rate_limit_rpm: 60,
      overage_strategy: :soft_warn,
      ai_plan: :basic
    }
  end

  defp check_feature_enabled(config, feature) do
    if feature in (config.features_enabled || []) do
      :ok
    else
      {:error, :feature_disabled}
    end
  end

  defp check_quota(tenant_id, config) do
    case config.monthly_token_limit do
      nil -> :ok
      limit ->
        status = quota_status(tenant_id)
        if status.monthly_tokens_used < limit do
          :ok
        else
          case config.overage_strategy do
            :hard_block -> {:error, :quota_exceeded, status}
            :soft_warn -> :ok  # Allow but will warn in UI
            :allow_overage -> :ok
            :upgrade_prompt -> {:error, :quota_exceeded, status}
          end
        end
    end
  end

  defp check_rate_limit(tenant_id, config) do
    # Simple in-memory rate limiting using ETS or Redis
    # For now, always pass - implement with Hammer or similar
    _ = {tenant_id, config}
    :ok
  end

  defp safe_execute(fun) do
    try do
      fun.()
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp track_usage(tenant_id, feature, opts, usage_info, duration_ms, success) do
    model = Keyword.get(opts, :model, "llama3")
    tokens_in = Map.get(usage_info, :tokens_in, 0)
    tokens_out = Map.get(usage_info, :tokens_out, 0)

    cost_cents = calculate_cost(model, tokens_in, tokens_out)

    Ash.create!(LlmUsage, %{
      tenant_id: tenant_id,
      merchant_id: Keyword.get(opts, :merchant_id),
      store_id: Keyword.get(opts, :store_id),
      user_id: Keyword.get(opts, :user_id),
      feature: feature,
      model: model,
      action: Keyword.get(opts, :action, "chat"),
      tokens_in: tokens_in,
      tokens_out: tokens_out,
      latency_ms: duration_ms,
      cost_cents: cost_cents,
      metadata: Map.get(usage_info, :metadata, %{}),
      success: success
    }, action: :track)
  end

  defp calculate_cost(model, tokens_in, tokens_out) do
    rates = Map.get(@model_costs, model, %{input: 0, output: 0})
    input_cost = (tokens_in / 1000) * rates.input
    output_cost = (tokens_out / 1000) * rates.output
    round(input_cost + output_cost)
  end
end
```

---

## Billing Integration Points

When billing is implemented, these are the integration surfaces:

### 1. Plan-Based Defaults

```elixir
# When tenant signs up or changes plan
def set_ai_plan(tenant_id, plan) do
  config = plan_config(plan)
  Mcp.Ai.TenantAiConfig.upsert(%{
    tenant_id: tenant_id,
    ai_plan: plan,
    features_enabled: config.features,
    monthly_token_limit: config.monthly_tokens,
    overage_strategy: config.overage
  })
end

defp plan_config(:free), do: %{
  features: [:semantic_search],
  monthly_tokens: 10_000,
  overage: :hard_block
}

defp plan_config(:pro), do: %{
  features: [:command_palette, :page_ai, :component_ai, :semantic_search],
  monthly_tokens: 500_000,
  overage: :soft_warn
}

defp plan_config(:unlimited), do: %{
  features: [:command_palette, :page_ai, :component_ai, :proactive_insights, :semantic_search],
  monthly_tokens: nil,
  overage: :allow_overage
}
```

### 2. Usage Aggregation for Invoicing

```elixir
# Monthly billing job
def generate_ai_invoice(tenant_id, billing_period) do
  usage = Ash.read!(LlmUsage,
    action: :monthly_summary,
    args: [tenant_id: tenant_id, billing_period: billing_period]
  )

  %{
    tenant_id: tenant_id,
    period: billing_period,
    total_tokens: Enum.sum(Enum.map(usage, & &1.total_tokens)),
    total_cost_cents: Enum.sum(Enum.map(usage, & &1.cost_cents)),
    by_feature: Enum.group_by(usage, & &1.feature) |> summarize_by_feature(),
    by_model: Enum.group_by(usage, & &1.model) |> summarize_by_model()
  }
end
```

### 3. UI Quota Display

```elixir
# In LiveView
def mount(_params, _session, socket) do
  quota_status = Mcp.Ai.Gateway.quota_status(socket.assigns.tenant_id)

  socket
  |> assign(:ai_quota, quota_status)
  |> assign(:show_quota_warning, quota_status.monthly_tokens_used > quota_status.monthly_token_limit * 0.8)
end
```

---

## Implementation Checklist

- [ ] Create `llm_usage` migration (enhance existing)
- [ ] Create `tenant_ai_configs` migration
- [ ] Implement `Mcp.Ai.LlmUsage` resource
- [ ] Implement `Mcp.Ai.TenantAiConfig` resource
- [ ] Implement `Mcp.Ai.Gateway` module
- [ ] Update `Changes.Respond` to use Gateway
- [ ] Add rate limiting (Hammer or custom ETS)
- [ ] Add quota warning component for UI
- [ ] Add admin UI for managing tenant AI configs

---

## Related Documents

- [AI Portal UX Design](2026-01-10-ai-portal-ux-design.md)
- [AI README](../features/ai/README.md)
- [AshAi Strategy](ASH_AI_STRATEGY.md)
