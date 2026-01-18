# Phase 5: AI Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate AI capabilities throughout the portal, including Intelligence Bar, Proactive Insights in sidebars, Natural Language Search, and AI-powered recommendations.

**Architecture:** Uses AshAi for LLM orchestration with Ollama for local inference. AI insights are streamed via LiveView async assigns. The Intelligence Bar provides contextual AI assistance across all pages.

**Tech Stack:** Phoenix LiveView, AshAi, Ollama, LangChain/Instructor patterns, Server-Sent Events for streaming

**Reference Documents:**
- `2026-01-11-merchant-portal-features.md` - AI Insights sections
- `2026-01-11-store-portal-features.md` - AI assistance patterns
- `docs/DESIGN_GUIDE.md` - Component patterns

---

## Pre-Implementation: Quality Gate

Before starting Phase 5, verify Phase 1-4 are complete:

```bash
mix test
mix precommit
```

If any failures, complete prior phase remediation first.

---

## Overview: Features to Build

| # | Feature | Scope | Priority |
|---|---------|-------|----------|
| 1 | AI Service Foundation | Backend | P0 |
| 2 | Intelligence Bar Component | Global | P0 |
| 3 | Sidebar AI Insights | All Pages | P0 |
| 4 | Natural Language Search | Global | P1 |
| 5 | Customer Insights | CRM | P1 |
| 6 | Product Recommendations | POS | P1 |
| 7 | Sales Predictions | Reports | P2 |
| 8 | Inventory Alerts | Products | P1 |
| 9 | Order Pattern Analysis | Orders | P2 |
| 10 | AI Chat Interface | Modal | P2 |

---

## Task 1: AI Service Foundation

