defmodule McpWeb.Settings.WebhooksLive do
  use McpWeb, :live_view
  require Ash.Query

  alias Mcp.Communication.WebhookEndpoint

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Webhooks")
     |> assign(:modal_open, false)
     |> assign(:form, nil)
     |> refresh_endpoints()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    form =
      WebhookEndpoint
      |> AshPhoenix.Form.for_create(:create,
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_tenant
      )
      |> to_form()

    {:noreply,
     socket
     |> assign(:modal_open, true)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :modal_open, false)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _endpoint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Webhook endpoint created successfully.")
         |> assign(:modal_open, false)
         |> refresh_endpoints()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    WebhookEndpoint
    |> Ash.get!(id, actor: socket.assigns.current_user)
    |> Ash.destroy!(actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, "Webhook endpoint deleted.")
     |> refresh_endpoints()}
  end

  defp refresh_endpoints(socket) do
    tenant_id = socket.assigns.current_tenant.id

    endpoints =
      WebhookEndpoint
      |> Ash.Query.filter(tenant_id == ^tenant_id)
      |> Ash.read!(actor: socket.assigns.current_user)

    assign(socket, :endpoints, endpoints)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold text-base-content">Webhooks</h1>
          <p class="text-base-content/70">Manage webhook endpoints for event notifications.</p>
        </div>
        <button phx-click="open_modal" class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Add Endpoint
        </button>
      </div>

      <div class="overflow-x-auto bg-base-100 rounded-lg border border-base-200">
        <table class="table w-full">
          <thead>
            <tr>
              <th>URL</th>
              <th>Events</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for endpoint <- @endpoints do %>
              <tr>
                <td class="font-mono text-sm">{endpoint.url}</td>
                <td>
                  <div class="flex flex-wrap gap-1">
                    <%= for event <- endpoint.events || [] do %>
                      <span class="badge badge-sm badge-ghost">{event}</span>
                    <% end %>
                  </div>
                </td>
                <td>
                  <%= if endpoint.enabled do %>
                    <span class="badge badge-success">Enabled</span>
                  <% else %>
                    <span class="badge badge-warning">Disabled</span>
                  <% end %>
                </td>
                <td>{Calendar.strftime(endpoint.inserted_at, "%Y-%m-%d")}</td>
                <td>
                  <button
                    phx-click="delete"
                    phx-value-id={endpoint.id}
                    data-confirm="Are you sure?"
                    class="btn btn-ghost btn-xs text-error"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            <% end %>
            <%= if Enum.empty?(@endpoints) do %>
              <tr>
                <td colspan="5" class="text-center py-8 text-base-content/50">
                  No webhook endpoints configured.
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @modal_open do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Add Webhook Endpoint</h3>

            <.form :let={f} for={@form} phx-change="validate" phx-submit="save">
              <div class="form-control w-full mb-4">
                <label class="label"><span class="label-text">Description</span></label>
                <input
                  type="text"
                  name={f[:description].name}
                  value={f[:description].value}
                  class="input input-bordered w-full"
                  placeholder="e.g. Production API"
                />
                <%= if f[:description].errors do %>
                  <p class="text-error text-xs mt-1">
                    {Enum.map(f[:description].errors, &elem(&1, 0)) |> Enum.join(", ")}
                  </p>
                <% end %>
              </div>

              <div class="form-control w-full mb-4">
                <label class="label"><span class="label-text">Target URL</span></label>
                <input
                  type="text"
                  name={f[:url].name}
                  value={f[:url].value}
                  class="input input-bordered w-full"
                  placeholder="https://api.example.com/webhooks"
                />
                <%= if f[:url].errors do %>
                  <p class="text-error text-xs mt-1">
                    {Enum.map(f[:url].errors, &elem(&1, 0)) |> Enum.join(", ")}
                  </p>
                <% end %>
              </div>

              <div class="form-control w-full mb-4">
                <label class="label"><span class="label-text">Events</span></label>
                <div class="flex gap-2">
                  <select name={f[:events].name} multiple class="select select-bordered w-full h-32">
                    <%= for event <- ["document.processed", "underwriting.completed", "billing.charged"] do %>
                      <option value={event} selected={event in (f[:events].value || [])}>
                        {event}
                      </option>
                    <% end %>
                  </select>
                </div>
                <%= if f[:events].errors do %>
                  <p class="text-error text-xs mt-1">
                    {Enum.map(f[:events].errors, &elem(&1, 0)) |> Enum.join(", ")}
                  </p>
                <% end %>
              </div>

              <div class="form-control w-full mb-4">
                <label class="cursor-pointer label justify-start gap-4">
                  <span class="label-text">Enabled</span>
                  <input
                    type="checkbox"
                    name={f[:enabled].name}
                    checked={f[:enabled].value}
                    class="toggle toggle-primary"
                  />
                </label>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="close_modal" class="btn btn-ghost">Cancel</button>
                <button type="submit" class="btn btn-primary" disabled={!@form.source.valid?}>
                  Save
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
