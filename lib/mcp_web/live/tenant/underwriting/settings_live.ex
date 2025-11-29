defmodule McpWeb.Tenant.Underwriting.SettingsLive do
  use McpWeb, :live_view

  alias Mcp.Underwriting.VendorSettings

  def mount(_params, _session, socket) do
    settings = 
      case VendorSettings.get_settings() do
        {:ok, [record | _]} -> record
        {:ok, []} -> 
          # Create default if missing
          VendorSettings.create!(%{preferred_vendor: :comply_cube, circuit_breaker_enabled: true})
        _ -> 
          VendorSettings.create!(%{preferred_vendor: :comply_cube, circuit_breaker_enabled: true})
      end

    form = AshPhoenix.Form.for_update(settings, :update, as: "settings")

    {:ok, assign(socket, settings: settings, form: form)}
  end

  def handle_event("validate", %{"settings" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"settings" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> assign(settings: settings)
         |> put_flash(:info, "Settings updated successfully")
         |> push_navigate(to: ~p"/tenant/underwriting/settings")}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6 text-slate-100">Underwriting Vendor Settings</h1>

      <.form :let={f} for={@form} phx-change="validate" phx-submit="save" class="space-y-6 bg-slate-800 p-6 rounded-lg border border-slate-700">
        
        <div>
          <label class="block text-sm font-medium text-slate-300 mb-2">Preferred Vendor</label>
          <.input type="select" field={f[:preferred_vendor]} options={[{"ComplyCube", :comply_cube}, {"iDenfy", :idenfy}]} class="w-full bg-slate-900 border-slate-700 text-slate-100 rounded-md" />
        </div>

        <div class="flex items-center space-x-3">
          <.input type="checkbox" field={f[:circuit_breaker_enabled]} class="h-4 w-4 rounded border-slate-700 bg-slate-900 text-blue-600 focus:ring-blue-500" />
          <label class="text-sm font-medium text-slate-300">Enable Circuit Breaker</label>
        </div>

        <div class="pt-4">
          <.button type="submit" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded transition-colors">
            Save Settings
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