**Files:**
- Create: `lib/mcp/ai/service.ex`
- Create: `lib/mcp/ai/prompts.ex`
- Create: `lib/mcp/ai/context_builder.ex`
- Test: `test/mcp/ai/service_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/ai/service_test.exs
defmodule Mcp.AI.ServiceTest do
  use Mcp.DataCase, async: true

  alias Mcp.AI.Service

  describe "generate_insight/2" do
    test "generates insight for customer context" do
      customer = insert(:customer, total_orders: 10, total_spent: Money.new(50000, :USD))

      {:ok, insight} = Service.generate_insight(:customer, customer)

      assert is_binary(insight.message)
      assert insight.type in [:info, :success, :warning, :suggestion]
    end

    test "generates insight for product context" do
      product = insert(:product, quantity_on_hand: 5, low_stock_threshold: 10)

      {:ok, insight} = Service.generate_insight(:product, product)

      assert is_binary(insight.message)
    end

    test "handles missing context gracefully" do
      {:ok, insight} = Service.generate_insight(:customer, nil)

      assert insight == nil or insight.type == :info
    end
  end

  describe "stream_response/3" do
    test "streams response chunks" do
      prompt = "What are the top selling products?"

      chunks = Service.stream_response(:chat, prompt) |> Enum.to_list()

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)
    end
  end

  describe "natural_language_search/2" do
    test "converts natural language to search params" do
      insert(:product, name: "Blue T-Shirt", status: :active)
      insert(:product, name: "Red T-Shirt", status: :active)

      {:ok, results} = Service.natural_language_search(:products, "show me blue shirts")

      assert length(results) >= 1
      assert Enum.any?(results, &(&1.name =~ "Blue"))
    end

    test "handles order searches" do
      insert(:order, status: :pending, inserted_at: ~U[2026-01-10 10:00:00Z])

      {:ok, results} = Service.natural_language_search(:orders, "orders from last week that are pending")

      assert is_list(results)
    end
  end

  describe "analyze_patterns/2" do
    test "analyzes customer purchase patterns" do
      customer = insert(:customer)
      for _ <- 1..5 do
        order = insert(:order, customer: customer, status: :completed)
        insert(:order_item, order: order)
      end

      {:ok, analysis} = Service.analyze_patterns(:customer_purchases, customer.id)

      assert Map.has_key?(analysis, :preferred_categories)
      assert Map.has_key?(analysis, :purchase_frequency)
      assert Map.has_key?(analysis, :avg_order_value)
    end

    test "analyzes sales trends" do
      # Create orders over time
      for day <- 1..30 do
        insert(:order,
          status: :completed,
          total: Money.new(:rand.uniform(10000), :USD),
          inserted_at: DateTime.add(DateTime.utc_now(), -day * 86400)
        )
      end

      {:ok, analysis} = Service.analyze_patterns(:sales_trends, %{days: 30})

      assert Map.has_key?(analysis, :trend_direction)
      assert Map.has_key?(analysis, :peak_days)
      assert Map.has_key?(analysis, :forecast)
    end
  end

  describe "get_recommendations/2" do
    test "recommends products for customer" do
      customer = insert(:customer)
      category = insert(:category, name: "Apparel")
      product = insert(:product, category: category)

      # Customer previously bought from this category
      order = insert(:order, customer: customer, status: :completed)
      insert(:order_item, order: order, product: product)

      # Other products in same category
      insert(:product, category: category, name: "Similar Product 1")
      insert(:product, category: category, name: "Similar Product 2")

      {:ok, recommendations} = Service.get_recommendations(:products_for_customer, customer.id)

      assert length(recommendations) > 0
      assert Enum.all?(recommendations, &Map.has_key?(&1, :product))
      assert Enum.all?(recommendations, &Map.has_key?(&1, :reason))
    end

    test "recommends upsells for cart" do
      product = insert(:product, price: Money.new(2999, :USD))
      cart_items = [%{product_id: product.id, quantity: 1}]

      {:ok, recommendations} = Service.get_recommendations(:upsells, cart_items)

      assert is_list(recommendations)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/ai/service_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp/ai/service.ex
defmodule Mcp.AI.Service do
  @moduledoc """
  AI service for generating insights, recommendations, and natural language processing.

  Uses AshAi for LLM orchestration with Ollama for local inference.
  Supports streaming responses for chat-like interactions.
  """

  alias Mcp.AI.{Prompts, ContextBuilder}
  alias Mcp.Catalog.Product
  alias Mcp.Commerce.Order
  alias Mcp.CRM.Customer

  @ollama_url System.get_env("OLLAMA_URL", "http://localhost:11434")
  @model System.get_env("AI_MODEL", "llama3.2")

  @doc """
  Generate an AI insight for a given context.
  """
  def generate_insight(context_type, data) when is_atom(context_type) do
    context = ContextBuilder.build(context_type, data)
    prompt = Prompts.insight_prompt(context_type, context)

    case call_llm(prompt) do
      {:ok, response} ->
        {:ok, parse_insight(response)}

      {:error, reason} ->
        # Fallback to rule-based insights
        {:ok, generate_fallback_insight(context_type, data)}
    end
  end

  @doc """
  Stream a response for interactive chat.
  """
  def stream_response(type, prompt, opts \\ []) do
    system_prompt = Prompts.system_prompt(type)

    Stream.resource(
      fn -> start_stream(system_prompt, prompt, opts) end,
      fn state -> read_stream(state) end,
      fn state -> close_stream(state) end
    )
  end

  @doc """
  Convert natural language query to search results.
  """
  def natural_language_search(entity_type, query) do
    # Extract search parameters from natural language
    extraction_prompt = Prompts.search_extraction_prompt(entity_type, query)

    case call_llm(extraction_prompt, json_mode: true) do
      {:ok, params_json} ->
        params = Jason.decode!(params_json)
        execute_search(entity_type, params)

      {:error, _} ->
        # Fallback to simple keyword search
        execute_simple_search(entity_type, query)
    end
  end

  @doc """
  Analyze patterns in data.
  """
  def analyze_patterns(pattern_type, input) do
    data = gather_pattern_data(pattern_type, input)
    analysis_prompt = Prompts.analysis_prompt(pattern_type, data)

    case call_llm(analysis_prompt, json_mode: true) do
      {:ok, analysis_json} ->
        {:ok, Jason.decode!(analysis_json, keys: :atoms)}

      {:error, _} ->
        # Fallback to statistical analysis
        {:ok, compute_statistical_analysis(pattern_type, data)}
    end
  end

  @doc """
  Get AI-powered recommendations.
  """
  def get_recommendations(rec_type, input) do
    context = ContextBuilder.build_recommendation_context(rec_type, input)
    rec_prompt = Prompts.recommendation_prompt(rec_type, context)

    case call_llm(rec_prompt, json_mode: true) do
      {:ok, recs_json} ->
        recommendations = Jason.decode!(recs_json, keys: :atoms)
        {:ok, enrich_recommendations(rec_type, recommendations)}

      {:error, _} ->
        # Fallback to rule-based recommendations
        {:ok, generate_fallback_recommendations(rec_type, input)}
    end
  end

  # Private functions

  defp call_llm(prompt, opts \\ []) do
    json_mode = Keyword.get(opts, :json_mode, false)

    body = %{
      model: @model,
      prompt: prompt,
      stream: false,
      format: if(json_mode, do: "json", else: nil)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    case HTTPoison.post("#{@ollama_url}/api/generate", Jason.encode!(body), [
      {"Content-Type", "application/json"}
    ], recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: response_body}} ->
        %{"response" => response} = Jason.decode!(response_body)
        {:ok, response}

      {:ok, %{status_code: status}} ->
        {:error, "LLM returned status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_stream(system_prompt, user_prompt, _opts) do
    body = Jason.encode!(%{
      model: @model,
      system: system_prompt,
      prompt: user_prompt,
      stream: true
    })

    {:ok, %HTTPoison.AsyncResponse{id: ref}} =
      HTTPoison.post(
        "#{@ollama_url}/api/generate",
        body,
        [{"Content-Type", "application/json"}],
        stream_to: self(), async: :once
      )

    ref
  end

  defp read_stream(ref) do
    receive do
      %HTTPoison.AsyncStatus{id: ^ref} ->
        HTTPoison.stream_next(%HTTPoison.AsyncResponse{id: ref})
        {[], ref}

      %HTTPoison.AsyncHeaders{id: ^ref} ->
        HTTPoison.stream_next(%HTTPoison.AsyncResponse{id: ref})
        {[], ref}

      %HTTPoison.AsyncChunk{id: ^ref, chunk: chunk} ->
        HTTPoison.stream_next(%HTTPoison.AsyncResponse{id: ref})
        case Jason.decode(chunk) do
          {:ok, %{"response" => text, "done" => false}} ->
            {[text], ref}

          {:ok, %{"done" => true}} ->
            {:halt, ref}

          _ ->
            {[], ref}
        end

      %HTTPoison.AsyncEnd{id: ^ref} ->
        {:halt, ref}
    after
      30_000 ->
        {:halt, ref}
    end
  end

  defp close_stream(_ref), do: :ok

  defp parse_insight(response) do
    # Parse LLM response into structured insight
    %{
      message: String.trim(response),
      type: determine_insight_type(response),
      confidence: 0.8
    }
  end

  defp determine_insight_type(response) do
    cond do
      response =~ ~r/warning|alert|low|issue/i -> :warning
      response =~ ~r/great|excellent|strong|success/i -> :success
      response =~ ~r/suggest|recommend|consider|try/i -> :suggestion
      true -> :info
    end
  end

  defp generate_fallback_insight(:customer, %{total_orders: orders, total_spent: spent})
       when orders > 10 do
    %{
      message: "Loyal customer with #{orders} orders. Consider personalized offers.",
      type: :success,
      confidence: 1.0
    }
  end

  defp generate_fallback_insight(:product, %{quantity_on_hand: qty, low_stock_threshold: threshold})
       when qty <= threshold do
    %{
      message: "Low stock warning: #{qty} remaining (threshold: #{threshold})",
      type: :warning,
      confidence: 1.0
    }
  end

  defp generate_fallback_insight(_, _), do: nil

  defp execute_search(:products, params) do
    Product.list_products(params)
  end

  defp execute_search(:orders, params) do
    Order.list_orders(params)
  end

  defp execute_search(:customers, params) do
    Customer.list_customers(params)
  end

  defp execute_simple_search(entity_type, query) do
    execute_search(entity_type, %{search: query})
  end

  defp gather_pattern_data(:customer_purchases, customer_id) do
    {:ok, customer} = Customer.get(customer_id, load: [orders: [:items]])
    %{
      orders: customer.orders,
      total_spent: customer.total_spent,
      order_count: length(customer.orders)
    }
  end

  defp gather_pattern_data(:sales_trends, %{days: days}) do
    {:ok, orders} = Order.list_orders(%{
      start_date: Date.add(Date.utc_today(), -days),
      status: :completed
    })
    %{orders: orders.results, period_days: days}
  end

  defp compute_statistical_analysis(:customer_purchases, data) do
    %{
      preferred_categories: [],
      purchase_frequency: "monthly",
      avg_order_value: Money.new(0, :USD)
    }
  end

  defp compute_statistical_analysis(:sales_trends, %{orders: orders, period_days: days}) do
    total = Enum.reduce(orders, Money.new(0, :USD), &Money.add(&2, &1.total))
    avg_daily = if days > 0, do: Money.divide(total, days), else: total

    %{
      trend_direction: :stable,
      peak_days: ["Saturday", "Sunday"],
      forecast: Money.multiply(avg_daily, 7)
    }
  end

  defp enrich_recommendations(:products_for_customer, recommendations) do
    Enum.map(recommendations, fn rec ->
      {:ok, product} = Product.get(rec.product_id)
      Map.put(rec, :product, product)
    end)
  end

  defp enrich_recommendations(_, recommendations), do: recommendations

  defp generate_fallback_recommendations(:products_for_customer, customer_id) do
    # Simple collaborative filtering fallback
    []
  end

  defp generate_fallback_recommendations(:upsells, _cart_items) do
    # Popular products fallback
    []
  end
end
```

