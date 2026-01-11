defmodule McpWeb.Layouts.PortalLayouts do
  @moduledoc """
  Layouts for the portal.
  """
  use McpWeb, :html

  alias McpWeb.Layouts.MerchantShell
  alias McpWeb.Layouts.StoreShell

  @doc """
  Platform Admin Layout
  """
  def platform_admin(assigns) do
    ~H"""
    <.app_shell title="Platform Admin" theme="dark">
      <:sidebar>
        <li><.link navigate={~p"/admin"}>Dashboard</.link></li>
        <li><.link navigate={~p"/admin/tenants"}>Tenants</.link></li>
        <li><.link navigate={~p"/admin/settings"}>Settings</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign-out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Tenant Portal Layout
  """
  def tenant_portal(assigns) do
    ~H"""
    <.app_shell title="Tenant Portal">
      <:sidebar>
        <li><.link navigate={~p"/tenant"}>Dashboard</.link></li>
        <li><.link navigate={~p"/tenant/merchants"}>Merchants</.link></li>
        <li><.link navigate={~p"/tenant/settings"}>Settings</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign-out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Merchant Portal Layout - Uses new MerchantShell with top nav + contextual sidebar
  """
  def merchant_portal(assigns) do
    assigns =
      assigns
      |> assign_new(:merchant_name, fn -> get_merchant_name(assigns) end)
      |> assign_new(:stores, fn -> get_stores(assigns) end)
      |> assign_new(:current_path, fn -> get_current_path(assigns) end)
      |> assign_new(:user_initials, fn -> get_user_initials(assigns) end)

    ~H"""
    <MerchantShell.merchant_shell
      merchant_name={@merchant_name}
      stores={@stores}
      current_path={@current_path}
      user_initials={@user_initials}
    >
      {@inner_content}
    </MerchantShell.merchant_shell>
    """
  end

  @doc """
  Developer Portal Layout
  """
  def developer_portal(assigns) do
    ~H"""
    <.app_shell title="Developer Portal">
      <:sidebar>
        <li><.link navigate={~p"/developers"}>Dashboard</.link></li>
        <li><.link navigate={~p"/developers/apps"}>My Apps</.link></li>
        <li><.link navigate={~p"/developers/docs"}>Documentation</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign-out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Reseller Portal Layout
  """
  def reseller_portal(assigns) do
    ~H"""
    <.app_shell title="Reseller Portal">
      <:sidebar>
        <li><.link navigate={~p"/partners"}>Dashboard</.link></li>
        <li><.link navigate={~p"/partners/merchants"}>Merchants</.link></li>
        <li><.link navigate={~p"/partners/commissions"}>Commissions</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign-out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Customer Portal Layout
  """
  def customer_portal(assigns) do
    ~H"""
    <.app_shell title="My Account">
      <:sidebar>
        <li><.link navigate={~p"/store/account"}>Dashboard</.link></li>
        <li><.link navigate={~p"/store/account/orders"}>Orders</.link></li>
        <li><.link navigate={~p"/store/account/profile"}>Profile</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign-out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Vendor Portal Layout
  """
  def vendor_portal(assigns) do
    ~H"""
    <.app_shell title="Vendor Portal">
      <:sidebar>
        <li><.link navigate={~p"/vendors"}>Dashboard</.link></li>
        <li><.link navigate={~p"/vendors/products"}>Products</.link></li>
        <li><.link navigate={~p"/vendors/orders"}>Orders</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign-out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Store Portal Layout - Uses new StoreShell with left sidebar navigation
  """
  def store_portal(assigns) do
    store_slug = get_store_slug(assigns)

    assigns =
      assigns
      |> assign(:store_slug, store_slug)
      |> assign_new(:store_name, fn -> get_store_name(assigns, store_slug) end)
      |> assign_new(:merchant_name, fn -> get_merchant_name(assigns) end)
      |> assign_new(:current_path, fn -> get_current_path(assigns) end)
      |> assign_new(:user_initials, fn -> get_user_initials(assigns) end)
      |> assign_new(:vertical, fn -> :retail end)

    ~H"""
    <StoreShell.store_shell
      store_name={@store_name}
      store_slug={@store_slug}
      merchant_name={@merchant_name}
      current_path={@current_path}
      user_initials={@user_initials}
      vertical={@vertical}
    >
      {@inner_content}
    </StoreShell.store_shell>
    """
  end

  @doc """
  Generic App Shell using DaisyUI Drawer
  """
  attr :title, :string, required: true
  attr :theme, :string, default: "light"
  slot :sidebar, required: true
  slot :user_menu, required: true
  slot :inner_block, required: true

  def app_shell(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open min-h-screen bg-base-200" data-theme={@theme}>
      <input id="app-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col">
        <!-- Navbar -->
        <div class="w-full navbar bg-base-100 shadow-sm lg:hidden">
          <div class="flex-none">
            <label for="app-drawer" aria-label="open sidebar" class="btn btn-square btn-ghost">
              <.icon name="hero-bars-3" class="w-6 h-6" />
            </label>
          </div>
          <div class="flex-1 px-2 mx-2">{@title}</div>
        </div>
        
    <!-- Page Content -->
        <main class="flex-1 p-6">
          {render_slot(@inner_block)}
        </main>
      </div>
      
    <!-- Sidebar -->
      <div class="drawer-side z-20">
        <label for="app-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <ul class="menu p-4 w-80 min-h-full bg-base-100 text-base-content gap-2">
          <!-- Sidebar Header -->
          <li class="mb-4">
            <span class="text-xl font-bold px-4">{@title}</span>
          </li>
          
    <!-- Sidebar Content -->
          {render_slot(@sidebar)}

          <div class="divider mt-auto"></div>
          
    <!-- User Menu -->
          {render_slot(@user_menu)}
        </ul>
      </div>
    </div>
    """
  end

  # Helper functions for extracting data from conn/session/socket
  defp get_store_slug(assigns) do
    cond do
      # Check if already in assigns (from LiveView)
      Map.has_key?(assigns, :store_slug) ->
        assigns.store_slug

      # LiveView socket context - check path_params
      Map.has_key?(assigns, :socket) && Map.has_key?(assigns.socket.assigns, :store_slug) ->
        assigns.socket.assigns.store_slug

      # Traditional conn context
      Map.has_key?(assigns, :conn) ->
        assigns.conn.params["store_slug"] || "unknown"

      # Fallback
      true ->
        "unknown"
    end
  end

  defp get_merchant_name(assigns) do
    # In production, get from session/assigns
    Map.get(assigns, :merchant_name, "Acme Corp")
  end

  defp get_stores(_assigns) do
    # In production, query from Ash
    [
      %{name: "Downtown Store", slug: "downtown"},
      %{name: "Online Shop", slug: "online"}
    ]
  end

  defp get_store_name(_assigns, slug) do
    # In production, query from Ash
    case slug do
      "downtown" -> "Downtown Store"
      "online" -> "Online Shop"
      _ -> "Store"
    end
  end

  defp get_current_path(assigns) do
    cond do
      # LiveView socket context
      Map.has_key?(assigns, :socket) ->
        assigns.socket.view
        |> to_string()
        |> get_path_from_module()

      # Traditional conn context
      Map.has_key?(assigns, :conn) ->
        assigns.conn.request_path

      # Fallback
      true ->
        "/app"
    end
  end

  defp get_path_from_module(module_string) do
    cond do
      String.contains?(module_string, "Merchant.DashboardLive") -> "/app/dashboard"
      String.contains?(module_string, "Store.DashboardLive") -> "/app/stores"
      String.contains?(module_string, "ProductsLive") -> "/app/products"
      String.contains?(module_string, "CustomersLive") -> "/app/customers"
      String.contains?(module_string, "OrdersLive") -> "/app/orders"
      true -> "/app"
    end
  end

  defp get_user_initials(assigns) do
    # In production, get from current_user
    Map.get(assigns, :user_initials, "JD")
  end
end
