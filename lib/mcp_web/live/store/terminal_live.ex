defmodule McpWeb.Store.TerminalLive do
  @moduledoc """
  Virtual Terminal LiveView - Single-screen payment interface.

  Single-screen layout with:
  - Customer section (optional, collapsible)
  - Two-panel main area: Line items (60%) | Order Summary (40%)
  - Bottom drawer for payment
  - Right drawers for history and browse
  - Modals for quick-create, send link, email, customer
  """
  use McpWeb, :live_view
  import McpWeb.Portal.FocusedLayout

  alias McpWeb.Store.Terminal.State

  # Import external components
  import McpWeb.Components.Terminal.CustomerSection
  import McpWeb.Components.Terminal.SearchDropdown
  import McpWeb.Components.Terminal.LineItems
  import McpWeb.Components.Terminal.AiProductSuggestions
  import McpWeb.Components.Terminal.OrderSummary
  import McpWeb.Components.Terminal.PaymentDrawer
  import McpWeb.Components.Terminal.HistoryDrawer
  import McpWeb.Components.Terminal.BrowseDrawer
  import McpWeb.Components.Terminal.QuickCreateModal
  import McpWeb.Components.Terminal.SendLinkModal
  import McpWeb.Components.Terminal.EmailRequestModal
  import McpWeb.Components.Terminal.CustomerModal
  import McpWeb.Components.Terminal.AiAssistantModal
  import McpWeb.Components.Terminal.NoteModal

  @impl Phoenix.LiveView
  def mount(%{"store_slug" => store_slug}, _session, socket) do
    state = State.new(store_slug)

    socket =
      socket
      |> assign(:page_title, "Virtual Terminal")
      |> assign(:store_slug, store_slug)
      |> assign(:state, state)
      # Search
      |> assign(:search_query, "")
      |> assign(:search_results, %{products: [], fees: [], discounts: []})
      |> assign(:show_search_dropdown, false)
      # AI Natural Language Interpretation
      |> assign(:ai_interpretation, nil)
      # Customer
      |> assign(:customer_query, "")
      |> assign(:customer_results, [])
      |> assign(:show_customer_modal, false)
      |> assign(:customer_form, %{name: "", email: "", phone: ""})
      # Quick-create
      |> assign(:show_create_modal, false)
      |> assign(:create_tab, :product)
      |> assign(:create_form, %{name: "", amount: "", is_percent: false, save_to_catalog: false})
      # Send link
      |> assign(:show_send_link_modal, false)
      |> assign(:link_url, nil)
      |> assign(:link_expiry_days, 7)
      # Pending payment status
      |> assign(:pending_payment, nil)
      # Email
      |> assign(:show_email_modal, false)
      |> assign(:email_sending, false)
      |> assign(:email_sent, false)
      |> assign(:email_subject, "")
      |> assign(:email_message, "")
      |> assign(:email_include_items, true)
      |> assign(:email_allow_partial, false)
      |> assign(:email_due_days, 7)
      # Payment drawer
      |> assign(:show_payment_drawer, false)
      |> assign(:card_number, "")
      |> assign(:expiry, "")
      |> assign(:cvv, "")
      |> assign(:billing_zip, "")
      |> assign(:save_card, false)
      |> assign(:card_errors, %{})
      |> assign(:processing, false)
      |> assign(:processing_timer, nil)
      |> assign(:payment_result, nil)
      # History drawer
      |> assign(:show_history_drawer, false)
      |> assign(:transactions, sample_transactions())
      # Browse drawer
      |> assign(:show_browse_drawer, false)
      |> assign(:browse_type, :products)
      |> assign(:browse_search, "")
      |> assign(:browse_category_filter, nil)
      |> assign(:browse_category_filter, nil)
      |> assign(:browse_price_filter, nil)
      # AI Assistant
      |> assign(:show_ai_assistant, false)
      |> assign(:ai_processing, false)
      # Notes
      |> assign(:show_note_modal, false)
      |> assign(:temp_note, "")

    {:ok, socket, layout: {McpWeb.Layouts, :focused}}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.focused_layout
      title="Virtual Terminal"
      exit={~p"/app/stores/#{@store_slug}/dashboard"}
      variant={:two_panel}
    >
      <:actions>
        <button type="button" class="btn btn-ghost btn-sm gap-2" phx-click="toggle_ai_assistant">
          <span class="font-mono text-xs">⌘</span>
          <span>Ask AI...</span>
        </button>
        <button type="button" class="btn btn-ghost btn-sm gap-2" phx-click="toggle_history">
          <span>History</span>
        </button>
        <button type="button" class="btn btn-ghost btn-sm btn-circle" aria-label="Help">
          <span>?</span>
        </button>
      </:actions>

      <:main_header>
        <!-- Expanded Customer Section (Full Width per Mock) -->
        <.customer_section
          customer={@state.customer}
          class="border-b border-base-300 p-4"
        />
      </:main_header>

      <:left_panel>
        <div class="flex flex-col h-full">
          <!-- Search Bar with AI -->
          <div class="p-4 border-b border-base-300 space-y-3">
            <.search_dropdown
              query={@search_query}
              products={@search_results.products}
              fees={@search_results.fees}
              discounts={@search_results.discounts}
              show_dropdown={@show_search_dropdown}
              ai_interpretation={@ai_interpretation}
            />

            <button
              type="button"
              class="btn btn-ghost btn-sm w-full justification-start gap-2 text-primary"
              phx-click="show_create_modal"
            >
              <.icon name="hero-plus" class="size-4" /> Custom Line Item
            </button>
          </div>
          
    <!-- Line Items -->
          <div class="flex-1 overflow-y-auto p-4">
            <.line_items items={@state.line_items} />
          </div>
          
    <!-- AI Product Suggestions -->
          <.ai_product_suggestions
            :if={@state.customer && length(@state.line_items) == 0}
            suggestions={get_product_suggestions(@state.customer)}
          />
          
    <!-- Note Button -->
          <button
            type="button"
            class="w-full text-left p-4 border-t border-base-300 text-base-content/70 hover:bg-base-200 transition-colors"
            phx-click="add_note"
          >
            <.icon name="hero-chat-bubble-left" class="size-4 mr-2" /> Add note to order
          </button>
        </div>
      </:left_panel>

      <:right_panel>
        <div class="flex flex-col h-full">
          <div class="flex items-center justify-between p-4 border-b border-base-300">
            <h3 class="text-lg font-semibold">Order Summary</h3>
            <button
              type="button"
              class="btn btn-ghost btn-sm btn-circle"
              phx-click="toggle_history"
              title="Transaction History"
            >
              <.icon name="hero-clock" class="size-5" />
            </button>
          </div>

          <div class="flex-1 overflow-y-auto p-4">
            <.order_summary
              items={@state.line_items}
              subtotal={@state.subtotal}
              tax={@state.tax}
              tax_rate={@state.tax_rate}
              total={@state.total}
              can_charge={!Decimal.eq?(@state.total, Decimal.new("0.00"))}
              can_send_link={!Decimal.eq?(@state.total, Decimal.new("0.00"))}
              can_email={
                !Decimal.eq?(@state.total, Decimal.new("0.00")) and @state.customer != nil and
                  @state.customer[:email] != nil
              }
            />
          </div>

          <.pending_payment_status :if={@pending_payment} pending={@pending_payment} />
        </div>
      </:right_panel>
      
    <!-- Drawers and Modals -->
      <.payment_drawer
        show={@show_payment_drawer}
        state={@state}
        card_number={@card_number}
        expiry={@expiry}
        cvv={@cvv}
        zip={@billing_zip}
        save_card={@save_card}
        processing={@processing}
        result={@payment_result}
        on_close="close_payment"
        on_card_change="card_field_change"
        on_submit="process_payment"
        on_new_transaction="new_transaction"
      />

      <.history_drawer
        :if={@show_history_drawer}
        transactions={@transactions}
      />

      <.browse_drawer
        :if={@show_browse_drawer}
        type={@browse_type}
        search={@browse_search}
        category_filter={@browse_category_filter}
        price_filter={@browse_price_filter}
      />

      <.quick_create_modal
        :if={@show_create_modal}
        tab={@create_tab}
        form={@create_form}
        subtotal={@state.subtotal}
      />

      <.send_link_modal
        :if={@show_send_link_modal}
        show={@show_send_link_modal}
        total={@state.total}
        customer={@state.customer}
        expiry_days={@link_expiry_days}
        on_expiry_change="link_expiry_change"
        on_copy="generate_and_copy_link"
        on_send_sms="send_link_sms"
        on_send_email="send_link_email"
      />

      <.email_request_modal
        :if={@show_email_modal}
        show={@show_email_modal}
        state={@state}
        subject={@email_subject}
        message={@email_message}
        include_items={@email_include_items}
        allow_partial={@email_allow_partial}
        due_days={@email_due_days}
        sending={@email_sending}
        sent={@email_sent}
      />

      <.customer_modal
        :if={@show_customer_modal}
        form={@customer_form}
      />

      <.ai_assistant_modal
        show={@show_ai_assistant}
        processing={@ai_processing}
      />

      <.note_modal
        show={@show_note_modal}
        note={@state.note}
      />
    </.focused_layout>
    """
  end

  # Pending Payment Status Helper (Small enough to keep locally or move if desired)
  defp pending_payment_status(assigns) do
    ~H"""
    <div class="p-4 border-t border-base-300">
      <div class="p-3 bg-warning/10 border border-warning/30 rounded-lg">
        <div class="flex items-center justify-between gap-3">
          <div class="flex items-center gap-2 flex-1 min-w-0">
            <div class="w-8 h-8 rounded-full bg-warning/20 flex items-center justify-center flex-shrink-0">
              <%= case @pending.type do %>
                <% :link -> %>
                  <.icon name="hero-link" class="size-4 text-warning" />
                <% :sms -> %>
                  <.icon name="hero-device-phone-mobile" class="size-4 text-warning" />
                <% :link_email -> %>
                  <.icon name="hero-envelope" class="size-4 text-warning" />
                <% :email -> %>
                  <.icon name="hero-envelope" class="size-4 text-warning" />
              <% end %>
            </div>
            <div class="min-w-0">
              <p class="font-medium text-sm truncate">
                <%= case @pending.type do %>
                  <% :link -> %>
                    Payment link copied
                  <% :sms -> %>
                    Payment link sent via SMS to {@pending.recipient}
                  <% :link_email -> %>
                    Payment link sent to {@pending.recipient}
                  <% :email -> %>
                    Payment request sent to {@pending.recipient}
                <% end %>
              </p>
              <p class="text-xs text-base-content/60">
                Expires {Calendar.strftime(@pending.expiry_date, "%b %d")} · Waiting for payment...
              </p>
            </div>
          </div>
          <div class="flex items-center gap-1 flex-shrink-0">
            <%= if @pending.type in [:link, :sms, :link_email] do %>
              <button
                type="button"
                class="btn btn-ghost btn-xs"
                phx-click="copy_link"
                title="Copy link"
              >
                <.icon name="hero-clipboard" class="size-4" />
              </button>
            <% end %>
            <button
              type="button"
              class="btn btn-ghost btn-xs"
              phx-click="cancel_pending_payment"
              title="Cancel"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ===============================================
  # Event Handlers
  # ===============================================

  @impl Phoenix.LiveView
  def handle_event("search", %{"search_query" => query}, socket) do
    # Simulate search
    results = search_items(query)
    ai_interpretation = interpret_natural_language(query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)
     |> assign(:ai_interpretation, ai_interpretation)
     |> assign(:show_search_dropdown, true)}
  end

  def handle_event("show_search_dropdown", _, socket) do
    {:noreply, assign(socket, :show_search_dropdown, true)}
  end

  def handle_event("hide_search_dropdown", _, socket) do
    # Small delay to allow clicks to register
    {:noreply, assign(socket, :show_search_dropdown, false)}
  end

  def handle_event("add_product", %{"id" => id}, socket) do
    product = find_product(id)
    # Default qty 1
    new_state = State.add_product(socket.assigns.state, product, 1)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:search_query, "")
     |> assign(:show_search_dropdown, false)}
  end

  def handle_event("increment", %{"id" => id}, socket) do
    current_item = Enum.find(socket.assigns.state.line_items, &(&1.id == id))

    socket =
      if current_item do
        new_state = State.update_quantity(socket.assigns.state, id, current_item.quantity + 1)
        assign(socket, :state, new_state)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("decrement", %{"id" => id}, socket) do
    current_item = Enum.find(socket.assigns.state.line_items, &(&1.id == id))

    socket =
      if current_item do
        new_state = State.update_quantity(socket.assigns.state, id, current_item.quantity - 1)
        assign(socket, :state, new_state)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("remove_item", %{"id" => id}, socket) do
    new_state = State.remove_item(socket.assigns.state, id)
    {:noreply, assign(socket, :state, new_state)}
  end

  def handle_event("clear_order", _, socket) do
    new_state = State.clear(socket.assigns.state)
    {:noreply, assign(socket, :state, new_state)}
  end

  def handle_event("add_note", _, socket) do
    {:noreply, assign(socket, :show_note_modal, true)}
  end

  def handle_event("close_note_modal", _params, socket) do
    {:noreply, assign(socket, :show_note_modal, false)}
  end

  def handle_event("note_change", %{"value" => value}, socket) do
    {:noreply, assign(socket, :temp_note, value)}
  end

  def handle_event("save_note", %{"note" => note}, socket) do
    new_state = State.set_note(socket.assigns.state, note)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:show_note_modal, false)
     |> put_flash(:info, "Note saved")}
  end

  def handle_event("show_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  def handle_event("close_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  # Payment Drawer Handlers
  def handle_event("card_field_change", %{"field" => field, "value" => value}, socket) do
    socket =
      case field do
        "card_number" -> assign(socket, :card_number, value)
        "expiry" -> assign(socket, :expiry, value)
        "cvv" -> assign(socket, :cvv, value)
        "billing_zip" -> assign(socket, :billing_zip, value)
        _ -> socket
      end

    {:noreply, socket}
  end

  # Allow event to handle keyup from inputs which might send "value"
  def handle_event("card_change", %{"field" => field, "value" => value}, socket) do
    handle_event("card_field_change", %{"field" => field, "value" => value}, socket)
  end

  def handle_event("toggle_save_card", _, socket) do
    {:noreply, assign(socket, :save_card, !socket.assigns.save_card)}
  end

  def handle_event("process_payment", _, socket) do
    # Simulate processing
    Process.send_after(self(), :payment_complete, 2000)
    {:noreply, assign(socket, :processing, true)}
  end

  def handle_event("new_transaction", _, socket) do
    # Reset payment state
    new_state = State.clear(socket.assigns.state)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:payment_result, nil)
     |> assign(:show_payment_drawer, false)
     |> assign(:card_number, "")
     |> assign(:expiry, "")
     |> assign(:cvv, "")}
  end

  # Send Link Handlers
  def handle_event("show_send_link", _, socket) do
    {:noreply, assign(socket, :show_send_link_modal, true)}
  end

  def handle_event("close_send_link", _, socket) do
    {:noreply, assign(socket, :show_send_link_modal, false)}
  end

  def handle_event("link_expiry_change", %{"value" => days}, socket) do
    days_int = String.to_integer(days)
    {:noreply, assign(socket, :link_expiry_days, days_int)}
  end

  def handle_event("generate_and_copy_link", _, socket) do
    # Mock link generation
    expiry = Date.add(Date.utc_today(), socket.assigns.link_expiry_days)

    {:noreply,
     socket
     |> put_flash(:info, "Payment link copied to clipboard")
     |> assign(:show_send_link_modal, false)
     |> assign(:pending_payment, %{type: :link, recipient: nil, expiry_date: expiry})}
  end

  def handle_event("send_link_sms", %{"phone" => phone}, socket) do
    expiry = Date.add(Date.utc_today(), socket.assigns.link_expiry_days)

    {:noreply,
     socket
     |> put_flash(:info, "Payment link sent to #{phone}")
     |> assign(:show_send_link_modal, false)
     |> assign(:pending_payment, %{type: :sms, recipient: phone, expiry_date: expiry})}
  end

  def handle_event("send_link_email", %{"email" => email}, socket) do
    expiry = Date.add(Date.utc_today(), socket.assigns.link_expiry_days)

    {:noreply,
     socket
     |> put_flash(:info, "Payment link sent to #{email}")
     |> assign(:show_send_link_modal, false)
     |> assign(:pending_payment, %{type: :link_email, recipient: email, expiry_date: expiry})}
  end

  def handle_event("cancel_pending_payment", _, socket) do
    {:noreply, assign(socket, :pending_payment, nil)}
  end

  def handle_event("open_browse", %{"type" => type}, socket) do
    type_atom = String.to_existing_atom(type)
    new_state = State.open_browse_drawer(socket.assigns.state, type_atom)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:show_browse_drawer, true)
     |> assign(:browse_type, type_atom)}
  end

  def handle_event("open_payment", _, socket) do
    new_state = State.open_payment_drawer(socket.assigns.state)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:show_payment_drawer, true)}
  end

  def handle_event("close_payment", _, socket) do
    new_state = State.close_payment_drawer(socket.assigns.state)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:show_payment_drawer, false)}
  end

  def handle_event("toggle_history", _, socket) do
    new_state = State.toggle_history_drawer(socket.assigns.state)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:show_history_drawer, !socket.assigns.show_history_drawer)}
  end

  def handle_event("toggle_ai_assistant", _params, socket) do
    {:noreply, assign(socket, :show_ai_assistant, !socket.assigns.show_ai_assistant)}
  end

  def handle_event("ai_submit", %{"prompt" => _prompt}, socket) do
    # Simulate AI processing time then close
    Process.send_after(self(), :ai_simulated_response, 800)
    {:noreply, assign(socket, :ai_processing, true)}
  end

  # Customer simulation
  def handle_event("customer_search", %{"value" => query}, socket) do
    results =
      if String.length(query) > 1 do
        [
          %{id: "cust_1", name: "Sarah Chen", email: "sarah@example.com", phone: "555-123-4567"},
          %{id: "cust_2", name: "John Doe", email: "john@example.com", phone: "555-987-6543"}
        ]
      else
        []
      end

    {:noreply, assign(socket, :customer_results, results)}
  end

  def handle_event("select_customer", %{"id" => id}, socket) do
    customer =
      case id do
        "cust_1" ->
          %{id: "cust_1", name: "Sarah Chen", email: "sarah@example.com", phone: "555-123-4567"}

        "cust_2" ->
          %{id: "cust_2", name: "John Doe", email: "john@example.com", phone: "555-987-6543"}

        _ ->
          nil
      end

    new_state = State.set_customer(socket.assigns.state, customer)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:customer_results, [])
     |> assign(:customer_query, "")}
  end

  def handle_event("clear_customer", _, socket) do
    new_state = State.clear_customer(socket.assigns.state)
    {:noreply, assign(socket, :state, new_state)}
  end

  # AI Handlers
  def handle_event("ai_add_all", _, socket) do
    # Add all interpreted items
    interp = socket.assigns.ai_interpretation
    state = socket.assigns.state

    new_state =
      Enum.reduce(interp.items, state, fn item, acc ->
        product = %{id: item.id, name: item.name, price: item.price, type: :product}
        State.add_product(acc, product, item.quantity)
      end)

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> assign(:search_query, "")
     |> assign(:ai_interpretation, nil)
     |> assign(:show_search_dropdown, false)}
  end

  def handle_event("ai_dismiss", _, socket) do
    {:noreply, assign(socket, :ai_interpretation, nil)}
  end

  def handle_event("add_suggested_product", %{"id" => id}, socket) do
    suggestions = get_product_suggestions(socket.assigns.state.customer)
    product_data = Enum.find(suggestions, &(&1.id == id))

    product = %{
      id: product_data.id,
      name: product_data.name,
      price: product_data.price,
      type: :product
    }

    new_state = State.add_product(socket.assigns.state, product, 1)
    {:noreply, assign(socket, :state, new_state)}
  end

  # Private Helpers (Mock Data)

  defp search_items(query) do
    if String.length(query) > 1 do
      %{
        products: [
          %{id: "p1", name: "Premium Tee", price: Decimal.new("29.99")},
          %{id: "p2", name: "Coffee Mug", price: Decimal.new("12.00")},
          %{id: "p3", name: "Hoodie", price: Decimal.new("49.99")}
        ],
        fees: [
          %{id: "f1", name: "Rush Delivery", amount: Decimal.new("25.00")}
        ],
        discounts: [
          %{id: "d1", name: "Summer Sale", amount: Decimal.new("10"), percent: true}
        ]
      }
    else
      %{products: [], fees: [], discounts: []}
    end
  end

  defp interpret_natural_language(query) do
    # Regex to find "N items" pattern (e.g. "2 burgers", "5 coffees")
    regex = ~r/(\d+)\s+([a-zA-Z\s]+)/

    case Regex.run(regex, query) do
      [_, qty_str, name] ->
        qty = String.to_integer(qty_str)
        # Mock price based on name length to vary it up
        price = Decimal.new("#{String.length(name)}.00")
        total = Decimal.mult(price, qty)

        %{
          items: [
            %{
              id: "ai_#{System.unique_integer()}",
              name: String.trim(name) |> String.capitalize(),
              price: price,
              quantity: qty,
              total: total
            }
          ],
          total: total
        }

      nil ->
        # Fallback for "coffee" legacy check or other keywords
        if String.contains?(String.downcase(query), "combo") do
          %{
            items: [
              %{
                id: "ai_1",
                name: "Premium Burger",
                price: Decimal.new("15.00"),
                quantity: 1,
                total: Decimal.new("15.00")
              },
              %{
                id: "ai_2",
                name: "Fries",
                price: Decimal.new("5.00"),
                quantity: 1,
                total: Decimal.new("5.00")
              },
              %{
                id: "ai_3",
                name: "Soda",
                price: Decimal.new("3.00"),
                quantity: 1,
                total: Decimal.new("3.00")
              }
            ],
            total: Decimal.new("23.00")
          }
        else
          nil
        end
    end
  end

  defp find_product(id) do
    # Mock lookup
    %{id: id, name: "Product #{id}", price: Decimal.new("29.99"), type: :product}
  end

  defp get_product_suggestions(nil), do: []

  defp get_product_suggestions(customer) do
    # Simulated AI suggestions based on customer purchase history
    case customer[:id] do
      "cust_1" ->
        # VIP customer - suggest premium items they've bought before
        [
          %{id: "suggested_1", name: "Premium Widget", price: Decimal.new("89.99")},
          %{id: "suggested_2", name: "Deluxe Bundle", price: Decimal.new("149.99")},
          %{id: "suggested_3", name: "Gold Service Plan", price: Decimal.new("59.99")}
        ]

      "cust_2" ->
        # Regular customer - suggest mid-range items
        [
          %{id: "suggested_4", name: "Standard Widget", price: Decimal.new("29.99")},
          %{id: "suggested_5", name: "Rush Delivery", price: Decimal.new("9.99")}
        ]

      "cust_3" ->
        # New customer - suggest popular starter items
        [
          %{id: "suggested_6", name: "Starter Kit", price: Decimal.new("24.99")},
          %{id: "suggested_7", name: "Setup Fee", price: Decimal.new("50.00")}
        ]

      _ ->
        []
    end
  end

  defp sample_transactions do
    [
      %{
        id: "txn_1",
        customer: "Sarah Chen",
        amount: Decimal.new("107.19"),
        status: :success,
        date: ~N[2026-01-11 15:42:00],
        card_last4: "4242"
      },
      %{
        id: "txn_2",
        customer: "Anonymous",
        amount: Decimal.new("45.00"),
        status: :success,
        date: ~N[2026-01-11 14:15:00],
        card_last4: "8888"
      }
    ]
  end

  @impl Phoenix.LiveView
  def handle_info(:ai_simulated_response, socket) do
    {:noreply,
     socket
     |> assign(:show_ai_assistant, false)
     |> assign(:ai_processing, false)
     |> put_flash(:info, "AI processed your request")}
  end

  @impl Phoenix.LiveView
  def handle_info(:payment_complete, socket) do
    # Mock success
    {:noreply,
     socket
     |> assign(:processing, false)
     |> assign(:payment_result, :success)}
  end
end
