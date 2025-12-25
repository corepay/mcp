defmodule McpWeb.Dev.StyleGuideLive do
  use McpWeb, :live_view

  def mount(_params, _session, socket) do
    users = [
      %{id: 1, name: "Alice Smith", role: "Admin", status: "Active"},
      %{id: 2, name: "Bob Jones", role: "User", status: "Inactive"},
      %{id: 3, name: "Charlie Day", role: "User", status: "Active"}
    ]

    {:ok, assign(socket, users: users)}
  end

  def handle_event("confirm", _, socket) do
    {:noreply, put_flash(socket, :info, "Confirmed!")}
  end

  def handle_event("cancel", _, socket) do
    {:noreply, put_flash(socket, :info, "Cancelled!")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 space-y-12">
      <McpWeb.Core.CoreComponents.header>
        Style Guide
        <:subtitle>The living documentation of our design system.</:subtitle>
        <:actions>
          <div class="join">
            <button
              class="join-item btn btn-sm"
              data-phx-theme="light"
              phx-click={JS.dispatch("phx:set-theme")}
            >
              Light
            </button>
            <button
              class="join-item btn btn-sm"
              data-phx-theme="dark"
              phx-click={JS.dispatch("phx:set-theme")}
            >
              Dark
            </button>
            <button
              class="join-item btn btn-sm"
              data-phx-theme="system"
              phx-click={JS.dispatch("phx:set-theme")}
            >
              System
            </button>
          </div>
        </:actions>
      </McpWeb.Core.CoreComponents.header>

      <section class="space-y-4">
        <h2 class="text-2xl font-bold border-b border-base-300 pb-2">Typography</h2>
        <div class="space-y-4">
          <div>
            <span class="text-sm text-base-content/60 uppercase tracking-widest">H1 Heading</span>
            <h1 class="text-4xl font-medium">The quick brown fox jumps over the lazy dog</h1>
          </div>
          <div>
            <span class="text-sm text-base-content/60 uppercase tracking-widest">H2 Heading</span>
            <h2 class="text-3xl font-medium">The quick brown fox jumps over the lazy dog</h2>
          </div>
          <div>
            <span class="text-sm text-base-content/60 uppercase tracking-widest">H3 Heading</span>
            <h3 class="text-2xl font-medium">The quick brown fox jumps over the lazy dog</h3>
          </div>
          <div>
            <span class="text-sm text-base-content/60 uppercase tracking-widest">Body Text</span>
            <p class="text-base leading-relaxed">
              Lorem ipsum dolor sit amet, consectetur adipiscing elit. Domines, ut aiunt, luce clarior est
              <span class="font-bold">bold text</span>
              and <span class="italic">italic text</span>.
              We use <span class="badge badge-neutral">badges</span>
              for metadata.
            </p>
          </div>
        </div>
      </section>

      <section class="space-y-4">
        <h2 class="text-2xl font-bold border-b border-base-300 pb-2">Colors</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="space-y-2">
            <div class="h-24 rounded-box bg-primary shadow-sm flex items-center justify-center text-primary-content font-bold">
              Primary
            </div>
            <div class="text-xs text-center font-mono">--color-primary</div>
          </div>
          <div class="space-y-2">
            <div class="h-24 rounded-box bg-secondary shadow-sm flex items-center justify-center text-secondary-content font-bold">
              Secondary
            </div>
            <div class="text-xs text-center font-mono">--color-secondary</div>
          </div>
          <div class="space-y-2">
            <div class="h-24 rounded-box bg-accent shadow-sm flex items-center justify-center text-accent-content font-bold">
              Accent
            </div>
            <div class="text-xs text-center font-mono">--color-accent</div>
          </div>
          <div class="space-y-2">
            <div class="h-24 rounded-box bg-neutral shadow-sm flex items-center justify-center text-neutral-content font-bold">
              Neutral
            </div>
            <div class="text-xs text-center font-mono">--color-neutral</div>
          </div>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
          <div class="space-y-2">
            <div class="h-16 rounded-box bg-info shadow-sm flex items-center justify-center text-info-content font-bold text-sm">
              Info
            </div>
          </div>
          <div class="space-y-2">
            <div class="h-16 rounded-box bg-success shadow-sm flex items-center justify-center text-success-content font-bold text-sm">
              Success
            </div>
          </div>
          <div class="space-y-2">
            <div class="h-16 rounded-box bg-warning shadow-sm flex items-center justify-center text-warning-content font-bold text-sm">
              Warning
            </div>
          </div>
          <div class="space-y-2">
            <div class="h-16 rounded-box bg-error shadow-sm flex items-center justify-center text-error-content font-bold text-sm">
              Error
            </div>
          </div>
        </div>
      </section>

      <section class="space-y-4">
        <h2 class="text-2xl font-bold border-b border-base-300 pb-2">Core Components</h2>
        <div class="grid gap-8">
          <McpWeb.Core.CoreComponents.card class="bg-base-100">
            <h3 class="card-title mb-4">Buttons</h3>
            <div class="flex flex-wrap gap-2">
              <McpWeb.Core.CoreComponents.button>Default</McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button variant="primary">
                Primary
              </McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button variant="secondary">
                Secondary
              </McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button variant="accent">
                Accent
              </McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button variant="ghost">
                Ghost
              </McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button variant="link">
                Link
              </McpWeb.Core.CoreComponents.button>
            </div>
            <div class="flex flex-wrap gap-2 mt-4">
              <McpWeb.Core.CoreComponents.button size="xs">Tiny</McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button size="sm">Small</McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button>Normal</McpWeb.Core.CoreComponents.button>
              <McpWeb.Core.CoreComponents.button size="lg">Large</McpWeb.Core.CoreComponents.button>
            </div>
          </McpWeb.Core.CoreComponents.card>

          <McpWeb.Core.CoreComponents.card class="bg-base-100">
            <h3 class="card-title mb-4">Inputs</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <McpWeb.Core.CoreComponents.input
                type="text"
                name="example_text"
                label="Text Input"
                placeholder="Type here..."
              />
              <McpWeb.Core.CoreComponents.input
                type="email"
                name="example_email"
                label="Email Input"
                placeholder="john@doe.com"
              />
              <McpWeb.Core.CoreComponents.input
                type="password"
                name="example_pass"
                label="Password"
                value="password123"
              />
              <McpWeb.Core.CoreComponents.input
                type="select"
                name="example_select"
                label="Select Option"
                options={["Option 1", "Option 2"]}
              />
            </div>
          </McpWeb.Core.CoreComponents.card>

          <McpWeb.Core.CoreComponents.card class="bg-base-100">
            <h3 class="card-title mb-4">Feedback / Modal</h3>
            <div class="flex flex-col gap-4">
              <div class="alert alert-info">
                <McpWeb.Core.CoreComponents.icon name="hero-information-circle" class="size-6" />
                <span>New software update available.</span>
              </div>
              <div>
                <McpWeb.Core.CoreComponents.button phx-click={
                  McpWeb.Core.CoreComponents.show_modal("example_modal")
                }>
                  Open Modal
                </McpWeb.Core.CoreComponents.button>
              </div>
            </div>
          </McpWeb.Core.CoreComponents.card>
        </div>
      </section>

      <section class="space-y-4">
        <h2 class="text-2xl font-bold border-b border-base-300 pb-2">Data Display</h2>
        <McpWeb.Core.CoreComponents.card class="bg-base-100">
          <h3 class="card-title mb-4">Table</h3>
          <McpWeb.Core.CoreComponents.table rows={@users}>
            <:col :let={user} label="Name">{user.name}</:col>
            <:col :let={user} label="Role">{user.role}</:col>
            <:col :let={user} label="Status">
              <div class={[
                "badge",
                user.status == "Active" && "badge-success",
                user.status == "Inactive" && "badge-ghost"
              ]}>
                {user.status}
              </div>
            </:col>
            <:action :let={_user}>
              <McpWeb.Core.CoreComponents.button variant="ghost" size="sm">
                Edit
              </McpWeb.Core.CoreComponents.button>
            </:action>
          </McpWeb.Core.CoreComponents.table>
        </McpWeb.Core.CoreComponents.card>
      </section>

      <section class="space-y-4">
        <h2 class="text-2xl font-bold border-b border-base-300 pb-2">UI Elements</h2>
        <div class="grid gap-8 md:grid-cols-2">
          <McpWeb.Core.CoreComponents.card class="bg-base-100">
            <h3 class="card-title mb-4">Badges</h3>
            <div class="flex flex-wrap gap-2">
              <div class="badge">Default</div>
              <div class="badge badge-neutral">Neutral</div>
              <div class="badge badge-primary">Primary</div>
              <div class="badge badge-secondary">Secondary</div>
              <div class="badge badge-accent">Accent</div>
              <div class="badge badge-ghost">Ghost</div>
              <div class="badge badge-outline">Outline</div>
            </div>
          </McpWeb.Core.CoreComponents.card>

          <McpWeb.Core.CoreComponents.card class="bg-base-100">
            <h3 class="card-title mb-4">Avatars</h3>
            <div class="flex flex-wrap items-center gap-4">
              <div class="avatar online">
                <div class="w-16 rounded-full">
                  <img src="https://img.daisyui.com/images/stock/photo-1534528741775-53994a69daeb.webp" />
                </div>
              </div>
              <div class="avatar offline">
                <div class="w-12 rounded-full">
                  <img src="https://img.daisyui.com/images/stock/photo-1534528741775-53994a69daeb.webp" />
                </div>
              </div>
              <div class="avatar placeholder">
                <div class="bg-neutral text-neutral-content rounded-full w-12 h-12 !flex !items-center !justify-center">
                  <span class="text-xl">AI</span>
                </div>
              </div>
            </div>
          </McpWeb.Core.CoreComponents.card>
        </div>
      </section>

      <McpWeb.Core.CoreComponents.modal
        id="example_modal"
        on_cancel={McpWeb.Core.CoreComponents.hide_modal("example_modal")}
      >
        <:title>Hello!</:title>
        <p>This is a modal example generated from the CoreComponents module.</p>
        <p class="py-4">It supports standard slots for title, content, and actions.</p>
        <:confirm_text>Awesome</:confirm_text>
      </McpWeb.Core.CoreComponents.modal>
    </div>
    """
  end
end
