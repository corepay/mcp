# Billing & Subscription Management - Developer Guide

This guide provides technical implementation details for developers and LLM agents working with the MCP billing system. Includes setup instructions, code examples, testing strategies, and integration patterns.

## Architecture Overview

The billing system uses a multi-layered architecture:

- **Payment Gateway Layer**: Integration with Stripe, PayPal, and other payment processors
- **Billing Engine Core**: Subscription management, invoicing, and revenue recognition
- **Data Layer**: Ash resources with PostgreSQL for transaction integrity
- **API Layer**: RESTful endpoints with GraphQL mutations for billing operations
- **Notification Layer**: Event-driven billing notifications and customer communications

## Setup and Configuration

### Database Schema Setup

```elixir
# Create billing tables
defmodule Mcp.Billing.Migrations.CreateBillingTables do
  use Ecto.Migration

  def change do
    create table(:billing_customers) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id), null: false
      add :stripe_customer_id, :string
      add :paypal_customer_id, :string
      add :billing_email, :string, null: false
      add :default_payment_method_id, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:billing_plans) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :name, :string, null: false
      add :description, :text
      add :amount, :integer, null: false  # in cents
      add :currency, :string, default: "USD"
      add :interval, :string, default: "month"  # day, week, month, year
      add :interval_count, :integer, default: 1
      add :trial_period_days, :integer, default: 0
      add :active, :boolean, default: true
      add :features, :map, default: %{}
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:billing_subscriptions) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :customer_id, references(:billing_customers, type: :binary_id), null: false
      add :plan_id, references(:billing_plans, type: :binary_id), null: false
      add :stripe_subscription_id, :string
      add :status, :string, default: "trialing"  # trialing, active, past_due, canceled, unpaid
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :trial_start, :utc_datetime
      add :trial_end, :utc_datetime
      add :canceled_at, :utc_datetime
      add :ended_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:billing_invoices) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :customer_id, references(:billing_customers, type: :binary_id), null: false
      add :subscription_id, references(:billing_subscriptions, type: :binary_id)
      add :stripe_invoice_id, :string
      add :status, :string, default: "draft"  # draft, open, paid, void, uncollectible
      add :amount_due, :integer
      add :amount_paid, :integer, default: 0
      add :amount_remaining, :integer
      add :currency, :string, default: "USD"
      add :due_date, :utc_datetime
      add :paid_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:billing_invoice_items) do
      add :invoice_id, references(:billing_invoices, type: :binary_id), null: false
      add :description, :string, null: false
      add :amount, :integer, null: false
      add :currency, :string, default: "USD"
      add :quantity, :integer, default: 1
      add :unit_amount, :integer
      add :period_start, :utc_datetime
      add :period_end, :utc_datetime
      add :proration, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:billing_payments) do
      add :tenant_id, references(:tenants, type: :binary_id), null: false
      add :customer_id, references(:billing_customers, type: :binary_id), null: false
      add :invoice_id, references(:billing_invoices, type: :binary_id)
      add :stripe_payment_intent_id, :string
      add :amount, :integer, null: false
      add :currency, :string, default: "USD"
      add :status, :string, default: "pending"  # pending, processing, succeeded, failed, canceled
      add :payment_method_id, :string
      add :failure_reason, :string
      add :receipt_url, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    # Indexes for performance
    create index(:billing_customers, [:tenant_id, :user_id])
    create index(:billing_subscriptions, [:customer_id, :status])
    create index(:billing_invoices, [:customer_id, :status])
    create index(:billing_payments, [:customer_id, :status])
  end
end
```

### Ash Resource Definitions

