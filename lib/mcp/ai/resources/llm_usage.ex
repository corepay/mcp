defmodule Mcp.Ai.LlmUsage do
  @moduledoc """
  Tracks LLM token usage and cost.
  """
  use Ash.Resource,
    domain: Mcp.Ai,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mcp.Cache.SpendingCache
  alias Mcp.Repo

  policies do
    policy action_type(:read) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end

    policy action_type(:create) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end

    policy action_type(:destroy) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end

    policy action_type(:update) do
      authorize_if expr(tenant_id == ^actor(:tenant_id))
    end
  end

  postgres do
    table "llm_usages"
    repo(Repo)
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :atom do
      constraints one_of: [:openrouter]
      allow_nil? false
    end

    attribute :model, :string, allow_nil?: false
    attribute :prompt_tokens, :integer, allow_nil?: false
    attribute :completion_tokens, :integer, allow_nil?: false
    attribute :total_tokens, :integer, allow_nil?: false

    attribute :cost, :decimal do
      allow_nil? false
      default 0.0
    end

    attribute :latency_ms, :integer

    attribute :merchant_id, :uuid
    attribute :reseller_id, :uuid
    attribute :api_key_id, :uuid
    # Link to Finance Transfer when posted
    attribute :transfer_id, :uuid

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :provider,
        :model,
        :prompt_tokens,
        :completion_tokens,
        :total_tokens,
        :cost,
        :latency_ms,
        :merchant_id,
        :reseller_id,
        :api_key_id
      ]

      change after_action(fn changeset, record, _context ->
               # Invalidate spending cache when new usage is recorded
               if record.api_key_id do
                 SpendingCache.invalidate(record.api_key_id)
               end

               {:ok, record}
             end)
    end

    update :update_transfer do
      accept [:transfer_id]
    end
  end

  code_interface do
    define :create
    define :update_transfer
  end

  def calculate_spend(api_key_id, start_date, end_date) do
    require Ash.Query

    Mcp.Ai.LlmUsage
    |> Ash.Query.filter(api_key_id == ^api_key_id)
    |> Ash.Query.filter(inserted_at > ^start_date and inserted_at < ^end_date)
    |> Ash.sum(:cost)
    |> case do
      {:ok, val} when not is_nil(val) -> val
      _ -> Decimal.new(0)
    end
  end

  def calculate_cost(model, prompt_tokens, completion_tokens) do
    # Prices per 1M tokens (USD)
    {input_price, output_price} =
      case model do
        "google/gemini-2.5-pro" ->
          {Decimal.new("1.25"), Decimal.new("10.00")}

        "google/gemini-2.0-flash-001" ->
          {Decimal.new("0.10"), Decimal.new("0.40")}

        model when is_binary(model) ->
          if String.ends_with?(model, ":free") do
            {Decimal.new(0), Decimal.new(0)}
          else
            # Default for safety
            {Decimal.new("3.00"), Decimal.new("15.00")}
          end
      end

    input_cost =
      Decimal.div(Decimal.new(prompt_tokens), Decimal.new(1_000_000))
      |> Decimal.mult(input_price)

    output_cost =
      Decimal.div(Decimal.new(completion_tokens), Decimal.new(1_000_000))
      |> Decimal.mult(output_price)

    Decimal.add(input_cost, output_cost)
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? true
    end

    belongs_to :merchant, Mcp.Platform.Merchant do
      allow_nil? true
    end
  end
end
