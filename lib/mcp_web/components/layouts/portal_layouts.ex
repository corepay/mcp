defmodule McpWeb.Layouts.PortalLayouts do
  use McpWeb, :html

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
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
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
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Merchant Portal Layout
  """
  def merchant_portal(assigns) do
    ~H"""
    <.app_shell title="Merchant Portal">
      <:sidebar>
        <li><.link navigate={~p"/app"}>Dashboard</.link></li>
        <li><.link navigate={~p"/app/orders"}>Orders</.link></li>
        <li><.link navigate={~p"/app/products"}>Products</.link></li>
        <li><.link navigate={~p"/app/customers"}>Customers</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
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
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
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
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
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
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
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
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
    """
  end

  @doc """
  Store Portal Layout
  """
  def store_portal(assigns) do
    ~H"""
    <.app_shell title="Store Portal">
      <:sidebar>
        <li><.link navigate={~p"/app/stores/#{@conn.params["store_slug"]}"}>Dashboard</.link></li>
        <li><.link navigate={~p"/app/stores/#{@conn.params["store_slug"]}/terminal"}>Virtual Terminal</.link></li>
        <li><.link navigate={~p"/app/stores/#{@conn.params["store_slug"]}/invoices"}>Invoices</.link></li>
        <li><.link navigate={~p"/app/stores/#{@conn.params["store_slug"]}/subscriptions"}>Subscriptions</.link></li>
      </:sidebar>
      <:user_menu>
        <li><.link method="delete" href={~p"/sign_out"}>Sign out</.link></li>
      </:user_menu>
      {@inner_content}
    </.app_shell>
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
          {@inner_content}
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
end