```elixir
defmodule Mcp.Billing.Customer do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "billing_customers"
    repo Mcp.Core.Repo
  end

  json_api do
    type "billing_customer"
  end

  attributes do
    uuid_primary_key :id

    attribute :stripe_customer_id, :string, allow_nil?: true
    attribute :paypal_customer_id, :string, allow_nil?: true
    attribute :billing_email, :string, allow_nil?: false
    attribute :default_payment_method_id, :string, allow_nil?: true
    attribute :metadata, :map, default: %{}

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :tenant, Mcp.MultiTenancy.Tenant, allow_nil?: false
    belongs_to :user, Mcp.Accounts.User, allow_nil?: false

    has_many :subscriptions, Mcp.Billing.Subscription
    has_many :invoices, Mcp.Billing.Invoice
    has_many :payments, Mcp.Billing.Payment
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      accept [:stripe_customer_id, :paypal_customer_id, :billing_email, :default_payment_method_id, :metadata]

      argument :tenant_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:tenant, type: :append_and_remove)
      change manage_relationship(:user, type: :append_and_remove)
    end
  end
end

defmodule Mcp.Billing.Plan do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "billing_plans"
    repo Mcp.Core.Repo
  end

  json_api do
    type "billing_plan"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :amount, :integer, allow_nil?: false  # in cents
    attribute :currency, :string, default: "USD"
    attribute :interval, :string, default: "month"  # day, week, month, year
    attribute :interval_count, :integer, default: 1
    attribute :trial_period_days, :integer, default: 0
    attribute :active, :boolean, default: true
    attribute :features, :map, default: %{}
    attribute :metadata, :map, default: %{}

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :tenant, Mcp.MultiTenancy.Tenant, allow_nil?: false

    has_many :subscriptions, Mcp.Billing.Subscription
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true
      accept [:name, :description, :amount, :currency, :interval, :interval_count, :trial_period_days, :active, :features, :metadata]

      argument :tenant_id, :uuid, allow_nil?: false

      change manage_relationship(:tenant, type: :append_and_remove)
    end
  end
end
```

### Payment Gateway Integration

```elixir
defmodule Mcp.Billing.StripeAdapter do
  @moduledoc """
  Stripe payment processor adapter for billing operations
  """

  def create_customer(customer_params) do
    Stripe.Customer.create(%{
      email: customer_params.billing_email,
      metadata: customer_params.metadata,
      description: "Customer for tenant #{customer_params.tenant_id}"
    })
  end

  def create_payment_method(customer_id, payment_method_params) do
    Stripe.PaymentMethod.attach(payment_method_params.payment_method_id, %{
      customer: customer_id
    })
  end

  def create_subscription(customer_id, plan_id, subscription_params) do
    Stripe.Subscription.create(%{
      customer: customer_id,
      items: [%{price: plan_id}],
      trial_period_days: subscription_params.trial_period_days,
      metadata: subscription_params.metadata
    })
  end

  def create_invoice(customer_id, invoice_params) do
    Stripe.Invoice.create(%{
      customer: customer_id,
      collection_method: "charge_automatically",
      metadata: invoice_params.metadata
    })
  end

  def finalize_invoice(invoice_id) do
    Stripe.Invoice.finalize_invoice(invoice_id)
  end

  def create_payment_intent(payment_params) do
    Stripe.PaymentIntent.create(%{
      amount: payment_params.amount,
      currency: payment_params.currency,
      customer: payment_params.customer_id,
      payment_method: payment_params.payment_method_id,
      confirmation_method: "automatic",
      confirm: true,
      metadata: payment_params.metadata
    })
  end

  def retrieve_payment_intent(payment_intent_id) do
    Stripe.PaymentIntent.retrieve(payment_intent_id)
  end

  def handle_webhook_event(raw_body, stripe_signature) do
    webhook_secret = Application.get_env(:mcp, :stripe_webhook_secret)

    case Stripe.Webhook.construct_event(raw_body, stripe_signature, webhook_secret) do
      {:ok, %Stripe.Event{type: event_type, data: %{object: event_data}}} ->
        process_webhook_event(event_type, event_data)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_webhook_event("invoice.payment_succeeded", invoice) do
    Mcp.Billing.InvoicePaymentSucceeded.handle(invoice)
  end

  defp process_webhook_event("invoice.payment_failed", invoice) do
    Mcp.Billing.InvoicePaymentFailed.handle(invoice)
  end

  defp process_webhook_event("customer.subscription.created", subscription) do
    Mcp.Billing.SubscriptionCreated.handle(subscription)
  end

  defp process_webhook_event("customer.subscription.updated", subscription) do
    Mcp.Billing.SubscriptionUpdated.handle(subscription)
  end

  defp process_webhook_event("customer.subscription.deleted", subscription) do
    Mcp.Billing.SubscriptionDeleted.handle(subscription)
  end

  defp process_webhook_event(_, _), do: :ok
end
```

### Billing Service Implementation

