defmodule McpWeb.TenantSettingsLive do
  @moduledoc """
  LiveView for interactive tenant settings management.
  """

  use McpWeb, :live_view

  alias Mcp.Platform.{FeatureToggle, TenantSettingsManager}

  def __live__ do
    %{
      layouts: [
        {McpWeb.Layouts, :app}
      ],
      container: {:div, class: "flex-1"}
    }
  end

  @impl true
  def mount(%{"tenant_schema" => tenant_schema} = _params, _session, socket) do
    if connected?(socket) do
      current_user = socket.assigns.current_user
      tenant_id = socket.assigns.current_tenant.id

      # Load initial data
      {:ok, settings} = TenantSettingsManager.get_all_tenant_settings(tenant_id)
      {:ok, enabled_features} = TenantSettingsManager.get_enabled_features(tenant_id)
      {:ok, branding} = TenantSettingsManager.get_tenant_branding(tenant_id)

      socket =
        socket
        |> assign(:tenant_schema, tenant_schema)
        |> assign(:current_user, current_user)
        |> assign(:tenant_id, tenant_id)
        |> assign(:settings, settings)
        |> assign(:enabled_features, enabled_features)
        |> assign(:branding, branding)
        |> assign(:categories, get_setting_categories())
        |> assign(:active_tab, "general")
        |> assign(:form_changes, %{})
        |> assign(:loading, false)
        |> assign(:feature_definitions, FeatureToggle.feature_definitions())

      {:ok, socket}
    else
      socket =
        socket
        |> assign(:tenant_schema, tenant_schema)
        |> assign(:active_tab, "general")

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    active_tab = Map.get(params, "tab", "general")
    {:noreply, assign(socket, :active_tab, active_tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <McpWeb.Core.CoreComponents.header>
        Tenant Settings
        <:subtitle>Manage your ISP platform configuration and preferences</:subtitle>
      </McpWeb.Core.CoreComponents.header>
      
    <!-- Tab Navigation -->
      <div class="border-b border-gray-200 mb-8">
        <nav class="-mb-px flex space-x-8">
          <.tab
            active={@active_tab == "general"}
            patch={~p"/tenant/settings?tab=general"}
          >
            General
          </.tab>
          <.tab
            active={@active_tab == "business"}
            patch={~p"/tenant/settings?tab=business"}
          >
            Business Info
          </.tab>
          <.tab
            active={@active_tab == "features"}
            patch={~p"/tenant/settings?tab=features"}
          >
            Features
          </.tab>
          <.tab
            active={@active_tab == "branding"}
            patch={~p"/tenant/settings?tab=branding"}
          >
            Branding
          </.tab>
          <.tab
            active={@active_tab == "notifications"}
            patch={~p"/tenant/settings?tab=notifications"}
          >
            Notifications
          </.tab>
          <.tab
            active={@active_tab == "security"}
            patch={~p"/tenant/settings?tab=security"}
          >
            Security
          </.tab>
        </nav>
      </div>
      
    <!-- Tab Content -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2">
          <%= case @active_tab do %>
            <% "general" -> %>
              <.live_component
                module={GeneralSettingsLive}
                id="general_settings"
                settings={@settings.general || %{}}
                tenant_id={@tenant_id}
              />
            <% "business" -> %>
              <.live_component
                module={BusinessSettingsLive}
                id="business_settings"
                settings={@settings.business_info || %{}}
                contact_settings={@settings.contact_details || %{}}
                tenant_id={@tenant_id}
              />
            <% "features" -> %>
              <.live_component
                module={FeatureTogglesLive}
                id="feature_toggles"
                enabled_features={@enabled_features}
                feature_definitions={@feature_definitions}
                tenant_id={@tenant_id}
              />
            <% "branding" -> %>
              <.live_component
                module={BrandingLive}
                id="branding"
                branding={@branding}
                tenant_id={@tenant_id}
              />
            <% "notifications" -> %>
              <.live_component
                module={NotificationSettingsLive}
                id="notification_settings"
                settings={@settings.notifications || %{}}
                tenant_id={@tenant_id}
              />
            <% "security" -> %>
              <.live_component
                module={SecuritySettingsLive}
                id="security_settings"
                settings={@settings.security || %{}}
                tenant_id={@tenant_id}
              />
            <% _ -> %>
              <div class="text-center py-8">
                <p class="text-gray-500">Settings tab not found</p>
              </div>
          <% end %>
        </div>
        
    <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Quick Actions -->
          <McpWeb.Core.CoreComponents.card class="p-6">
            <h3 class="text-lg font-semibold mb-4">Quick Actions</h3>
            <div class="space-y-3">
              <McpWeb.Core.CoreComponents.button
                phx-click="export_settings"
                class="w-full"
              >
                <McpWeb.Core.CoreComponents.icon name="hero-download" class="mr-2" /> Export Settings
              </McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button
                phx-click="show_import_modal"
                class="w-full"
                variant="primary"
              >
                <McpWeb.Core.CoreComponents.icon name="hero-upload" class="mr-2" /> Import Settings
              </McpWeb.Core.CoreComponents.button>
            </div>
          </McpWeb.Core.CoreComponents.card>
          
    <!-- Status Overview -->
          <McpWeb.Core.CoreComponents.card class="p-6">
            <h3 class="text-lg font-semibold mb-4">Configuration Status</h3>
            <div class="space-y-3">
              <.status_item
                label="Total Settings"
                value={count_total_settings(@settings)}
                icon="hero-cog-6-tooth"
              />
              <.status_item
                label="Enabled Features"
                value={length(@enabled_features)}
                icon="hero-bolt"
              />
              <.status_item
                label="Custom Branding"
                value={if has_custom_branding?(@branding), do: "Active", else: "Default"}
                icon="hero-palette"
              />
            </div>
          </McpWeb.Core.CoreComponents.card>
          
    <!-- Help -->
          <McpWeb.Core.CoreComponents.card class="p-6">
            <h3 class="text-lg font-semibold mb-4">Help & Resources</h3>
            <div class="space-y-3">
              <a href="#" class="block text-sm text-blue-600 hover:text-blue-800">
                <McpWeb.Core.CoreComponents.icon name="hero-book-open" class="mr-2" /> Settings Documentation
              </a>
              <a href="#" class="block text-sm text-blue-600 hover:text-blue-800">
                <McpWeb.Core.CoreComponents.icon name="hero-video-camera" class="mr-2" /> Video Tutorials
              </a>
              <a href="#" class="block text-sm text-blue-600 hover:text-blue-800">
                <McpWeb.Core.CoreComponents.icon name="hero-question-mark-circle" class="mr-2" /> Support Center
              </a>
            </div>
          </McpWeb.Core.CoreComponents.card>
        </div>
      </div>
    </div>

    <!-- Import Modal -->
    <div
      :if={@show_import_modal}
      id="import_modal"
      class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
    >
      <McpWeb.Core.CoreComponents.header>Import Settings</McpWeb.Core.CoreComponents.header>
      <p class="text-gray-600 mb-4">
        Upload a JSON file containing your tenant settings configuration.
      </p>

      <.form
        id="import_form"
        for={%{}}
        phx-submit="import_settings"
        phx-change="validate_import"
      >
        <McpWeb.Core.CoreComponents.input
          type="file"
          name="file"
          accept=".json"
          label="Settings File"
          required
        />

        <div class="flex justify-end space-x-3 mt-6">
          <McpWeb.Core.CoreComponents.button variant="primary" type="button" phx-click="hide_import_modal">
            Cancel
          </McpWeb.Core.CoreComponents.button>
          <McpWeb.Core.CoreComponents.button type="submit" phx-disable-with="Importing...">
            Import Settings
          </McpWeb.Core.CoreComponents.button>
        </div>
      </.form>
      <div class="relative bg-white rounded-lg max-w-md mx-auto mt-20 p-4">
        <button
          type="button"
          phx-click="hide_import_modal"
          class="absolute top-2 right-2 text-gray-400 hover:text-gray-600"
        >
          &times;
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("export_settings", _params, socket) do
    tenant_id = socket.assigns.tenant_id

    case TenantSettingsManager.export_tenant_settings(tenant_id) do
      {:ok, export_data} ->
        json_data = Jason.encode!(export_data, pretty: true)

        # Trigger download
        filename = "tenant_settings_#{socket.assigns.tenant_schema}_#{Date.utc_today()}.json"

        {:noreply,
         push_event(socket, "download_file", %{
           content: json_data,
           filename: filename
         })}
    end
  end

  def handle_event("show_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, true)}
  end

  def handle_event("hide_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, false)}
  end

  def handle_event("import_settings", %{"file" => file}, socket) do
    current_user = socket.assigns.current_user
    tenant_id = socket.assigns.tenant_id

    with {:ok, content} <- File.read(file.path),
         {:ok, import_data} <- Jason.decode(content),
         {:ok, %{imported: true} = _result} <-
           TenantSettingsManager.import_tenant_settings(tenant_id, import_data, current_user.id) do
      # Reload data
      {:ok, settings} = TenantSettingsManager.get_all_tenant_settings(tenant_id)
      {:ok, enabled_features} = TenantSettingsManager.get_enabled_features(tenant_id)
      {:ok, branding} = TenantSettingsManager.get_tenant_branding(tenant_id)

      {:noreply,
       socket
       |> put_flash(:info, "Settings imported successfully")
       |> assign(:settings, settings)
       |> assign(:enabled_features, enabled_features)
       |> assign(:branding, branding)
       |> assign(:show_import_modal, false)}
    else
      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to process import file")
         |> assign(:show_import_modal, false)}
    end
  end

  # Component helper functions

  defp count_total_settings(settings) do
    settings
    |> Map.values()
    |> Enum.map(&map_size/1)
    |> Enum.sum()
  end

  defp has_custom_branding?(branding) do
    branding.colors.primary != "#3B82F6" or not is_nil(branding.assets.logo)
  end

  # Helper components

  defp tab(assigns) do
    ~H"""
    <a
      href={@patch}
      class={[
        "py-2 px-1 border-b-2 font-medium text-sm whitespace-nowrap",
        @active && "border-blue-500 text-blue-600",
        !@active && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
      ]}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  defp status_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-2">
        <McpWeb.Core.CoreComponents.icon name={@icon} class="w-4 h-4 text-gray-500" />
        <span class="text-sm text-gray-600">{@label}</span>
      </div>
      <span class="text-sm font-medium text-gray-900">{@value}</span>
    </div>
    """
  end

  defp get_setting_categories do
    [
      {"general", "General Settings"},
      {"business_info", "Business Information"},
      {"contact_details", "Contact Details"},
      {"notifications", "Notifications"},
      {"billing", "Billing & Finance"},
      {"isp_config", "ISP Configuration"},
      {"security", "Security Settings"},
      {"integrations", "Integrations"}
    ]
  end
end
