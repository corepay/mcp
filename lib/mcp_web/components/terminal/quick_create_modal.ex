defmodule McpWeb.Components.Terminal.QuickCreateModal do
  @moduledoc """
  Quick-create modal for adding custom line items (products, fees, discounts, tips).
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1]

  attr :show, :boolean, default: false
  attr :active_tab, :atom, default: :product
  attr :name, :string, default: ""
  attr :amount, :string, default: ""
  attr :tab, :atom, default: :product
  attr :form, :map, default: %{}
  attr :subtotal, :any, default: Decimal.new("0.00")
  attr :is_percent, :boolean, default: false
  attr :save_to_catalog, :boolean, default: false
  attr :on_tab_change, :string, default: "create_tab_change"
  attr :on_field_change, :string, default: "create_field_change"
  attr :on_submit, :string, default: "create_item"
  attr :on_cancel, :string, default: "close_create"

  def quick_create_modal(assigns) do
    ~H"""
    <.modal id="quick-create-modal" show={@show} on_cancel={@on_cancel}>
      <:title>Add Line Item</:title>

      <div class="tabs tabs-boxed mb-4">
        <button
          :for={tab <- [:product, :fee, :discount, :tip]}
          type="button"
          class={["tab", @active_tab == tab && "tab-active"]}
          phx-click={@on_tab_change}
          phx-value-tab={tab}
        >
          {tab_label(tab)}
        </button>
      </div>

      <.tab_content
        tab={@active_tab}
        name={@name}
        amount={@amount}
        is_percent={@is_percent}
        save_to_catalog={@save_to_catalog}
        on_field_change={@on_field_change}
      />

      <:cancel_text>Cancel</:cancel_text>
      <:confirm_text>
        <button
          type="button"
          class="btn btn-primary"
          phx-click={@on_submit}
          disabled={@name == "" or @amount == ""}
        >
          Add to Order
        </button>
      </:confirm_text>
    </.modal>
    """
  end

  defp tab_content(%{tab: :product} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label"><span class="label-text">Name *</span></label>
        <input
          type="text"
          placeholder="Product name"
          class="input input-bordered"
          value={@name}
          phx-keyup={@on_field_change}
          phx-value-field="name"
        />
      </div>

      <div class="form-control">
        <label class="label"><span class="label-text">Price *</span></label>
        <label class="input input-bordered flex items-center gap-2">
          <span class="text-base-content/50">$</span>
          <input
            type="text"
            placeholder="0.00"
            class="grow border-none focus:ring-0"
            value={@amount}
            phx-keyup={@on_field_change}
            phx-value-field="amount"
            inputmode="decimal"
          />
        </label>
      </div>

      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <input
            type="checkbox"
            class="checkbox checkbox-primary"
            checked={@save_to_catalog}
            phx-click={@on_field_change}
            phx-value-field="save_to_catalog"
            phx-value-value={!@save_to_catalog}
          />
          <span class="label-text">Save to product catalog</span>
        </label>
      </div>
    </div>
    """
  end

  defp tab_content(%{tab: :fee} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label"><span class="label-text">Name *</span></label>
        <input
          type="text"
          placeholder="Fee name"
          class="input input-bordered"
          value={@name}
          phx-keyup={@on_field_change}
          phx-value-field="name"
        />
      </div>

      <div class="form-control">
        <label class="label"><span class="label-text">Amount *</span></label>
        <div class="join w-full">
          <label class="input input-bordered flex items-center gap-2 join-item flex-1">
            <span class="text-base-content/50">{if @is_percent, do: "%", else: "$"}</span>
            <input
              type="text"
              placeholder="0.00"
              class="grow border-none focus:ring-0"
              value={@amount}
              phx-keyup={@on_field_change}
              phx-value-field="amount"
              inputmode="decimal"
            />
          </label>
          <button
            type="button"
            class={["btn join-item", !@is_percent && "btn-active"]}
            phx-click={@on_field_change}
            phx-value-field="is_percent"
            phx-value-value="false"
          >
            Fixed $
          </button>
          <button
            type="button"
            class={["btn join-item", @is_percent && "btn-active"]}
            phx-click={@on_field_change}
            phx-value-field="is_percent"
            phx-value-value="true"
          >
            Percent %
          </button>
        </div>
      </div>

      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <input
            type="checkbox"
            class="checkbox checkbox-primary"
            checked={@save_to_catalog}
            phx-click={@on_field_change}
            phx-value-field="save_to_catalog"
            phx-value-value={!@save_to_catalog}
          />
          <span class="label-text">Save to fee catalog</span>
        </label>
      </div>
    </div>
    """
  end

  defp tab_content(%{tab: :discount} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label"><span class="label-text">Name *</span></label>
        <input
          type="text"
          placeholder="Discount name"
          class="input input-bordered"
          value={@name}
          phx-keyup={@on_field_change}
          phx-value-field="name"
        />
      </div>

      <div class="form-control">
        <label class="label"><span class="label-text">Amount *</span></label>
        <div class="join w-full">
          <label class="input input-bordered flex items-center gap-2 join-item flex-1">
            <span class="text-base-content/50">{if @is_percent, do: "%", else: "$"}</span>
            <input
              type="text"
              placeholder="0.00"
              class="grow border-none focus:ring-0"
              value={@amount}
              phx-keyup={@on_field_change}
              phx-value-field="amount"
              inputmode="decimal"
            />
          </label>
          <button
            type="button"
            class={["btn join-item", !@is_percent && "btn-active"]}
            phx-click={@on_field_change}
            phx-value-field="is_percent"
            phx-value-value="false"
          >
            Fixed $
          </button>
          <button
            type="button"
            class={["btn join-item", @is_percent && "btn-active"]}
            phx-click={@on_field_change}
            phx-value-field="is_percent"
            phx-value-value="true"
          >
            Percent %
          </button>
        </div>
      </div>

      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <input
            type="checkbox"
            class="checkbox checkbox-primary"
            checked={@save_to_catalog}
            phx-click={@on_field_change}
            phx-value-field="save_to_catalog"
            phx-value-value={!@save_to_catalog}
          />
          <span class="label-text">Save to discount catalog</span>
        </label>
      </div>
    </div>
    """
  end

  defp tab_content(%{tab: :tip} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label"><span class="label-text">Tip Amount *</span></label>
        <label class="input input-bordered flex items-center gap-2">
          <span class="text-base-content/50">$</span>
          <input
            type="text"
            placeholder="0.00"
            class="grow border-none focus:ring-0"
            value={@amount}
            phx-keyup={@on_field_change}
            phx-value-field="amount"
            inputmode="decimal"
          />
        </label>
      </div>

      <div class="flex gap-2">
        <button
          :for={pct <- [15, 18, 20, 25]}
          type="button"
          class="btn btn-outline flex-1"
          phx-click={@on_field_change}
          phx-value-field="tip_percent"
          phx-value-value={pct}
        >
          {pct}%
        </button>
      </div>

      <p class="text-sm text-base-content/50">
        <.icon name="hero-information-circle" class="size-4 inline" /> Tips are not saved to catalog
      </p>
    </div>
    """
  end

  defp tab_label(:product), do: "Product"
  defp tab_label(:fee), do: "Fee"
  defp tab_label(:discount), do: "Discount"
  defp tab_label(:tip), do: "Tip"
end