```elixir
defmodule Mcp.Billing.Service do
  @moduledoc """
  Core billing service for managing customers, subscriptions, and payments
  """

  alias Mcp.Billing.{Customer, Plan, Subscription, Invoice, Payment}
  alias Mcp.Billing.StripeAdapter

  def create_customer(customer_params) do
    with {:ok, stripe_customer} <- StripeAdapter.create_customer(customer_params) do
      Customer.create(%{
        tenant_id: customer_params.tenant_id,
        user_id: customer_params.user_id,
        stripe_customer_id: stripe_customer.id,
        billing_email: customer_params.billing_email,
        metadata: customer_params.metadata
      })
    end
  end

  def create_subscription(customer_id, plan_id, subscription_params) do
    with {:ok, customer} <- Customer.by_id(customer_id),
         {:ok, plan} <- Plan.by_id(plan_id),
         {:ok, stripe_subscription} <- StripeAdapter.create_subscription(
           customer.stripe_customer_id,
           plan.stripe_price_id,
           subscription_params
         ) do
      Subscription.create(%{
        tenant_id: customer.tenant_id,
        customer_id: customer_id,
        plan_id: plan_id,
        stripe_subscription_id: stripe_subscription.id,
        status: stripe_subscription.status,
        current_period_start: DateTime.from_unix!(stripe_subscription.current_period_start),
        current_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
        trial_start: stripe_subscription.trial_start && DateTime.from_unix!(stripe_subscription.trial_start),
        trial_end: stripe_subscription.trial_end && DateTime.from_unix!(stripe_subscription.trial_end),
        metadata: stripe_subscription.metadata
      })
    end
  end

  def create_invoice(customer_id, invoice_items) do
    with {:ok, customer} <- Customer.by_id(customer_id),
         {:ok, stripe_invoice} <- StripeAdapter.create_invoice(customer.stripe_customer_id, %{}) do

      # Add invoice items
      Enum.each(invoice_items, fn item ->
        Stripe.InvoiceItem.create(%{
          customer: customer.stripe_customer_id,
          amount: item.amount,
          currency: item.currency,
          description: item.description,
          quantity: item.quantity
        })
      end)

      # Finalize invoice
      {:ok, finalized_invoice} <- StripeAdapter.finalize_invoice(stripe_invoice.id)

      Invoice.create(%{
        tenant_id: customer.tenant_id,
        customer_id: customer_id,
        stripe_invoice_id: finalized_invoice.id,
        status: finalized_invoice.status,
        amount_due: finalized_invoice.amount_due,
        amount_paid: finalized_invoice.amount_paid,
        amount_remaining: finalized_invoice.amount_remaining,
        currency: finalized_invoice.currency,
        due_date: DateTime.from_unix!(finalized_invoice.due_date),
        metadata: finalized_invoice.metadata
      })
    end
  end

  def process_payment(customer_id, invoice_id, payment_params) do
    with {:ok, customer} <- Customer.by_id(customer_id),
         {:ok, invoice} <- Invoice.by_id(invoice_id),
         {:ok, payment_intent} <- StripeAdapter.create_payment_intent(%{
           amount: invoice.amount_due,
           currency: invoice.currency,
           customer_id: customer.stripe_customer_id,
           payment_method_id: customer.default_payment_method_id || payment_params.payment_method_id,
           metadata: Map.put(payment_params.metadata, "invoice_id", invoice_id)
         }) do

      Payment.create(%{
        tenant_id: customer.tenant_id,
        customer_id: customer_id,
        invoice_id: invoice_id,
        stripe_payment_intent_id: payment_intent.id,
        amount: payment_intent.amount,
        currency: payment_intent.currency,
        status: payment_intent.status,
        payment_method_id: payment_intent.payment_method,
        metadata: payment_intent.metadata
      })
    end
  end

  def cancel_subscription(subscription_id, cancel_params \\ %{}) do
    with {:ok, subscription} <- Subscription.by_id(subscription_id) do
      case StripeAdapter.cancel_subscription(subscription.stripe_subscription_id, cancel_params) do
        {:ok, cancelled_subscription} ->
          Subscription.update(subscription, %{
            status: cancelled_subscription.status,
            canceled_at: DateTime.from_unix!(cancelled_subscription.canceled_at),
            ended_at: cancelled_subscription.ended_at && DateTime.from_unix!(cancelled_subscription.ended_at)
          })
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
```

### Phoenix Controllers