```elixir
# lib/mcp/ai/prompts.ex
defmodule Mcp.AI.Prompts do
  @moduledoc """
  Prompt templates for AI interactions.
  """

  def system_prompt(:chat) do
    """
    You are an AI assistant for a point-of-sale and merchant management platform.
    You help merchants understand their business data, manage inventory, and serve customers better.
    Be concise, helpful, and focus on actionable insights.
    """
  end

  def system_prompt(:insights) do
    """
    You are an AI analyst generating brief, actionable business insights.
    Keep responses to 1-2 sentences. Focus on what matters most.
    """
  end

  def insight_prompt(:customer, context) do
    """
    Analyze this customer and provide a brief insight:

    Customer: #{context.name}
    Total Orders: #{context.total_orders}
    Total Spent: #{context.total_spent}
    Last Order: #{context.last_order_date}
    Favorite Categories: #{context.favorite_categories}

    Provide a 1-2 sentence insight about this customer.
    """
  end

  def insight_prompt(:product, context) do
    """
    Analyze this product and provide a brief insight:

    Product: #{context.name}
    Stock: #{context.quantity_on_hand} / threshold: #{context.low_stock_threshold}
    Sales (30 days): #{context.sales_30d}
    Status: #{context.status}

    Provide a 1-2 sentence insight about this product.
    """
  end

  def insight_prompt(:order, context) do
    """
    Analyze this order and provide a brief insight:

    Order: #{context.order_number}
    Items: #{context.item_count}
    Total: #{context.total}
    Customer: #{context.customer_name || "Walk-in"}

    Provide a 1-2 sentence insight about this order.
    """
  end

  def search_extraction_prompt(entity_type, query) do
    """
    Convert this natural language search query into structured search parameters for #{entity_type}.

    Query: "#{query}"

    Return a JSON object with these possible fields:
    - search: text search term
    - status: status filter (if mentioned)
    - category_id: category filter (if mentioned)
    - start_date: date range start (YYYY-MM-DD format)
    - end_date: date range end (YYYY-MM-DD format)
    - sort: field to sort by
    - sort_dir: "asc" or "desc"

    Only include fields that are clearly specified in the query.
    Return valid JSON only.
    """
  end

  def analysis_prompt(:customer_purchases, data) do
    """
    Analyze this customer's purchase history and return insights.

    Order count: #{data.order_count}
    Total spent: #{data.total_spent}
    Orders: #{inspect(data.orders)}

    Return a JSON object with:
    - preferred_categories: array of category names they buy most
    - purchase_frequency: "weekly", "monthly", "quarterly", or "sporadic"
    - avg_order_value: average order value as string
    - insights: array of 2-3 brief text insights

    Return valid JSON only.
    """
  end

  def analysis_prompt(:sales_trends, data) do
    """
    Analyze sales trends for the past #{data.period_days} days.

    Order count: #{length(data.orders)}

    Return a JSON object with:
    - trend_direction: "up", "down", or "stable"
    - peak_days: array of day names with highest sales
    - forecast: predicted sales for next 7 days as string
    - insights: array of 2-3 brief text insights

    Return valid JSON only.
    """
  end

  def recommendation_prompt(:products_for_customer, context) do
    """
    Recommend products for this customer based on their purchase history.

    Customer preferences: #{inspect(context.preferences)}
    Previous purchases: #{inspect(context.previous_products)}
    Available products: #{inspect(context.available_products)}

    Return a JSON array of recommendations:
    [
      {"product_id": "uuid", "reason": "brief explanation"},
      ...
    ]

    Limit to 5 recommendations. Return valid JSON only.
    """
  end

  def recommendation_prompt(:upsells, context) do
    """
    Suggest upsell products for this cart.

    Cart items: #{inspect(context.cart_items)}
    Available products: #{inspect(context.available_products)}

    Return a JSON array of upsell suggestions:
    [
      {"product_id": "uuid", "reason": "brief explanation"},
      ...
    ]

    Limit to 3 suggestions. Return valid JSON only.
    """
  end
end
```

