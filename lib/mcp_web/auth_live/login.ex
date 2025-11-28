defmodule McpWeb.AuthLive.Login do
  @moduledoc """
  LiveView login page using the reusable LoginComponent.
  """

  use McpWeb, :live_view
  import Phoenix.Component

  @impl true
  def mount(_params, session, socket) do
    # Check if user is already authenticated via session plug
    current_user = session["current_user"]

    # Get portal context from session (passed from router)
    # Default to :tenant if not specified (fallback)
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
        |> assign(:return_to, session["return_to"])
        # Handle any flash messages from the session
        |> assign_flash_from_session(session)

      {:ok, socket, layout: false}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <McpWeb.Portals.AuthComponents.auth_layout
      title={@portal_config.title}
      subtitle={@portal_config.subtitle}
      image_url={@portal_config.image_url}
      theme_color={@portal_config.theme_color}
      gradient_class={@portal_config.gradient_class}
      icon={@portal_config.icon}
      features={@portal_config.features}
      bg_color_class={@portal_config.bg_color_class}
      flash={@flash}
    >
      <.live_component
        module={McpWeb.AuthLive.LoginComponent}
        id="login-form"
        return_to={@return_to}
        portal_context={@portal_context}
      />
    </McpWeb.Portals.AuthComponents.auth_layout>
    """
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Handle return_to parameter from redirects
    socket =
      case params["return_to"] do
        return_to when is_binary(return_to) ->
          assign(socket, :return_to, return_to)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  # Handle OAuth redirect from component
  @impl true
  def handle_event("oauth-redirect", %{"url" => url}, socket) do
    {:noreply, redirect(socket, external: url)}
  end

  # Private helper functions

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
      image_url: portal_image(context),
      theme_color: portal_theme_color(context),
      gradient_class: portal_gradient(context),
      icon: portal_icon(context),
      features: portal_features(context),
      bg_color_class: bg_color_class(context)
    }
  end

  defp portal_subtitle(:admin), do: "Manage the entire platform infrastructure."
  defp portal_subtitle(:merchant), do: "Manage your store, orders, and customers."
  defp portal_subtitle(:developer), do: "Access API keys, webhooks, and documentation."
  defp portal_subtitle(:reseller), do: "Track commissions and manage your merchants."
  defp portal_subtitle(:customer), do: "View your order history and manage subscriptions."
  defp portal_subtitle(:vendor), do: "Manage your products and fulfillment."
  defp portal_subtitle(:tenant), do: "Sign in to your organization's workspace."

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

  # Placeholder images
  defp portal_image(_), do: nil

  defp default_redirect_path(:admin), do: "/admin"
  defp default_redirect_path(:merchant), do: "/app"
  defp default_redirect_path(:developer), do: "/developers"
  defp default_redirect_path(:reseller), do: "/partners"
  defp default_redirect_path(:customer), do: "/store/account"
  defp default_redirect_path(:vendor), do: "/vendors"
  defp default_redirect_path(:tenant), do: "/tenant"
  defp default_redirect_path(:ola), do: "/online-application/application"
  defp default_redirect_path(_), do: "/tenant"

  defp portal_title(:ola), do: "Merchant Application"
  defp portal_subtitle(:ola), do: "Apply for a merchant account in minutes."
  defp portal_theme_color(:ola), do: "blue"
  defp bg_color_class(:ola), do: "bg-blue-500"
  defp portal_gradient(:ola), do: "from-blue-600 to-indigo-700"
  defp portal_icon(:ola), do: "hero-document-text"
  defp portal_features(:ola), do: ["Fast Approval", "Secure", "24/7 Support"]

  defp assign_flash_from_session(socket, session) do
    flash_messages = session["flash"] || %{}

    if flash_messages != %{} do
      # We need to pass these to the component via assigns if we want them to show up there
      # For now, standard flash mechanism might be enough if component uses it
      socket
    else
      socket
    end
  end
end
