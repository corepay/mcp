defmodule McpWeb.Settings.ApiKeysLive do
  use McpWeb, :live_view

  alias Mcp.Platform.ApiKey

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "API Keys")
     |> assign(:new_key, nil)
     |> assign(:confirm_revoke, nil)
     |> refresh_keys()}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  def handle_event("create_key", %{"scope" => _scope}, socket) do
    # For now, default to creating a standard key. Scope handling can be added later or via form.
    # We use the current tenant as the owner.
    tenant_id = socket.assigns.current_tenant.id

    case ApiKey.create(%{
           prefix: "mcp_live",
           type: :merchant,
           owner_id: tenant_id,
           owner_type: :tenant,
           scopes: ["full_access"]
         }) do
      {:ok, api_key} ->
        {:noreply,
         socket
         # This key has the virtual `raw_key` attribute
         |> assign(:new_key, api_key)
         |> put_flash(:info, "API Key created successfully.")
         |> refresh_keys()}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("confirm_revoke", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirm_revoke, id)}
  end

  def handle_event("cancel_revoke", _, socket) do
    {:noreply, assign(socket, :confirm_revoke, nil)}
  end

  def handle_event("revoke_key", %{"id" => id}, socket) do
    key = Ash.get!(ApiKey, id)

    case ApiKey.revoke(key) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:confirm_revoke, nil)
         |> put_flash(:info, "API Key revoked.")
         |> refresh_keys()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke key.")}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :new_key, nil)}
  end

  defp refresh_keys(socket) do
    tenant_id = socket.assigns.current_tenant.id
    require Ash.Query

    {:ok, keys} =
      ApiKey
      |> Ash.Query.filter(owner_id == ^tenant_id and is_nil(revoked_at))
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.read(domain: Mcp.Platform)

    assign(socket, :api_keys, keys)
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl py-8">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">API Keys</h1>
        <button
          phx-click="create_key"
          phx-value-scope="full"
          class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
        >
          Create New Key
        </button>
      </div>

      <div class="bg-white shadow rounded-lg overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Prefix
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Created
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Last Used
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for key <- @api_keys do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  <span class="font-mono bg-gray-100 px-2 py-1 rounded">{key.prefix}_...</span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {Calendar.strftime(key.inserted_at, "%Y-%m-%d %H:%M")}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {if key.last_used_at,
                    do: Calendar.strftime(key.last_used_at, "%Y-%m-%d %H:%M"),
                    else: "Never"}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <%= if @confirm_revoke == key.id do %>
                    <span class="text-red-600 mr-2">Are you sure?</span>
                    <button
                      phx-click="revoke_key"
                      phx-value-id={key.id}
                      class="text-red-600 hover:text-red-900 font-bold"
                    >
                      Yes, Revoke
                    </button>
                    <button phx-click="cancel_revoke" class="text-gray-600 hover:text-gray-900 ml-2">
                      Cancel
                    </button>
                  <% else %>
                    <button
                      phx-click="confirm_revoke"
                      phx-value-id={key.id}
                      class="text-red-600 hover:text-red-900"
                    >
                      Revoke
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
            <%= if Enum.empty?(@api_keys) do %>
              <tr>
                <td colspan="4" class="px-6 py-8 text-center text-gray-500">
                  No active API keys found. Create one to get started.
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @new_key do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg p-6 max-w-lg w-full shadow-xl">
            <h3 class="text-lg font-medium text-gray-900 mb-2">API Key Created</h3>
            <p class="text-sm text-gray-500 mb-4">
              This is the only time you will see this key. Please copy it and store it somewhere safe.
            </p>

            <div class="bg-gray-100 p-3 rounded-md font-mono text-sm break-all mb-4 border border-gray-200">
              {@new_key.__metadata__.raw_key}
            </div>

            <div class="flex justify-end">
              <button
                phx-click="close_modal"
                class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
              >
                I have copied it
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