```elixir
# lib/mcp/ai/context_builder.ex
defmodule Mcp.AI.ContextBuilder do
  @moduledoc """
  Builds context objects for AI prompts from domain data.
  """

  alias Mcp.CRM.Customer
  alias Mcp.Catalog.Product
  alias Mcp.Commerce.Order

  def build(:customer, nil), do: %{}

  def build(:customer, %Customer{} = customer) do
    %{
      name: customer.name,
      total_orders: customer.total_orders || 0,
      total_spent: Money.to_string(customer.total_spent || Money.new(0, :USD)),
      last_order_date: format_date(customer.last_order_at),
      favorite_categories: get_favorite_categories(customer)
    }
  end

  def build(:product, nil), do: %{}

  def build(:product, %Product{} = product) do
    %{
      name: product.name,
      quantity_on_hand: product.quantity_on_hand,
      low_stock_threshold: product.low_stock_threshold,
      sales_30d: get_product_sales_30d(product),
      status: product.status
    }
  end

  def build(:order, nil), do: %{}

  def build(:order, %Order{} = order) do
    %{
      order_number: order.order_number,
      item_count: order.item_count || 0,
      total: Money.to_string(order.total),
      customer_name: order.customer && order.customer.name
    }
  end

  def build_recommendation_context(:products_for_customer, customer_id) do
    {:ok, customer} = Customer.get(customer_id, load: [orders: [:items]])

    previous_product_ids =
      customer.orders
      |> Enum.flat_map(& &1.items)
      |> Enum.map(& &1.product_id)
      |> Enum.uniq()

    {:ok, all_products} = Product.list_products(%{status: :active})

    %{
      preferences: get_favorite_categories(customer),
      previous_products: previous_product_ids,
      available_products:
        all_products.results
        |> Enum.reject(&(&1.id in previous_product_ids))
        |> Enum.take(50)
        |> Enum.map(&%{id: &1.id, name: &1.name, category: &1.category && &1.category.name})
    }
  end

  def build_recommendation_context(:upsells, cart_items) do
    product_ids = Enum.map(cart_items, & &1.product_id)
    {:ok, products} = Product.list_products(%{status: :active})

    %{
      cart_items: cart_items,
      available_products:
        products.results
        |> Enum.reject(&(&1.id in product_ids))
        |> Enum.take(20)
        |> Enum.map(&%{id: &1.id, name: &1.name, price: Money.to_string(&1.price)})
    }
  end

  # Helpers

  defp format_date(nil), do: "Never"
  defp format_date(date), do: Calendar.strftime(date, "%Y-%m-%d")

  defp get_favorite_categories(_customer) do
    # Would analyze purchase history
    []
  end

  defp get_product_sales_30d(_product) do
    # Would query order items
    0
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/ai/service_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/ai/service.ex lib/mcp/ai/prompts.ex lib/mcp/ai/context_builder.ex test/mcp/ai/service_test.exs
git commit -m "feat(ai): add AI service foundation with LLM integration"
```

---

## Task 2: Intelligence Bar Component

**Files:**
- Create: `lib/mcp_web/components/portal/intelligence_bar.ex`
- Create: `lib/mcp_web/live/components/intelligence_bar_live.ex`
- Test: `test/mcp_web/components/portal/intelligence_bar_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/portal/intelligence_bar_test.exs
defmodule McpWeb.Portal.IntelligenceBarTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias McpWeb.Portal.IntelligenceBar

  describe "intelligence_bar/1" do
    test "renders minimized by default" do
      assigns = %{expanded: false, message: nil}

      html = rendered_to_string(~H"""
      <IntelligenceBar.intelligence_bar expanded={@expanded} message={@message} />
      """)

      assert html =~ "intelligence-bar"
      assert html =~ "Ask AI"
      refute html =~ "intelligence-bar-expanded"
    end

    test "renders expanded state with input" do
      assigns = %{expanded: true, message: nil}

      html = rendered_to_string(~H"""
      <IntelligenceBar.intelligence_bar expanded={@expanded} message={@message} />
      """)

      assert html =~ "intelligence-bar-expanded"
      assert html =~ "input"
      assert html =~ "What would you like to know"
    end

    test "displays AI message when present" do
      assigns = %{expanded: true, message: "Here's an insight about your data..."}

      html = rendered_to_string(~H"""
      <IntelligenceBar.intelligence_bar expanded={@expanded} message={@message} />
      """)

      assert html =~ "Here's an insight about your data"
    end

    test "shows loading state during streaming" do
      assigns = %{expanded: true, message: nil, loading: true}

      html = rendered_to_string(~H"""
      <IntelligenceBar.intelligence_bar expanded={@expanded} message={@message} loading={@loading} />
      """)

      assert html =~ "animate-pulse" or html =~ "loading"
    end
  end

  describe "quick actions" do
    test "displays contextual quick actions" do
      assigns = %{
        expanded: true,
        message: nil,
        context: :products,
        quick_actions: [
          %{label: "Low stock items", query: "Show low stock products"},
          %{label: "Best sellers", query: "What are my best sellers?"}
        ]
      }

      html = rendered_to_string(~H"""
      <IntelligenceBar.intelligence_bar
        expanded={@expanded}
        message={@message}
        context={@context}
        quick_actions={@quick_actions}
      />
      """)

      assert html =~ "Low stock items"
      assert html =~ "Best sellers"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp_web/components/portal/intelligence_bar_test.exs -v`
Expected: FAIL

**Step 3: Write minimal implementation**

