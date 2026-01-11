defmodule McpWeb.Components.Terminal.CustomerModal do
  @moduledoc """
  Quick-create modal for adding new customers directly from the terminal.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1]

  attr :show, :boolean, default: false
  attr :name, :string, default: ""
  attr :email, :string, default: ""
  attr :form, :map, default: %{}
  attr :phone, :string, default: ""
  attr :save_to_crm, :boolean, default: true
  attr :errors, :map, default: %{}
  attr :on_field_change, :string, default: "customer_field_change"
  attr :on_submit, :string, default: "create_customer"
  attr :on_cancel, :string, default: "close_customer_modal"

  def customer_modal(assigns) do
    ~H"""
    <.modal id="customer-modal" show={@show} on_cancel={@on_cancel}>
      <:title>Add Customer</:title>

      <div class="space-y-4">
        <div class="form-control">
          <label class="label"><span class="label-text">Name *</span></label>
          <input
            type="text"
            placeholder="Customer name"
            class={["input input-bordered", @errors[:name] && "input-error"]}
            value={@name}
            phx-keyup={@on_field_change}
            phx-value-field="name"
            autocomplete="name"
          />
          <label :if={@errors[:name]} class="label">
            <span class="label-text-alt text-error">{@errors[:name]}</span>
          </label>
        </div>

        <div class="form-control">
          <label class="label"><span class="label-text">Email</span></label>
          <label class="input input-bordered flex items-center gap-2">
            <.icon name="hero-envelope" class="size-4 opacity-50" />
            <input
              type="email"
              placeholder="customer@example.com"
              class="grow border-none focus:ring-0"
              value={@email}
              phx-keyup={@on_field_change}
              phx-value-field="email"
              autocomplete="email"
            />
          </label>
        </div>

        <div class="form-control">
          <label class="label"><span class="label-text">Phone</span></label>
          <label class="input input-bordered flex items-center gap-2">
            <.icon name="hero-phone" class="size-4 opacity-50" />
            <input
              type="tel"
              placeholder="(555) 123-4567"
              class="grow border-none focus:ring-0"
              value={@phone}
              phx-keyup={@on_field_change}
              phx-value-field="phone"
              autocomplete="tel"
              inputmode="tel"
            />
          </label>
        </div>
      </div>

      <:cancel_text>Cancel</:cancel_text>
      <:confirm_text>
        <button type="button" class="btn btn-primary" phx-click={@on_submit} disabled={@name == ""}>
          <.icon name="hero-user-plus" class="size-4" /> Add Customer
        </button>
      </:confirm_text>
    </.modal>
    """
  end
end
