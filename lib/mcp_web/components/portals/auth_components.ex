defmodule McpWeb.Portals.AuthComponents do
  @moduledoc """
  Provides premium UI components for authentication pages.
  """
  use Phoenix.Component
  alias McpWeb.Core.CoreComponents

  @doc """
  Renders the main login layout with a split screen or centered card design.
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :image_url, :string, default: nil
  attr :theme_color, :string, default: "primary"
  attr :gradient_class, :string, default: "from-blue-600 to-indigo-700"
  attr :icon, :string, default: "hero-lock-closed"
  attr :features, :list, default: []
  attr :bg_color_class, :string, default: "bg-primary"
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def auth_layout(assigns) do
    ~H"""
    <div
      class="min-h-screen flex flex-col md:flex-row bg-base-200 font-sans"
      role="main"
      aria-label={@title}
    >
      <CoreComponents.flash kind={:info} title="Info" flash={@flash} />
      <CoreComponents.flash kind={:error} title="Error" flash={@flash} />
      <CoreComponents.flash kind={:success} title="Success" flash={@flash} />
      <CoreComponents.flash kind={:warning} title="Warning" flash={@flash} />
      
    <!-- Left Side: Branding/Context (Hidden on mobile) -->
      <div class="hidden md:flex md:w-1/2 relative overflow-hidden bg-base-200">
        <!-- Background Gradients (Context Aware) -->
        <div class={["absolute inset-0 bg-gradient-to-br opacity-20", @gradient_class]}></div>
        
    <!-- Animated Background Shapes -->
        <div class="absolute inset-0 overflow-hidden">
          <div class={[
            "absolute -top-24 -left-24 w-96 h-96 rounded-full blur-3xl animate-pulse opacity-30",
            @bg_color_class
          ]}>
          </div>
          <div class={[
            "absolute top-1/2 left-1/2 w-64 h-64 rounded-full blur-2xl opacity-30",
            @bg_color_class
          ]}>
          </div>
          <div class={[
            "absolute -bottom-12 -right-12 w-80 h-80 rounded-full blur-3xl opacity-20",
            @bg_color_class
          ]}>
          </div>
        </div>
        
    <!-- Content Overlay -->
        <div class="relative z-10 flex flex-col justify-center items-start w-full h-full text-white p-16">
          <div class="mb-8 p-4 bg-white/10 backdrop-blur-md rounded-2xl border border-white/20 shadow-xl">
            <CoreComponents.icon name={@icon} class="size-12 text-white" />
          </div>

          <h1 class="text-5xl font-bold mb-6 tracking-tight leading-tight">{@title}</h1>
          <p class="text-xl opacity-90 font-light leading-relaxed max-w-lg">{@subtitle}</p>
          
    <!-- Feature List -->
          <div :if={@features != []} class="mt-12 space-y-4">
            <div
              :for={feature <- @features}
              class="flex items-center gap-3 opacity-80 hover:opacity-100 transition-opacity"
            >
              <div class="p-1 rounded-full bg-white/20">
                <CoreComponents.icon name="hero-check" class="size-4" />
              </div>
              <span class="font-medium">{feature}</span>
            </div>
          </div>
        </div>
        
    <!-- Glass Footer on Left -->
        <div class="absolute bottom-8 left-16 text-xs text-white/40 font-mono">
          SECURE CONNECTION • ENCRYPTED
        </div>
      </div>
      
    <!-- Right Side: Login Form -->
      <div class="flex-1 flex flex-col justify-center items-center p-6 md:p-12 bg-base-100 relative">
        <!-- Mobile Header Background (visible only on mobile) -->
        <div class={["absolute top-0 left-0 right-0 h-2 bg-gradient-to-r md:hidden", @gradient_class]}>
        </div>

        <div class="w-full max-w-md space-y-8">
          <!-- Mobile Header -->
          <div class="md:hidden text-center mb-8">
            <div class={[
              "inline-flex p-3 rounded-xl mb-4 text-white shadow-lg bg-gradient-to-br",
              @gradient_class
            ]}>
              <CoreComponents.icon name={@icon} class="size-8" />
            </div>
            <h2 class="text-3xl font-bold text-base-content">{@title}</h2>
            <p class="mt-2 text-base-content/60">{@subtitle}</p>
          </div>
          
    <!-- Login Card -->
          <div class="card bg-base-100/50 backdrop-blur-sm md:shadow-2xl md:border border-base-200/50 rounded-3xl overflow-hidden transition-all duration-300 hover:shadow-primary/5">
            <div class="card-body p-0 md:p-8">
              {render_slot(@inner_block)}
            </div>
          </div>
          
    <!-- Footer -->
          <div class="text-center space-y-4">
            <p class="text-xs text-base-content/40">
              Protected by enterprise-grade security. <br />
              &copy; {Date.utc_today().year} MCP Platform.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a premium login form input with icon.
  """
  attr :field, Phoenix.HTML.FormField
  attr :icon, :string, required: true
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :label, :string, default: nil

  def auth_input(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label :if={@label} class="label font-medium">
        <span class="label-text">{@label}</span>
      </label>
      <div class="relative">
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-base-content/50">
          <CoreComponents.icon name={@icon} class="size-5" />
        </div>
        <input
          type={@type}
          name={@field.name}
          id={@field.id}
          value={@field.value}
          placeholder={@placeholder}
          class={[
            "input input-bordered w-full pl-10 focus:input-primary transition-all duration-200",
            @field.errors != [] && "input-error"
          ]}
          aria-invalid={@field.errors != []}
          aria-describedby={@field.id <> "-error"}
        />
      </div>
      <label :for={msg <- @field.errors} class="label" id={@field.id <> "-error"}>
        <span class="label-text-alt text-error">{msg}</span>
      </label>
    </div>
    """
  end
end