```elixir
# lib/mcp_web/components/portal/intelligence_bar.ex
defmodule McpWeb.Portal.IntelligenceBar do
  @moduledoc """
  Global AI assistant bar that appears at the bottom of pages.

  Features:
  - Minimized: Single line with AI icon and "Ask AI" prompt
  - Expanded: Full input field with quick actions and streaming responses
  - Context-aware: Adapts suggestions based on current page

  Design reference: Portal Design Docs - Intelligence Bar
  """
  use Phoenix.Component

  import McpWeb.Core.CoreComponents, only: [icon: 1, button: 1]

  attr :expanded, :boolean, default: false
  attr :message, :string, default: nil
  attr :loading, :boolean, default: false
  attr :context, :atom, default: nil
  attr :quick_actions, :list, default: []
  attr :rest, :global

  def intelligence_bar(assigns) do
    ~H"""
    <div
      class={[
        "intelligence-bar fixed bottom-0 left-0 right-0 z-50",
        "bg-gradient-to-r from-primary/5 via-secondary/5 to-accent/5",
        "backdrop-blur-md border-t border-base-300",
        "transition-all duration-300 ease-in-out",
        @expanded && "intelligence-bar-expanded"
      ]}
      {@rest}
    >
      <div class="max-w-7xl mx-auto">
        <%= if @expanded do %>
          <.expanded_view
            message={@message}
            loading={@loading}
            context={@context}
            quick_actions={@quick_actions}
          />
        <% else %>
          <.minimized_view />
        <% end %>
      </div>
    </div>
    """
  end

  defp minimized_view(assigns) do
    ~H"""
    <div
      class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-base-200/50 transition-colors"
      phx-click="expand_intelligence_bar"
    >
      <div class="flex items-center gap-2 text-primary">
        <.icon name="hero-sparkles" class="size-5 animate-pulse" />
        <span class="font-medium">Ask AI</span>
      </div>
      <div class="flex-1 text-base-content/50 text-sm">
        Type a question or click for suggestions...
      </div>
      <div class="flex items-center gap-2 text-sm text-base-content/50">
        <kbd class="kbd kbd-sm">⌘</kbd>
        <kbd class="kbd kbd-sm">K</kbd>
      </div>
    </div>
    """
  end

  attr :message, :string, default: nil
  attr :loading, :boolean, default: false
  attr :context, :atom, default: nil
  attr :quick_actions, :list, default: []

  defp expanded_view(assigns) do
    ~H"""
    <div class="p-4">
      <div class="flex items-center gap-3 mb-3">
        <div class="flex items-center gap-2 text-primary">
          <.icon name="hero-sparkles" class="size-5" />
          <span class="font-medium">AI Assistant</span>
        </div>
        <button
          phx-click="collapse_intelligence_bar"
          class="ml-auto btn btn-ghost btn-sm btn-circle"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <div :if={@message || @loading} class="mb-4 p-4 bg-base-200 rounded-lg">
        <div :if={@loading} class="flex items-center gap-2">
          <span class="loading loading-dots loading-sm"></span>
          <span class="text-base-content/60">Thinking...</span>
        </div>
        <div :if={@message && !@loading} class="prose prose-sm max-w-none">
          {@message}
        </div>
      </div>

      <form phx-submit="submit_ai_query" class="flex gap-2">
        <input
          type="text"
          name="query"
          placeholder="What would you like to know?"
          class="input input-bordered flex-1"
          phx-keydown="ai_input_keydown"
          autocomplete="off"
        />
        <.button type="submit" variant="primary">
          <.icon name="hero-paper-airplane" class="size-4" />
        </.button>
      </form>

      <div :if={@quick_actions != []} class="mt-3 flex flex-wrap gap-2">
        <span class="text-sm text-base-content/50">Quick:</span>
        <button
          :for={action <- @quick_actions}
          type="button"
          phx-click="ai_quick_action"
          phx-value-query={action.query}
          class="btn btn-xs btn-ghost"
        >
          {action.label}
        </button>
      </div>

      <div :if={@quick_actions == []} class="mt-3 flex flex-wrap gap-2">
        <span class="text-sm text-base-content/50">Try:</span>
        <button
          type="button"
          phx-click="ai_quick_action"
          phx-value-query="What's my best selling product?"
          class="btn btn-xs btn-ghost"
        >
          Best sellers
        </button>
        <button
          type="button"
          phx-click="ai_quick_action"
          phx-value-query="Show me low stock items"
          class="btn btn-xs btn-ghost"
        >
          Low stock
        </button>
        <button
          type="button"
          phx-click="ai_quick_action"
          phx-value-query="How are sales today?"
          class="btn btn-xs btn-ghost"
        >
          Today's sales
        </button>
      </div>
    </div>
    """
  end
end
```

```elixir
# lib/mcp_web/live/components/intelligence_bar_live.ex
defmodule McpWeb.Live.Components.IntelligenceBarLive do
  @moduledoc """
  Live component for Intelligence Bar state management.
  """
  use McpWeb, :live_component

  alias Mcp.AI.Service
  alias McpWeb.Portal.IntelligenceBar

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:expanded, false)
      |> assign(:message, nil)
      |> assign(:loading, false)
      |> assign(:query, "")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <IntelligenceBar.intelligence_bar
        expanded={@expanded}
        message={@message}
        loading={@loading}
        context={@context}
        quick_actions={@quick_actions}
      />
    </div>
    """
  end

  @impl true
  def handle_event("expand_intelligence_bar", _params, socket) do
    {:noreply, assign(socket, expanded: true)}
  end

  @impl true
  def handle_event("collapse_intelligence_bar", _params, socket) do
    {:noreply, assign(socket, expanded: false, message: nil)}
  end

  @impl true
  def handle_event("submit_ai_query", %{"query" => query}, socket) do
    # Start streaming response
    socket = assign(socket, loading: true, query: query)

    # Process in background
    send(self(), {:ai_query, query, socket.assigns.context})

    {:noreply, socket}
  end

  @impl true
  def handle_event("ai_quick_action", %{"query" => query}, socket) do
    socket = assign(socket, loading: true, query: query)
    send(self(), {:ai_query, query, socket.assigns.context})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:ai_query, query, context}, socket) do
    case Service.natural_language_search(context || :general, query) do
      {:ok, response} ->
        message = format_ai_response(response)
        {:noreply, assign(socket, message: message, loading: false)}

      {:error, _} ->
        {:noreply,
         assign(socket,
           message: "I couldn't process that request. Please try again.",
           loading: false
         )}
    end
  end

  @impl true
  def handle_info({:ai_stream_chunk, chunk}, socket) do
    current = socket.assigns.message || ""
    {:noreply, assign(socket, message: current <> chunk)}
  end

  @impl true
  def handle_info(:ai_stream_done, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  defp format_ai_response(response) when is_binary(response), do: response

  defp format_ai_response(results) when is_list(results) do
    count = length(results)
    "Found #{count} result#{if count == 1, do: "", else: "s"}."
  end

  defp format_ai_response(%{results: results, insights: insights}) do
    """
    Found #{length(results)} results.

    #{insights}
    """
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp_web/components/portal/intelligence_bar_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp_web/components/portal/intelligence_bar.ex lib/mcp_web/live/components/intelligence_bar_live.ex test/mcp_web/components/portal/intelligence_bar_test.exs
git commit -m "feat(portal): add Intelligence Bar component with AI chat"
```

