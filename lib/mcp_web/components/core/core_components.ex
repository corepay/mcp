defmodule McpWeb.Core.CoreComponents do
  @moduledoc """
  Provides core UI components based on DaisyUI.
  """
  use Phoenix.Component
  use Gettext, backend: McpWeb.Gettext
  alias Phoenix.LiveView.JS

  @doc """
  Renders a button.
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: nil

  attr :variant, :string,
    default: "primary",
    values: ~w(primary secondary accent info success warning error ghost link outline)

  attr :size, :string, default: nil, values: [nil, "lg", "sm", "xs"]
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :href, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <%= if @navigate || @patch || @href do %>
      <.link
        navigate={@navigate}
        patch={@patch}
        href={@href}
        class={[
          "btn",
          "btn-#{@variant}",
          @size && "btn-#{@size}",
          @class
        ]}
        {@rest}
      >
        {render_slot(@inner_block)}
      </.link>
    <% else %>
      <button
        type={@type}
        class={[
          "btn",
          "btn-#{@variant}",
          @size && "btn-#{@size}",
          @class
        ]}
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
    <% end %>
    """
  end

  @doc """
  Renders an input field.
  """
  attr :id, :any, default: nil
  attr :name, :any, default: nil
  attr :label, :string, default: nil
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :class, :string, default: nil
  attr :required, :boolean, default: false
  attr :accept, :string, default: nil
  attr :options, :list, default: []
  attr :step, :string, default: nil
  attr :min, :string, default: nil
  attr :max, :string, default: nil
  attr :rest, :global

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign(:name, assigns.name || field.name)
    |> assign(:value, assigns.value || field.value)
    |> input()
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="form-control w-full">
      <label :if={@label} class="label" for={@id}>
        <span class="label-text">{@label}</span>
      </label>
      <select
        id={@id}
        name={@name}
        class={[
          "select select-bordered w-full focus:outline-none",
          @errors != [] && "select-error",
          @class
        ]}
        required={@required}
        {@rest}
      >
        <option :for={opt <- @options} value={opt} selected={@value == opt}>{opt}</option>
      </select>
      <label :for={msg <- @errors} class="label">
        <span class="label-text-alt text-error">{msg}</span>
      </label>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label :if={@label} class="label" for={@id}>
        <span class="label-text">{@label}</span>
      </label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={@value}
        class={[
          "input input-bordered w-full focus:outline-none",
          @errors != [] && "input-error",
          @class
        ]}
        required={@required}
        accept={@accept}
        step={@step}
        min={@min}
        max={@max}
        {@rest}
      />
      <label :for={msg <- @errors} class="label">
        <span class="label-text-alt text-error">{msg}</span>
      </label>
    </div>
    """
  end

  @doc """
  Renders a modal.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, :any, default: nil
  attr :on_confirm, :any, default: nil
  attr :"data-testid", :string, default: nil
  attr :width, :string, default: nil
  slot :inner_block, required: true
  slot :title
  slot :confirm_text
  slot :cancel_text
  slot :extra_footer

  def modal(assigns) do
    ~H"""
    <dialog id={@id} class={["modal", @show && "modal-open"]} data-testid={assigns[:"data-testid"]}>
      <div class={[
        "modal-box bg-base-100/95 border border-white/10 shadow-2xl backdrop-blur-xl flex flex-col p-0 overflow-hidden relative z-[50]",
        @width || "max-w-lg",
        "max-h-[95vh] rounded-3xl"
      ]}>
        <div :if={@title != []} class="px-8 py-6 border-b border-white/5 shrink-0 bg-base-100/50 backdrop-blur-md z-[60]">
          <h3 class="font-black text-xl uppercase tracking-widest text-white">{render_slot(@title)}</h3>
        </div>

        <div class="p-8 overflow-y-auto custom-scrollbar flex-1 bg-gradient-to-b from-transparent to-base-200/20 relative z-[40]">
          {render_slot(@inner_block)}
        </div>

        <div
          :if={@confirm_text != [] || @cancel_text != [] || @extra_footer != []}
          class="shrink-0 px-8 py-6 border-t border-white/5 bg-base-100 flex items-center justify-between gap-3 relative z-[100]"
        >
          <div class="flex items-center gap-3">
            {render_slot(@extra_footer)}
          </div>
          <div class="flex gap-3">
            <form :if={@cancel_text != []} method="dialog">
              <button class="btn btn-ghost rounded-xl px-6 font-bold uppercase tracking-widest text-xs" phx-click={@on_cancel}>
                {render_slot(@cancel_text)}
              </button>
            </form>
            <button
              :if={@confirm_text != []}
              class="btn btn-primary rounded-xl px-8 font-black uppercase tracking-widest text-xs shadow-lg shadow-primary/20"
              phx-click={@on_confirm || "confirm"}
            >
              {render_slot(@confirm_text)}
            </button>
          </div>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop bg-black/60 backdrop-blur-sm z-[30]">
        <button phx-click={@on_cancel}>close</button>
      </form>
    </dialog>
    """
  end

  @doc """
  Renders a simple table.
  """
  attr :id, :string
  attr :rows, :list, required: true

  slot :col, required: true do
    attr :label, :string
  end

  slot :action

  def table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table">
        <thead>
          <tr>
            <th :for={col <- @col}>{col[:label]}</th>
            <th :if={@action != []}>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows}>
            <td :for={col <- @col}>{render_slot(col, row)}</td>
            <td :if={@action != []}>
              {render_slot(@action, row)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a flash message.
  """
  attr :kind, :atom
  attr :title, :string, default: nil
  attr :flash, :map, default: %{}
  attr :rest, :global
  slot :inner_block

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error",
        @kind == :success && "alert-success",
        @kind == :warning && "alert-warning"
      ]}>
        <span>{msg}</span>
      </div>
    </div>
    """
  end

  @doc """
  Renders a card.
  """
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(data-testid)
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["card bg-base-100 shadow-xl", @class]} {@rest}>
      <div class="card-body">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a header with title and subtitle.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-medium leading-8 text-zinc-800">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a Heroicon.
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Shows a DaisyUI modal by adding the modal-open class.
  """
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    JS.add_class(js, "modal-open", to: "##{id}")
  end

  @doc """
  Hides a DaisyUI modal by removing the modal-open class.
  """
  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    JS.remove_class(js, "modal-open", to: "##{id}")
  end

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(McpWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(McpWeb.Gettext, "errors", msg, opts)
    end
  end
end
