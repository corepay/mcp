defmodule McpWeb.AuthComponents do
  @moduledoc """
  Provides premium UI components for authentication pages.
  """
  use Phoenix.Component
  alias McpWeb.CoreComponents

  @doc """
  Renders the main login layout with a split screen or centered card design.
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :image_url, :string, default: nil
  slot :inner_block, required: true

  def auth_layout(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col md:flex-row bg-base-200">
      <!-- Left Side: Branding/Image (Hidden on mobile if no image, or just a header) -->
      <div :if={@image_url} class="hidden md:flex md:w-1/2 bg-cover bg-center relative" style={"background-image: url('#{@image_url}')"}>
        <div class="absolute inset-0 bg-black/40 backdrop-blur-[2px]"></div>
        <div class="relative z-10 flex flex-col justify-center items-center w-full h-full text-white p-12 text-center">
          <h1 class="text-5xl font-bold mb-6">{@title}</h1>
          <p class="text-xl opacity-90">{@subtitle}</p>
        </div>
      </div>

      <!-- Right Side: Login Form -->
      <div class={["flex-1 flex flex-col justify-center items-center p-8", @image_url == nil && "w-full"]}>
        <div class="w-full max-w-md space-y-8">
          <!-- Mobile Header (if image hidden) -->
          <div :if={!@image_url} class="text-center mb-10">
            <h2 class="text-4xl font-bold text-base-content">{@title}</h2>
            <p class="mt-2 text-base-content/60">{@subtitle}</p>
          </div>

          <!-- Login Card -->
          <div class="card bg-base-100 shadow-2xl border border-base-300">
            <div class="card-body p-8">
              {render_slot(@inner_block)}
            </div>
          </div>

          <!-- Footer -->
          <p class="text-center text-sm text-base-content/50">
            &copy; {Date.utc_today().year} MCP Platform. All rights reserved.
          </p>
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
        />
      </div>
      <label :for={msg <- @field.errors} class="label">
        <span class="label-text-alt text-error">{msg}</span>
      </label>
    </div>
    """
  end
end