---

## Task 3: Sidebar AI Insights Component

**Files:**
- Modify: `lib/mcp_web/components/portal/action_sidebar.ex`
- Create: `lib/mcp_web/live/hooks/ai_insights_hook.ex`
- Test: `test/mcp_web/components/portal/ai_insights_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/portal/ai_insights_test.exs
defmodule McpWeb.Portal.AiInsightsTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "ai_insight/1" do
    test "renders insight with icon and message" do
      assigns = %{
        insight: %{
          message: "This customer is a top spender",
          type: :success,
          action: %{label: "View details", href: "/customers/123"}
        }
      }

      html = rendered_to_string(~H"""
      <.ai_insight insight={@insight} />
      """)

      assert html =~ "This customer is a top spender"
      assert html =~ "View details"
      assert html =~ "hero-sparkles"
    end

    test "renders warning style for warning type" do
      assigns = %{
        insight: %{message: "Low stock alert", type: :warning}
      }

      html = rendered_to_string(~H"""
      <.ai_insight insight={@insight} />
      """)

      assert html =~ "warning" or html =~ "text-warning"
    end

    test "renders suggestion style for suggestion type" do
      assigns = %{
        insight: %{message: "Consider offering a discount", type: :suggestion}
      }

      html = rendered_to_string(~H"""
      <.ai_insight insight={@insight} />
      """)

      assert html =~ "Consider offering"
    end
  end

  describe "ai_insights_section/1" do
    test "renders loading state" do
      assigns = %{loading: true, insights: []}

      html = rendered_to_string(~H"""
      <.ai_insights_section loading={@loading} insights={@insights} />
      """)

      assert html =~ "loading" or html =~ "animate-pulse"
    end

    test "renders multiple insights" do
      assigns = %{
        loading: false,
        insights: [
          %{message: "Insight 1", type: :info},
          %{message: "Insight 2", type: :success}
        ]
      }

      html = rendered_to_string(~H"""
      <.ai_insights_section loading={@loading} insights={@insights} />
      """)

      assert html =~ "Insight 1"
      assert html =~ "Insight 2"
    end

    test "renders empty state when no insights" do
      assigns = %{loading: false, insights: []}

      html = rendered_to_string(~H"""
      <.ai_insights_section loading={@loading} insights={@insights} />
      """)

      assert html =~ "No insights" or html =~ "AI is analyzing"
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/components/portal/action_sidebar.ex lib/mcp_web/live/hooks/ai_insights_hook.ex test/mcp_web/components/portal/ai_insights_test.exs
git commit -m "feat(portal): add AI insights to sidebar with async loading"
```

---

## Task 4: Natural Language Search

**Files:**
- Create: `lib/mcp_web/live/components/search_modal_live.ex`
- Create: `lib/mcp_web/components/portal/search_modal.ex`
- Test: `test/mcp_web/live/components/search_modal_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/components/search_modal_live_test.exs
defmodule McpWeb.Live.Components.SearchModalLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "search modal" do
    test "opens with keyboard shortcut", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      # Simulate Cmd+K
      view |> render_keydown(%{key: "k", metaKey: true})

      assert has_element?(view, "[data-testid='search-modal']")
    end

    test "performs natural language search", %{conn: conn} do
      insert(:product, name: "Blue T-Shirt", status: :active)

      {:ok, view, _html} = live(conn, ~p"/app/products")

      view |> render_keydown(%{key: "k", metaKey: true})

      view
      |> form("#search-form", %{query: "show me blue shirts"})
      |> render_submit()

      assert has_element?(view, "[data-testid='search-result']", "Blue T-Shirt")
    end

    test "shows recent searches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/products")

      view |> render_keydown(%{key: "k", metaKey: true})

      assert has_element?(view, "[data-testid='recent-searches']")
    end

    test "navigates to result on click", %{conn: conn} do
      product = insert(:product, name: "Test Product", status: :active)

      {:ok, view, _html} = live(conn, ~p"/app/products")

      view |> render_keydown(%{key: "k", metaKey: true})

      view
      |> form("#search-form", %{query: "test product"})
      |> render_submit()

      {:ok, _view, html} =
        view
        |> element("[data-testid='search-result-#{product.id}']")
        |> render_click()
        |> follow_redirect(conn, ~p"/app/products/#{product.id}")

      assert html =~ "Test Product"
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/components/search_modal_live.ex lib/mcp_web/components/portal/search_modal.ex test/mcp_web/live/components/search_modal_live_test.exs
git commit -m "feat(portal): add natural language search modal with Cmd+K"
```

---

## Task 5: Customer Insights Integration

**Files:**
- Modify: `lib/mcp_web/live/merchant/customers/show_live.ex`
- Test: `test/mcp_web/live/merchant/customers/show_live_ai_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/customers/show_live_ai_test.exs
defmodule McpWeb.Merchant.Customers.ShowLiveAiTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "AI insights" do
    test "loads customer insights asynchronously", %{conn: conn} do
      customer = insert(:customer, total_orders: 10, total_spent: Money.new(50000, :USD))

      {:ok, view, _html} = live(conn, ~p"/app/customers/#{customer.id}")

      # Initially shows loading
      assert has_element?(view, "[data-testid='ai-insights-loading']")

      # Wait for async load
      :timer.sleep(100)

      # Shows insights
      assert has_element?(view, "[data-testid='ai-insight']")
    end

    test "shows purchase pattern analysis", %{conn: conn} do
      customer = insert(:customer)
      for _ <- 1..5 do
        order = insert(:order, customer: customer, status: :completed)
        insert(:order_item, order: order)
      end

      {:ok, view, _html} = live(conn, ~p"/app/customers/#{customer.id}")

      # Wait for analysis
      :timer.sleep(200)

      assert has_element?(view, "[data-testid='purchase-patterns']")
    end

    test "shows product recommendations", %{conn: conn} do
      customer = insert(:customer)
      insert(:order, customer: customer, status: :completed)

      {:ok, view, _html} = live(conn, ~p"/app/customers/#{customer.id}")

      # Wait for recommendations
      :timer.sleep(200)

      assert has_element?(view, "[data-testid='ai-recommendations']")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/customers/show_live.ex test/mcp_web/live/merchant/customers/show_live_ai_test.exs
git commit -m "feat(merchant): add AI insights to Customer Detail"
```

