defmodule McpWeb.Tenant.Underwriting.Components.RequestInfoModal do
  use McpWeb, :live_component

  def render(assigns) do
    ~H"""
    <div id={@id} class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm" phx-window-keydown="close" phx-key="escape" phx-target={@myself}>
      <div class="bg-base-100 rounded-lg shadow-xl w-full max-w-lg mx-4 overflow-hidden">
        <div class="px-6 py-4 border-b border-base-200 flex justify-between items-center">
          <h3 class="text-lg font-bold">Request More Information</h3>
          <button phx-click="close" phx-target={@myself} class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>
        
        <div class="p-6">
          <form phx-submit="save" phx-target={@myself}>
            <div class="form-control mb-4">
              <label class="label">
                <span class="label-text">Document Type (Optional)</span>
              </label>
              <select name="document_type" class="select select-bordered w-full">
                <option value="">-- Select Document Type --</option>
                <option value="identity">Identity Document (Passport/DL)</option>
                <option value="business_registration">Business Registration</option>
                <option value="bank_statement">Bank Statement</option>
                <option value="proof_of_address">Proof of Address</option>
                <option value="tax_return">Tax Return</option>
                <option value="other">Other</option>
              </select>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Reason for request</span>
              </label>
              <textarea 
                name="reason" 
                class="textarea textarea-bordered h-32" 
                placeholder="Please explain what information is missing or needs clarification..."
                required
              ></textarea>
              <label class="label">
                <span class="label-text-alt text-zinc-500">This will be logged to the activity timeline.</span>
              </label>
            </div>
            
            <div class="modal-action mt-6">
              <button type="button" phx-click="close" phx-target={@myself} class="btn btn-ghost">Cancel</button>
              <button type="submit" class="btn btn-warning">Request Info</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("close", _, socket) do
    send(self(), :close_modal)
    {:noreply, socket}
  end

  def handle_event("save", %{"reason" => reason, "document_type" => document_type}, socket) do
    send(self(), {:confirm_request_info, reason, document_type})
    {:noreply, socket}
  end
end