```elixir
defmodule McpWeb.Billing.CustomerController do
  use McpWeb, :controller

  alias Mcp.Billing.{Customer, Service}

  def create(conn, %{"customer" => customer_params}) do
    current_user = conn.assigns.current_user
    tenant_id = conn.assigns.current_tenant.id

    customer_params = Map.merge(customer_params, %{
      "tenant_id" => tenant_id,
      "user_id" => current_user.id
    })

    case Service.create_customer(customer_params) do
      {:ok, customer} ->
        conn
        |> put_status(:created)
        |> render(:show, customer: customer)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.current_tenant.id

    case Customer.by_tenant_and_id(tenant_id, id) do
      {:ok, customer} ->
        render(conn, :show, customer: customer)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Customer not found")
    end
  end

  def update(conn, %{"id" => id, "customer" => customer_params}) do
    tenant_id = conn.assigns.current_tenant.id

    case Customer.by_tenant_and_id(tenant_id, id) do
      {:ok, customer} ->
        case Customer.update(customer, customer_params) do
          {:ok, updated_customer} ->
            render(conn, :show, customer: updated_customer)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:error, changeset: changeset)
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Customer not found")
    end
  end
end
```

### LiveView Components

```elixir
defmodule McpWeb.Billing.SubscriptionLive.Index do
  use McpWeb, :live_view

  alias Mcp.Billing.{Subscription, Service}

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = socket.assigns.current_tenant.id

    {:ok, stream(socket, :subscriptions, Subscription.by_tenant(tenant_id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Subscription")
    |> assign(:subscription, Subscription.by_id!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Subscription")
    |> assign(:subscription, %Subscription{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Subscriptions")
    |> assign(:subscription, nil)
  end

  @impl true
  def handle_event("cancel_subscription", %{"subscription_id" => subscription_id}, socket) do
    case Service.cancel_subscription(subscription_id) do
      {:ok, _subscription} ->
        {:noreply,
         socket
         |> put_flash(:info, "Subscription cancelled successfully")
         |> push_patch(to: ~p"/billing/subscriptions")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel subscription")}
    end
  end
end

defmodule McpWeb.Billing.Components.SubscriptionCard do
  use McpWeb, :component

  attr :subscription, Mcp.Billing.Subscription, required: true
  attr :actions, :list, default: []

  def subscription_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">
          {@subscription.plan.name}
          <div class="badge badge-ghost badge-sm">
            {@subscription.status}
          </div>
        </h2>

        <p class="text-sm opacity-70">
          Period: {format_date(@subscription.current_period_start)} - {format_date(@subscription.current_period_end)}
        </p>

        <div class="card-actions justify-end">
          <%= for action <- @actions do %>
            <button phx-click={action.action} phx-value-subscription_id={@subscription.id} class={action.class}>
              {action.label}
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end

  defp format_date(nil), do: "N/A"
end
```

## Testing Strategies

### Unit Tests

```elixir
defmodule Mcp.Billing.ServiceTest do
  use Mcp.DataCase

  alias Mcp.Billing.{Customer, Plan, Service}

  describe "create_customer/1" do
    test "creates customer with valid attributes" do
      tenant = insert!(:tenant)
      user = insert!(:user)

      customer_params = %{
        tenant_id: tenant.id,
        user_id: user.id,
        billing_email: "customer@example.com",
        metadata: %{"source" => "web"}
      }

      assert {:ok, %Customer{} = customer} = Service.create_customer(customer_params)
      assert customer.billing_email == "customer@example.com"
      assert customer.tenant_id == tenant.id
      assert customer.user_id == user.id
    end

    test "returns error with invalid email" do
      tenant = insert!(:tenant)
      user = insert!(:user)

      customer_params = %{
        tenant_id: tenant.id,
        user_id: user.id,
        billing_email: "invalid-email"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Service.create_customer(customer_params)
      assert :billing_email in Keyword.keys(changeset.errors)
    end
  end

  describe "create_subscription/3" do
    test "creates subscription with valid attributes" do
      customer = insert!(:billing_customer)
      plan = insert!(:billing_plan, %{amount: 9999})

      subscription_params = %{
        trial_period_days: 14
      }

      assert {:ok, %Subscription{} = subscription} = Service.create_subscription(
        customer.id,
        plan.id,
        subscription_params
      )
      assert subscription.customer_id == customer.id
      assert subscription.plan_id == plan.id
      assert subscription.status in ["trialing", "active"]
    end
  end
end
```

### Integration Tests