---

## Task 6: POS Product Recommendations

**Files:**
- Modify: `lib/mcp_web/live/store/pos_live.ex`
- Create: `lib/mcp_web/components/pos/ai_recommendations.ex`
- Test: `test/mcp_web/components/pos/ai_recommendations_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/components/pos/ai_recommendations_test.exs
defmodule McpWeb.POS.AiRecommendationsTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_store_user

  describe "POS recommendations" do
    test "shows upsell suggestions based on cart", %{conn: conn} do
      product = insert(:product, price: Money.new(2999, :USD))

      {:ok, view, _html} = live(conn, ~p"/store/pos")

      # Add item to cart
      view |> element("[data-testid='product-#{product.id}']") |> render_click()

      # Wait for recommendations
      :timer.sleep(100)

      assert has_element?(view, "[data-testid='ai-upsell-section']")
    end

    test "shows customer-based suggestions when customer selected", %{conn: conn} do
      customer = insert(:customer)
      insert(:order, customer: customer, status: :completed)

      {:ok, view, _html} = live(conn, ~p"/store/pos")

      # Select customer
      view |> element("[data-testid='select-customer']") |> render_click()
      view |> element("[data-testid='customer-#{customer.id}']") |> render_click()

      # Wait for recommendations
      :timer.sleep(100)

      assert has_element?(view, "[data-testid='ai-customer-suggestions']")
    end

    test "can add recommended product to cart", %{conn: conn} do
      product = insert(:product)
      recommended = insert(:product, name: "Recommended Product")

      {:ok, view, _html} = live(conn, ~p"/store/pos")

      # Add item to trigger recommendations
      view |> element("[data-testid='product-#{product.id}']") |> render_click()

      :timer.sleep(100)

      # Click recommended product
      view |> element("[data-testid='add-recommended-#{recommended.id}']") |> render_click()

      assert has_element?(view, "[data-testid='cart-item']", "Recommended Product")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/store/pos_live.ex lib/mcp_web/components/pos/ai_recommendations.ex test/mcp_web/components/pos/ai_recommendations_test.exs
git commit -m "feat(store): add AI product recommendations to POS"
```

---

## Task 7: Reports AI Analysis

**Files:**
- Modify: `lib/mcp_web/live/merchant/reports/sales_live.ex`
- Test: `test/mcp_web/live/merchant/reports/sales_live_ai_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/merchant/reports/sales_live_ai_test.exs
defmodule McpWeb.Merchant.Reports.SalesLiveAiTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "AI analysis" do
    test "shows AI-generated summary of sales data", %{conn: conn} do
      for _ <- 1..10 do
        insert(:order, status: :completed)
      end

      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      # Wait for AI analysis
      :timer.sleep(200)

      assert has_element?(view, "[data-testid='ai-summary']")
    end

    test "shows trend insights", %{conn: conn} do
      # Create trending data
      for day <- 1..30 do
        insert(:order,
          status: :completed,
          total: Money.new(1000 + day * 100, :USD),
          inserted_at: DateTime.add(DateTime.utc_now(), -day * 86400)
        )
      end

      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      :timer.sleep(200)

      assert has_element?(view, "[data-testid='trend-insight']")
    end

    test "can ask questions about the data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app/reports/sales")

      view |> element("[data-testid='ask-ai-btn']") |> render_click()

      view
      |> form("#ai-question-form", %{question: "What day has the highest sales?"})
      |> render_submit()

      :timer.sleep(200)

      assert has_element?(view, "[data-testid='ai-answer']")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/merchant/reports/sales_live.ex test/mcp_web/live/merchant/reports/sales_live_ai_test.exs
git commit -m "feat(merchant): add AI analysis to Sales Report"
```

---

## Task 8: Inventory Alert System

**Files:**
- Create: `lib/mcp/ai/inventory_monitor.ex`
- Create: `lib/mcp_web/live/merchant/alerts_live.ex`
- Test: `test/mcp/ai/inventory_monitor_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp/ai/inventory_monitor_test.exs
defmodule Mcp.AI.InventoryMonitorTest do
  use Mcp.DataCase, async: true

  alias Mcp.AI.InventoryMonitor

  describe "check_inventory/0" do
    test "generates alerts for low stock products" do
      insert(:product, name: "Low Stock", track_inventory: true, quantity_on_hand: 5, low_stock_threshold: 10)
      insert(:product, name: "OK Stock", track_inventory: true, quantity_on_hand: 50, low_stock_threshold: 10)

      alerts = InventoryMonitor.check_inventory()

      assert length(alerts) == 1
      assert hd(alerts).type == :low_stock
      assert hd(alerts).product_name == "Low Stock"
    end

    test "generates alerts for out of stock products" do
      insert(:product, name: "Out of Stock", track_inventory: true, quantity_on_hand: 0)

      alerts = InventoryMonitor.check_inventory()

      assert length(alerts) == 1
      assert hd(alerts).type == :out_of_stock
    end

    test "predicts potential stockouts" do
      product = insert(:product, track_inventory: true, quantity_on_hand: 20)

      # Simulate high sales velocity
      for day <- 1..7 do
        order = insert(:order, status: :completed, inserted_at: DateTime.add(DateTime.utc_now(), -day * 86400))
        insert(:order_item, order: order, product: product, quantity: 3)
      end

      alerts = InventoryMonitor.check_inventory()

      # Should predict stockout at 3/day * 7 days = 21, current = 20
      prediction_alert = Enum.find(alerts, &(&1.type == :predicted_stockout))
      assert prediction_alert != nil
    end
  end

  describe "get_reorder_suggestions/0" do
    test "suggests products to reorder" do
      insert(:product, name: "Reorder Me", track_inventory: true, quantity_on_hand: 5, low_stock_threshold: 10)

      suggestions = InventoryMonitor.get_reorder_suggestions()

      assert length(suggestions) >= 1
      assert Enum.any?(suggestions, &(&1.product_name == "Reorder Me"))
    end

    test "includes suggested quantity based on sales velocity" do
      product = insert(:product, track_inventory: true, quantity_on_hand: 5, low_stock_threshold: 10)

      # High sales velocity
      for _ <- 1..10 do
        order = insert(:order, status: :completed)
        insert(:order_item, order: order, product: product, quantity: 2)
      end

      suggestions = InventoryMonitor.get_reorder_suggestions()
      suggestion = Enum.find(suggestions, &(&1.product_id == product.id))

      assert suggestion.suggested_quantity > 0
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp/ai/inventory_monitor.ex lib/mcp_web/live/merchant/alerts_live.ex test/mcp/ai/inventory_monitor_test.exs
git commit -m "feat(ai): add inventory monitoring with predictive alerts"
```

