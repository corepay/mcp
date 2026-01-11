defmodule McpWeb.Components.Terminal.EmailRequestModal do
  @moduledoc """
  Modal for sending payment request via email.

  Full form per spec:
  - To: customer email (read-only)
  - Subject: editable with default
  - Message: optional textarea
  - Include itemized order details checkbox
  - Allow partial payments checkbox
  - Payment due in dropdown
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1]

  attr :show, :boolean, default: false
  attr :state, :map, required: true
  attr :subject, :string, default: ""
  attr :message, :string, default: ""
  attr :include_items, :boolean, default: true
  attr :allow_partial, :boolean, default: false
  attr :due_days, :integer, default: 7
  attr :sending, :boolean, default: false
  attr :sent, :boolean, default: false
  attr :on_field_change, :string, default: "email_field_change"
  attr :on_send, :string, default: "send_email_request"
  attr :on_cancel, :string, default: "close_email"

  def email_request_modal(assigns) do
    ~H"""
    <.modal id="email-request-modal" show={@show} on_cancel={@on_cancel}>
      <:title>Email Payment Request</:title>

      <%= cond do %>
        <% @sent -> %>
          <.email_sent customer={@state.customer} />
        <% @sending -> %>
          <.email_sending />
        <% true -> %>
          <.email_form
            state={@state}
            subject={@subject}
            message={@message}
            include_items={@include_items}
            allow_partial={@allow_partial}
            due_days={@due_days}
            on_field_change={@on_field_change}
            on_send={@on_send}
          />
      <% end %>

      <:cancel_text>{if @sent, do: "Done", else: "Cancel"}</:cancel_text>
      <:confirm_text></:confirm_text>
    </.modal>
    """
  end

  defp email_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <%!-- To Field (read-only) --%>
      <div class="form-control">
        <label class="label"><span class="label-text">To</span></label>
        <input
          type="email"
          class="input input-bordered bg-base-200"
          value={@state.customer[:email]}
          readonly
        />
      </div>

      <%!-- Subject Field --%>
      <div class="form-control">
        <label class="label"><span class="label-text">Subject</span></label>
        <input
          type="text"
          class="input input-bordered"
          value={@subject}
          placeholder="Payment request from Your Store"
          phx-keyup={@on_field_change}
          phx-value-field="subject"
        />
      </div>

      <%!-- Message Field (optional) --%>
      <div class="form-control">
        <label class="label"><span class="label-text">Message (optional)</span></label>
        <textarea
          class="textarea textarea-bordered h-24"
          placeholder="Add a personal message..."
          phx-keyup={@on_field_change}
          phx-value-field="message"
        >{@message}</textarea>
      </div>

      <%!-- Include Items Checkbox --%>
      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <input
            type="checkbox"
            class="checkbox checkbox-primary"
            checked={@include_items}
            phx-click={@on_field_change}
            phx-value-field="include_items"
            phx-value-value={!@include_items}
          />
          <span class="label-text">Include itemized order details</span>
        </label>
      </div>

      <%!-- Allow Partial Payments Checkbox --%>
      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <input
            type="checkbox"
            class="checkbox checkbox-primary"
            checked={@allow_partial}
            phx-click={@on_field_change}
            phx-value-field="allow_partial"
            phx-value-value={!@allow_partial}
          />
          <span class="label-text">Allow partial payments</span>
        </label>
      </div>

      <%!-- Payment Due In Dropdown --%>
      <div class="form-control">
        <label class="label"><span class="label-text">Payment due in</span></label>
        <select
          class="select select-bordered w-full"
          phx-change={@on_field_change}
          name="due_days"
        >
          <option value="7" selected={@due_days == 7}>7 days</option>
          <option value="14" selected={@due_days == 14}>14 days</option>
          <option value="30" selected={@due_days == 30}>30 days</option>
          <option value="60" selected={@due_days == 60}>60 days</option>
        </select>
      </div>

      <%!-- Amount Summary --%>
      <div class="bg-base-200 rounded-lg p-4 text-center">
        <p class="text-sm text-base-content/70 mb-1">Amount Due</p>
        <p class="text-2xl font-bold">{format_amount(@state.total)}</p>
      </div>

      <%!-- Send Button --%>
      <button type="button" class="btn btn-primary btn-block gap-2" phx-click={@on_send}>
        <.icon name="hero-paper-airplane" class="size-5" /> Send Payment Request
      </button>
    </div>
    """
  end

  defp email_sending(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-8">
      <div class="loading loading-spinner loading-lg text-primary mb-4"></div>
      <p class="font-medium">Sending email...</p>
    </div>
    """
  end

  defp email_sent(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-8">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-success/20 mb-4">
        <.icon name="hero-check" class="size-8 text-success" />
      </div>
      <h3 class="text-xl font-semibold mb-2">Email Sent!</h3>
      <p class="text-base-content/70 text-center">
        Payment request sent to<br />
        <span class="font-medium">{@customer[:email]}</span>
      </p>
    </div>
    """
  end

  defp format_amount(amount) do
    sign = if Decimal.negative?(amount), do: "-", else: ""
    abs_amount = Decimal.abs(amount)

    formatted =
      abs_amount
      |> Decimal.to_string(:normal)
      |> String.split(".")
      |> case do
        [dollars] ->
          "#{dollars}.00"

        [dollars, cents] ->
          "#{dollars}.#{String.pad_trailing(cents, 2, "0") |> String.slice(0, 2)}"
      end

    "#{sign}$#{formatted}"
  end
end
