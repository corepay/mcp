defmodule McpWeb.Components.Terminal.SendLinkModal do
  @moduledoc """
  Modal for generating and sending payment links.

  Per spec:
  - Shows amount due at top
  - Copy Link as primary action
  - "or send directly" divider
  - SMS option (if customer has phone)
  - Email option (if customer has email)
  - Link expires dropdown at bottom
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1]

  attr :show, :boolean, default: false
  attr :total, :any, required: true
  attr :customer, :map, default: nil
  attr :expiry_days, :integer, default: 7
  attr :on_expiry_change, :string, default: "link_expiry_change"
  attr :on_copy, :string, default: "generate_and_copy_link"
  attr :on_send_sms, :string, default: "send_link_sms"
  attr :on_send_email, :string, default: "send_link_email"
  attr :on_cancel, :string, default: "close_send_link"

  def send_link_modal(assigns) do
    has_phone = assigns.customer && assigns.customer[:phone]
    has_email = assigns.customer && assigns.customer[:email]
    has_direct_options = has_phone || has_email

    assigns =
      assigns
      |> assign(:has_phone, has_phone)
      |> assign(:has_email, has_email)
      |> assign(:has_direct_options, has_direct_options)

    ~H"""
    <.modal id="send-link-modal" show={@show} on_cancel={@on_cancel}>
      <:title>Send Payment Link</:title>

      <div class="space-y-4">
        <%!-- Amount due --%>
        <div class="text-center py-4">
          <p class="text-3xl font-bold">{format_amount(@total)}</p>
          <p class="text-sm text-base-content/70 mt-1">due</p>
        </div>

        <%!-- Copy Link - Primary action --%>
        <button
          type="button"
          class="btn btn-outline btn-block gap-2"
          phx-click={@on_copy}
        >
          <.icon name="hero-clipboard-document" class="size-5" /> Copy Link
        </button>

        <%!-- Direct send options --%>
        <%= if @has_direct_options do %>
          <div class="divider text-xs text-base-content/50">or send directly</div>

          <%= if @has_phone do %>
            <button
              type="button"
              class="btn btn-outline btn-block gap-2 justify-start"
              phx-click={@on_send_sms}
            >
              <.icon name="hero-device-phone-mobile" class="size-5" />
              <span class="flex-1 text-left">SMS to {@customer[:phone]}</span>
            </button>
          <% end %>

          <%= if @has_email do %>
            <button
              type="button"
              class="btn btn-outline btn-block gap-2 justify-start"
              phx-click={@on_send_email}
            >
              <.icon name="hero-envelope" class="size-5" />
              <span class="flex-1 text-left">Email to {@customer[:email]}</span>
            </button>
          <% end %>
        <% end %>

        <%!-- Link expiry dropdown --%>
        <div class="form-control pt-2">
          <label class="label">
            <span class="label-text text-base-content/70">Link expires in</span>
          </label>
          <select
            class="select select-bordered select-sm w-full"
            phx-change={@on_expiry_change}
            name="expiry_days"
          >
            <option value="7" selected={@expiry_days == 7}>7 days</option>
            <option value="14" selected={@expiry_days == 14}>14 days</option>
            <option value="30" selected={@expiry_days == 30}>30 days</option>
          </select>
        </div>
      </div>

      <:cancel_text>Close</:cancel_text>
      <:confirm_text></:confirm_text>
    </.modal>
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
