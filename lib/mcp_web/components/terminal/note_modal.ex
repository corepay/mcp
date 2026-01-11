defmodule McpWeb.Components.Terminal.NoteModal do
  @moduledoc """
  Modal for adding or editing an internal note on the order.
  """
  use Phoenix.Component
  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1]

  attr :show, :boolean, default: false
  attr :note, :string, default: ""
  attr :on_change, :string, default: "note_change"
  attr :on_save, :string, default: "save_note"
  attr :on_cancel, :string, default: "close_note_modal"

  def note_modal(assigns) do
    ~H"""
    <.modal id="note-modal" show={@show} on_cancel={@on_cancel}>
      <:title>Order Note</:title>

      <div class="space-y-4">
        <p class="text-sm text-base-content/70">
          Add an internal note to this order. This will not be visible to the customer.
        </p>

        <form phx-submit={@on_save}>
          <div class="form-control">
            <textarea
              name="note"
              class="textarea textarea-bordered h-32 text-base"
              placeholder="e.g. Customer requested gift receipt..."
              phx-keyup={@on_change}
              phx-value-field="note"
              autofocus
            >{@note}</textarea>
          </div>
        </form>
      </div>

      <:cancel_text>Cancel</:cancel_text>
      <:confirm_text>
        <button type="button" class="btn btn-primary" phx-click={@on_save}>
          <.icon name="hero-document-text" class="size-4" /> Save Note
        </button>
      </:confirm_text>
    </.modal>
    """
  end
end