```elixir
defmodule McpWeb.Billing.SubscriptionControllerTest do
  use McpWeb.ConnCase

  alias Mcp.Billing.{Customer, Plan, Subscription}

  setup %{conn: conn} do
    tenant = insert!(:tenant)
    user = insert!(:user, %{tenant_id: tenant.id})
    customer = insert!(:billing_customer, %{tenant_id: tenant.id, user_id: user.id})
    plan = insert!(:billing_plan, %{tenant_id: tenant.id, amount: 9999})

    conn =
      conn
      |> authenticate_user(user)
      |> assign(:current_tenant, tenant)

    {:ok, conn: conn, customer: customer, plan: plan}
  end

  describe "POST /billing/subscriptions" do
    test "creates subscription with valid params", %{conn: conn, customer: customer, plan: plan} do
      subscription_params = %{
        customer_id: customer.id,
        plan_id: plan.id,
        trial_period_days: 14
      }

      conn = post(conn, ~p"/billing/subscriptions", subscription: subscription_params)

      assert redirected_to(conn) == ~p"/billing/subscriptions"

      assert get_flash(conn, :info) =~ "Subscription created successfully"

      # Verify subscription was created in database
      created_subscription = Repo.get_by!(Subscription, customer_id: customer.id, plan_id: plan.id)
      assert created_subscription.status in ["trialing", "active"]
    end

    test "returns error with invalid params", %{conn: conn} do
      subscription_params = %{
        customer_id: nil,
        plan_id: nil
      }

      conn = post(conn, ~p"/billing/subscriptions", subscription: subscription_params)

      assert html_response(conn, 422) =~ "Create Subscription"
    end
  end
end
```

### Mock Testing with Stripe

```elixir
defmodule Mcp.Billing.StripeAdapterTest do
  use ExUnit.Case, async: false

  import Mox

  alias Mcp.Billing.StripeAdapter

  setup :verify_on_exit!

  describe "create_customer/1" do
    test "creates customer successfully" do
      customer_params = %{
        billing_email: "customer@example.com",
        metadata: %{"source" => "web"}
      }

      expect(Stripe.Customer, :create, fn params ->
        assert params.email == "customer@example.com"
        assert params.metadata == %{"source" => "web"}

        {:ok, %Stripe.Customer{id: "cus_test123", email: "customer@example.com"}}
      end)

      assert {:ok, stripe_customer} = StripeAdapter.create_customer(customer_params)
      assert stripe_customer.id == "cus_test123"
      assert stripe_customer.email == "customer@example.com"
    end
  end
end
```

## Best Practices

### Security Considerations

1. **PCI DSS Compliance**: Never store raw credit card numbers or CVCs
2. **Tokenized Payments**: Use payment method tokens from Stripe Elements
3. **Webhook Security**: Verify webhook signatures before processing events
4. **Data Encryption**: Encrypt sensitive billing data at rest

### Performance Optimization

1. **Database Indexing**: Index customer_id, subscription status, and invoice status fields
2. **Caching**: Cache subscription status and plan details for frequent access
3. **Background Jobs**: Process invoice generation and payment retries asynchronously
4. **Rate Limiting**: Implement rate limiting on billing endpoints

### Error Handling

```elixir
defmodule Mcp.Billing.Errors do
  defmodule CustomerNotFound, do: [code: "customer_not_found", message: "Customer not found"]
  defmodule PlanNotFound, do: [code: "plan_not_found", message: "Plan not found"]
  defmodule PaymentFailed, do: [code: "payment_failed", message: "Payment processing failed"]
  defmodule SubscriptionActive, do: [code: "subscription_active", message: "Customer already has active subscription"]
end
```

### Monitoring and Observability

```elixir
defmodule Mcp.Billing.Telemetry do
  @events [:billing_operation_completed, :billing_operation_failed]

  def track_operation(operation, duration, result, metadata \\ %{}) do
    :telemetry.execute(
      [:billing, operation, result],
      %{duration: duration},
      Map.merge(metadata, %{result: result})
    )
  end

  def subscribe do
    :telemetry.attach_many(
      "billing-telemetry",
      @events,
      &handle_event/4,
      nil
    )
  end

  defp handle_event([:billing, operation, result], measurements, metadata, _config) do
    Logger.info(
      "Billing operation: #{operation} - #{result} - #{measurements.duration}μs",
      metadata: metadata
    )
  end
end
```

This developer guide provides comprehensive implementation details for the billing system, including setup instructions, code examples, testing strategies, and best practices for secure and scalable billing operations.