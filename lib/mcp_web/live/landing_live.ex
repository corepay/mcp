defmodule McpWeb.LandingLive do
  @moduledoc """
  Context-aware landing page with login modal.
  """
  use McpWeb, :live_view
  import Phoenix.Component

  @impl true
  def mount(_params, session, socket) do
    # Check if user is already authenticated
    current_user = session["current_user"]

    # Get portal context
    portal_context_str = session["portal_context"] || "tenant"
    portal_context = String.to_atom(portal_context_str)

    if current_user do
      {:ok, push_navigate(socket, to: default_redirect_path(portal_context))}
    else
      socket =
        socket
        |> assign(:page_title, portal_title(portal_context))
        |> assign(:portal_context, portal_context)
        |> assign(:portal_config, portal_config(portal_context))
        |> assign(:show_login_modal, false)
        |> assign(:return_to, session["return_to"])

      {:ok, socket, layout: false}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 font-sans relative overflow-hidden">
      <!-- Background Gradients (Context Aware) -->
      <div class={["absolute inset-0 bg-gradient-to-br opacity-10", @portal_config.gradient_class]}>
      </div>
      
    <!-- Animated Background Shapes -->
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class={[
          "absolute -top-24 -left-24 w-96 h-96 rounded-full blur-3xl opacity-20 animate-pulse",
          bg_color_class(@portal_context)
        ]}>
        </div>
        <div class={[
          "absolute top-1/2 right-0 w-64 h-64 rounded-full blur-2xl opacity-20",
          bg_color_class(@portal_context)
        ]}>
        </div>
      </div>
      
    <!-- Navbar -->
      <nav class="relative z-10 w-full max-w-7xl mx-auto px-6 py-6 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <div class={[
            "p-2 rounded-xl text-white shadow-lg bg-gradient-to-br",
            @portal_config.gradient_class
          ]}>
            <McpWeb.Core.CoreComponents.icon name={@portal_config.icon} class="size-6" />
          </div>
          <span class="text-xl font-bold tracking-tight text-base-content">
            MCP <span class="opacity-60 font-normal">Platform</span>
          </span>
        </div>

        <button phx-click="show_login" class="btn btn-primary shadow-lg shadow-primary/20">
          Sign In
        </button>
      </nav>
      
    <!-- Hero Section -->
      <main class="relative z-10 w-full max-w-7xl mx-auto px-6 py-12 md:py-24 flex flex-col md:flex-row items-center gap-12">
        <div class="flex-1 text-center md:text-left space-y-8">
          <div class={[
            "inline-flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium border bg-base-100/50 backdrop-blur-sm",
            border_color_class(@portal_context),
            text_color_class(@portal_context)
          ]}>
            <span class="relative flex h-2 w-2">
              <span class={[
                "animate-ping absolute inline-flex h-full w-full rounded-full opacity-75",
                bg_color_class(@portal_context)
              ]}>
              </span>
              <span class={[
                "relative inline-flex rounded-full h-2 w-2",
                bg_color_class(@portal_context)
              ]}>
              </span>
            </span>
            {@portal_config.title}
          </div>

          <h1 class="text-5xl md:text-7xl font-bold tracking-tight text-base-content leading-tight">
            {@portal_config.hero_title}
            <span class={[
              "text-transparent bg-clip-text bg-gradient-to-r",
              @portal_config.gradient_class
            ]}>
              {@portal_config.hero_highlight}
            </span>
          </h1>

          <p class="text-xl text-base-content/70 max-w-2xl mx-auto md:mx-0 leading-relaxed">
            {@portal_config.subtitle}
          </p>

          <div class="flex flex-col sm:flex-row gap-4 justify-center md:justify-start">
            <.link
              navigate={sign_in_path(@portal_context)}
              class="btn btn-primary btn-lg shadow-xl shadow-primary/20"
            >
              Get Started
              <McpWeb.Core.CoreComponents.icon name="hero-arrow-right" class="size-5 ml-2" />
            </.link>
            <button class="btn btn-ghost btn-lg">
              Learn More
            </button>
          </div>
          
    <!-- Feature Grid -->
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6 pt-8 border-t border-base-content/10">
            <div :for={feature <- @portal_config.features} class="flex items-center gap-3">
              <div class={[
                "p-2 rounded-lg bg-opacity-10",
                bg_color_class(@portal_context),
                text_color_class(@portal_context)
              ]}>
                <McpWeb.Core.CoreComponents.icon name="hero-check" class="size-5" />
              </div>
              <span class="font-medium text-base-content/80">{feature}</span>
            </div>
          </div>
        </div>
        
    <!-- Hero Image / Visual -->
        <div class="flex-1 w-full max-w-lg md:max-w-none relative">
          <div class={[
            "absolute inset-0 rounded-3xl blur-3xl opacity-30 bg-gradient-to-tr",
            @portal_config.gradient_class
          ]}>
          </div>
          <div class="relative bg-base-100/40 backdrop-blur-xl border border-white/20 rounded-3xl shadow-2xl p-6 md:p-8 transform rotate-3 transition-transform hover:rotate-0 duration-500">
            <!-- Mock UI Interface -->
            <div class="space-y-6">
              <div class="flex items-center justify-between border-b border-base-content/10 pb-4">
                <div class="flex gap-2">
                  <div class="w-3 h-3 rounded-full bg-red-400"></div>
                  <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                  <div class="w-3 h-3 rounded-full bg-green-400"></div>
                </div>
                <div class="h-2 w-20 rounded-full bg-base-content/10"></div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div class="h-24 rounded-xl bg-base-content/5 animate-pulse"></div>
                <div class="h-24 rounded-xl bg-base-content/5 animate-pulse delay-75"></div>
                <div class="h-24 rounded-xl bg-base-content/5 animate-pulse delay-150"></div>
                <div class="h-24 rounded-xl bg-base-content/5 animate-pulse delay-200"></div>
              </div>
              <div class="h-32 rounded-xl bg-base-content/5"></div>
            </div>
          </div>
        </div>
      </main>
      
    <!-- Footer -->
      <footer class="relative z-10 w-full max-w-7xl mx-auto px-6 py-8 text-center text-sm text-base-content/40">
        &copy; {Date.utc_today().year} MCP Platform. All rights reserved.
      </footer>
      
    <!-- Login Modal -->
      <McpWeb.Core.CoreComponents.modal
        id="login_modal"
        show={@show_login_modal}
        on_cancel="hide_login"
      >
        <:title>
          <div class="flex items-center gap-3 mb-2">
            <div class={[
              "p-2 rounded-lg text-white shadow-md bg-gradient-to-br",
              @portal_config.gradient_class
            ]}>
              <McpWeb.Core.CoreComponents.icon name={@portal_config.icon} class="size-5" />
            </div>
            <span>Sign In to {@portal_config.title}</span>
          </div>
        </:title>

        <.live_component
          module={McpWeb.AuthLive.LoginComponent}
          id="landing-login-form"
          return_to={@return_to}
          portal_context={@portal_context}
        />
      </McpWeb.Core.CoreComponents.modal>
    </div>
    """
  end

  @impl true
  def handle_event("show_login", _params, socket) do
    {:noreply, assign(socket, :show_login_modal, true)}
  end

  @impl true
  def handle_event("hide_login", _params, socket) do
    {:noreply, assign(socket, :show_login_modal, false)}
  end

  # Handle OAuth redirect from component
  @impl true
  def handle_event("oauth-redirect", %{"url" => url}, socket) do
    {:noreply, redirect(socket, external: url)}
  end

  # Private Helpers (Duplicated from Login.ex for now, ideally extracted to shared module)

  defp portal_title(:admin), do: "Platform Admin"
  defp portal_title(:merchant), do: "Merchant Portal"
  defp portal_title(:developer), do: "Developer Portal"
  defp portal_title(:reseller), do: "Partner Portal"
  defp portal_title(:customer), do: "Customer Account"
  defp portal_title(:vendor), do: "Vendor Portal"
  defp portal_title(:tenant), do: "Tenant Portal"

  defp portal_config(context) do
    %{
      title: portal_title(context),
      subtitle: portal_subtitle(context),
      hero_title: portal_hero_title(context),
      hero_highlight: portal_hero_highlight(context),
      theme_color: portal_theme_color(context),
      gradient_class: portal_gradient(context),
      icon: portal_icon(context),
      features: portal_features(context)
    }
  end

  defp portal_subtitle(:admin),
    do: "Secure access to the platform infrastructure and management tools."

  defp portal_subtitle(:merchant),
    do: "Everything you need to manage your store, orders, and customers in one place."

  defp portal_subtitle(:developer),
    do: "Access API keys, webhooks, and comprehensive documentation for your integrations."

  defp portal_subtitle(:reseller),
    do: "Track commissions, manage merchants, and grow your partnership business."

  defp portal_subtitle(:customer),
    do: "View your order history, manage subscriptions, and update your profile."

  defp portal_subtitle(:vendor),
    do: "Manage your product catalog, track shipments, and handle invoicing."

  defp portal_subtitle(:tenant),
    do: "Collaborate with your team in a secure, dedicated workspace."

  defp portal_hero_title(:admin), do: "Control Center for"
  defp portal_hero_title(:merchant), do: "Grow your business with"
  defp portal_hero_title(:developer), do: "Build the future with"
  defp portal_hero_title(:reseller), do: "Scale your agency with"
  defp portal_hero_title(:customer), do: "Your personal"
  defp portal_hero_title(:vendor), do: "Streamline your"
  defp portal_hero_title(:tenant), do: "Welcome to your"

  defp portal_hero_highlight(:admin), do: "Platform Ops"
  defp portal_hero_highlight(:merchant), do: "Smart Commerce"
  defp portal_hero_highlight(:developer), do: "Powerful APIs"
  defp portal_hero_highlight(:reseller), do: "Partner Tools"
  defp portal_hero_highlight(:customer), do: "Account Hub"
  defp portal_hero_highlight(:vendor), do: "Supply Chain"
  defp portal_hero_highlight(:tenant), do: "Workspace"

  # Theme Colors (Tailwind classes)
  defp portal_theme_color(:admin), do: "slate"
  defp portal_theme_color(:merchant), do: "emerald"
  defp portal_theme_color(:developer), do: "amber"
  defp portal_theme_color(:reseller), do: "violet"
  defp portal_theme_color(:customer), do: "rose"
  defp portal_theme_color(:vendor), do: "cyan"
  defp portal_theme_color(:tenant), do: "indigo"

  defp bg_color_class(:admin), do: "bg-slate-500"
  defp bg_color_class(:merchant), do: "bg-emerald-500"
  defp bg_color_class(:developer), do: "bg-amber-500"
  defp bg_color_class(:reseller), do: "bg-violet-500"
  defp bg_color_class(:customer), do: "bg-rose-500"
  defp bg_color_class(:vendor), do: "bg-cyan-500"
  defp bg_color_class(:tenant), do: "bg-indigo-500"

  defp text_color_class(:admin), do: "text-slate-600"
  defp text_color_class(:merchant), do: "text-emerald-600"
  defp text_color_class(:developer), do: "text-amber-600"
  defp text_color_class(:reseller), do: "text-violet-600"
  defp text_color_class(:customer), do: "text-rose-600"
  defp text_color_class(:vendor), do: "text-cyan-600"
  defp text_color_class(:tenant), do: "text-indigo-600"

  defp border_color_class(:admin), do: "border-slate-200"
  defp border_color_class(:merchant), do: "border-emerald-200"
  defp border_color_class(:developer), do: "border-amber-200"
  defp border_color_class(:reseller), do: "border-violet-200"
  defp border_color_class(:customer), do: "border-rose-200"
  defp border_color_class(:vendor), do: "border-cyan-200"
  defp border_color_class(:tenant), do: "border-indigo-200"

  # Gradients
  defp portal_gradient(:admin), do: "from-slate-800 to-zinc-900"
  defp portal_gradient(:merchant), do: "from-emerald-600 to-teal-700"
  defp portal_gradient(:developer), do: "from-amber-500 to-orange-600"
  defp portal_gradient(:reseller), do: "from-violet-600 to-purple-700"
  defp portal_gradient(:customer), do: "from-rose-500 to-pink-600"
  defp portal_gradient(:vendor), do: "from-cyan-600 to-sky-700"
  defp portal_gradient(:tenant), do: "from-blue-600 to-indigo-700"

  # Icons
  defp portal_icon(:admin), do: "hero-server-stack"
  defp portal_icon(:merchant), do: "hero-shopping-bag"
  defp portal_icon(:developer), do: "hero-code-bracket"
  defp portal_icon(:reseller), do: "hero-user-group"
  defp portal_icon(:customer), do: "hero-heart"
  defp portal_icon(:vendor), do: "hero-truck"
  defp portal_icon(:tenant), do: "hero-building-office-2"

  # Features
  defp portal_features(:admin), do: ["System Monitoring", "User Management", "Audit Logs"]

  defp portal_features(:merchant),
    do: ["Real-time Analytics", "Inventory Management", "Order Processing"]

  defp portal_features(:developer), do: ["API Access", "Webhooks", "Developer Tools"]

  defp portal_features(:reseller),
    do: ["Commission Tracking", "Merchant Onboarding", "Performance Reports"]

  defp portal_features(:customer), do: ["Order History", "Subscription Management", "Support"]
  defp portal_features(:vendor), do: ["Product Catalog", "Shipment Tracking", "Invoicing"]

  defp portal_features(:tenant),
    do: ["Team Collaboration", "Project Management", "Secure Workspace"]

  defp default_redirect_path(:admin), do: "/admin/dashboard"
  defp default_redirect_path(:merchant), do: "/app/dashboard"
  defp default_redirect_path(:developer), do: "/developers/dashboard"
  defp default_redirect_path(:reseller), do: "/partners/dashboard"
  defp default_redirect_path(:customer), do: "/store/account/dashboard"
  defp default_redirect_path(:vendor), do: "/vendors/dashboard"
  defp default_redirect_path(:tenant), do: "/tenant/dashboard"
  defp default_redirect_path(_), do: "/tenant/dashboard"

  defp sign_in_path(:admin), do: "/admin/sign-in"
  defp sign_in_path(:merchant), do: "/app/sign-in"
  defp sign_in_path(:developer), do: "/developers/sign-in"
  defp sign_in_path(:reseller), do: "/partners/sign-in"
  defp sign_in_path(:customer), do: "/store/account/sign-in"
  defp sign_in_path(:vendor), do: "/vendors/sign-in"
  defp sign_in_path(:tenant), do: "/tenant/sign-in"
  defp sign_in_path(_), do: "/tenant/sign-in"
end
