defmodule McpWeb.Settings.CustomDomainsLive do
  use McpWeb, :live_view

  alias Mcp.Platform.CustomDomain

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to changes if needed, but for now just load
    end

    {:ok,
     socket
     |> assign(:page_title, "Custom Domains")
     |> assign(:show_add_modal, false)
     |> assign(
       :form,
       to_form(AshPhoenix.Form.for_create(CustomDomain, :create, domain: Mcp.Platform))
     )
     |> refresh_domains()}
  end

  def handle_event("open_modal", _, socket) do
    {:noreply, assign(socket, :show_add_modal, true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_add_modal, false)}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    # Ensure tenant_id is set. We can pass it as hidden input or merge it.
    # Passing as hidden input is safer if form handles it, or merge here.
    # Better: set it in form creation or params.
    # Here we merge it into params just to be sure, or rely on hidden input.
    # We'll merge it in arguments using `actor`? No, tenant_id is attribute.

    tenant_id = socket.assigns.current_tenant.id
    params = Map.merge(params, %{"tenant_id" => tenant_id})

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, _domain} ->
        {:noreply,
         socket
         |> put_flash(:info, "Domain added. Please verify DNS.")
         |> assign(:show_add_modal, false)
         |> assign(
           :form,
           to_form(AshPhoenix.Form.for_create(CustomDomain, :create, domain: Mcp.Platform))
         )
         |> refresh_domains()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("verify", %{"id" => id}, socket) do
    domain = Ash.get!(CustomDomain, id, actor: socket.assigns.current_user)

    case Ash.Changeset.for_update(domain, :verify)
         |> Ash.update(actor: socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Domain verified successfully!")
         |> refresh_domains()}

      {:error, error} ->
        msg =
          case error do
            %Ash.Error.Unknown{errors: [err]} -> Exception.message(err)
            _ -> "Verification failed."
          end

        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    domain = Ash.get!(CustomDomain, id, actor: socket.assigns.current_user)
    Ash.destroy!(domain, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, "Domain removed.")
     |> refresh_domains()}
  end

  defp refresh_domains(socket) do
    tenant_id = socket.assigns.current_tenant.id
    require Ash.Query

    {:ok, domains} =
      CustomDomain
      |> Ash.Query.filter(tenant_id == ^tenant_id)
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.read(domain: Mcp.Platform, actor: socket.assigns.current_user)

    assign(socket, :domains, domains)
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl py-8">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Custom Domains</h1>
        <button
          phx-click="open_modal"
          class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
        >
          Add Domain
        </button>
      </div>

      <div class="bg-white shadow rounded-lg overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Domain
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                DNS Record
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for domain <- @domains do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {domain.domain}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full " <> status_color(domain.state)}>
                    {domain.state}
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">
                  <%= if domain.state == :pending_verification do %>
                    <div class="flex flex-col space-y-1">
                      <code class="text-xs bg-gray-100 p-1 rounded">
                        TXT {domain.verification_record_name}.{domain.domain}
                      </code>
                      <code class="text-xs bg-gray-100 p-1 roundedselect-all">
                        {domain.verification_record_value}
                      </code>
                    </div>
                  <% else %>
                    <span class="text-green-600">Verified</span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-2">
                  <%= if domain.state == :pending_verification do %>
                    <button
                      phx-click="verify"
                      phx-value-id={domain.id}
                      class="text-blue-600 hover:text-blue-900"
                    >
                      Verify
                    </button>
                  <% end %>
                  <button
                    phx-click="delete"
                    phx-value-id={domain.id}
                    data-confirm="Are you sure?"
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            <% end %>
            <%= if Enum.empty?(@domains) do %>
              <tr>
                <td colspan="4" class="px-6 py-8 text-center text-gray-500">
                  No custom domains configured.
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @show_add_modal do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg p-6 max-w-lg w-full shadow-xl">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Add Custom Domain</h3>

            <.form for={@form} phx-change="validate" phx-submit="save">
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-700">Domain Name</label>
                <input
                  type="text"
                  name="form[domain]"
                  value={@form[:domain].value}
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                  placeholder="app.example.com"
                />
                <%= if @form[:domain].errors do %>
                  <p class="text-red-600 text-xs mt-1">
                    {Enum.map(@form[:domain].errors, &elem(&1, 0)) |> Enum.join(", ")}
                  </p>
                <% end %>
              </div>

              <div class="flex justify-end space-x-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
                >
                  Add Domain
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_color(:pending_verification), do: "bg-yellow-100 text-yellow-800"
  defp status_color(:verified), do: "bg-green-100 text-green-800"
  defp status_color(:active), do: "bg-blue-100 text-blue-800"
  defp status_color(:failed), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"
end