---

## Task 9: AI Chat Modal

**Files:**
- Create: `lib/mcp_web/live/components/ai_chat_modal_live.ex`
- Create: `lib/mcp_web/components/portal/ai_chat_modal.ex`
- Test: `test/mcp_web/live/components/ai_chat_modal_live_test.exs`

**Step 1: Write the failing test**

```elixir
# test/mcp_web/live/components/ai_chat_modal_live_test.exs
defmodule McpWeb.Live.Components.AiChatModalLiveTest do
  use McpWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "AI chat modal" do
    test "opens from help menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app")

      view |> element("[data-testid='ai-chat-btn']") |> render_click()

      assert has_element?(view, "[data-testid='ai-chat-modal']")
    end

    test "sends message and receives streamed response", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app")

      view |> element("[data-testid='ai-chat-btn']") |> render_click()

      view
      |> form("#chat-form", %{message: "Hello, how can you help me?"})
      |> render_submit()

      # Should show user message
      assert has_element?(view, "[data-testid='user-message']", "Hello")

      # Wait for response
      :timer.sleep(200)

      # Should show AI response
      assert has_element?(view, "[data-testid='ai-message']")
    end

    test "maintains conversation history", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app")

      view |> element("[data-testid='ai-chat-btn']") |> render_click()

      # Send first message
      view
      |> form("#chat-form", %{message: "What products do I have?"})
      |> render_submit()

      :timer.sleep(100)

      # Send follow-up
      view
      |> form("#chat-form", %{message: "Which one has low stock?"})
      |> render_submit()

      :timer.sleep(100)

      # Should have both messages in history
      assert has_element?(view, "[data-testid='user-message']", "products")
      assert has_element?(view, "[data-testid='user-message']", "low stock")
    end

    test "can clear conversation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/app")

      view |> element("[data-testid='ai-chat-btn']") |> render_click()

      view
      |> form("#chat-form", %{message: "Hello"})
      |> render_submit()

      :timer.sleep(100)

      view |> element("[data-testid='clear-chat']") |> render_click()

      refute has_element?(view, "[data-testid='user-message']")
    end
  end
end
```

**Step 2-5:** Follow TDD pattern.

**Step 5: Commit**

```bash
git add lib/mcp_web/live/components/ai_chat_modal_live.ex lib/mcp_web/components/portal/ai_chat_modal.ex test/mcp_web/live/components/ai_chat_modal_live_test.exs
git commit -m "feat(portal): add AI chat modal with conversation history"
```

---

## Task 10: Integration and Global Setup

**Files:**
- Modify: `lib/mcp_web/components/layouts/app.html.heex`
- Create: `lib/mcp_web/live/hooks/ai_global_hook.ex`
- Test: Integration tests

**Step 1: Update layout to include Intelligence Bar**

In `app.html.heex`:

```heex
<main class="pb-20">
  <%= @inner_content %>
</main>

<.live_component
  module={McpWeb.Live.Components.IntelligenceBarLive}
  id="intelligence-bar"
  context={assigns[:ai_context]}
  quick_actions={assigns[:ai_quick_actions] || []}
/>
```

**Step 2: Add keyboard shortcut handler**

```elixir
# lib/mcp_web/live/hooks/ai_global_hook.ex
defmodule McpWeb.Live.Hooks.AiGlobalHook do
  @moduledoc """
  Global hooks for AI features including keyboard shortcuts.
  """
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> attach_hook(:ai_keyboard, :handle_event, &handle_keyboard/3)
      |> assign(:ai_context, nil)
      |> assign(:ai_quick_actions, [])

    {:cont, socket}
  end

  defp handle_keyboard("keydown", %{"key" => "k", "metaKey" => true}, socket) do
    send(self(), :open_search_modal)
    {:halt, socket}
  end

  defp handle_keyboard("keydown", %{"key" => "j", "metaKey" => true}, socket) do
    send(self(), :toggle_intelligence_bar)
    {:halt, socket}
  end

  defp handle_keyboard(_event, _params, socket) do
    {:cont, socket}
  end
end
```

**Step 3: Commit**

```bash
git add lib/mcp_web/components/layouts/app.html.heex lib/mcp_web/live/hooks/ai_global_hook.ex
git commit -m "feat(portal): integrate AI features globally with keyboard shortcuts"
```

---

## Success Criteria

Phase 5 is complete when:

- [ ] All tests pass (`mix test`)
- [ ] `mix precommit` passes
- [ ] AI Service connects to Ollama successfully
- [ ] Intelligence Bar appears on all pages
- [ ] Sidebar AI insights load asynchronously
- [ ] Natural language search works (Cmd+K)
- [ ] Customer Detail shows AI insights
- [ ] POS shows product recommendations
- [ ] Sales Report has AI analysis
- [ ] Inventory alerts are generated
- [ ] AI Chat modal is functional
- [ ] Keyboard shortcuts work (Cmd+K, Cmd+J)

---

## Quality Gates Between Tasks

After each task, run:

```bash
mix test test/path/to/new_test.exs  # New tests pass
mix compile --warnings-as-errors     # No warnings
mix format --check-formatted         # Code formatted
```

Before declaring Phase 5 complete, run:

```bash
mix precommit  # Full quality check
```

---

## Post-Implementation

After all phases are complete:

1. Run full test suite: `mix test`
2. Run quality checks: `mix precommit`
3. Visual verification of all features
4. Performance testing with AI features
5. Documentation update
