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
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
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
    """
  end

  @doc """
  Renders an input field.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :class, :string, default: nil
  attr :required, :boolean, default: false
  attr :accept, :string, default: nil
  attr :options, :list, default: []
  attr :rest, :global

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
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
          "select select-bordered w-full",
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
          "input input-bordered w-full",
          @errors != [] && "input-error",
          @class
        ]}
        required={@required}
        accept={@accept}
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
  attr :on_cancel, :string, default: nil
  slot :inner_block, required: true
  slot :title
  slot :confirm_text
  slot :cancel_text

  def modal(assigns) do
    ~H"""
    <dialog id={@id} class={["modal", @show && "modal-open"]}>
      <div class="modal-box">
        <h3 :if={@title != []} class="font-bold text-lg">{render_slot(@title)}</h3>
        <div class="py-4">
          {render_slot(@inner_block)}
        </div>
        <div class="modal-action">
          <form method="dialog">
            <button class="btn" phx-click={@on_cancel}>
              {render_slot(@cancel_text) || "Cancel"}
            </button>
            <button class="btn btn-primary" phx-click="confirm">
              {render_slot(@confirm_text) || "Confirm"}
            </button>
          </form>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop">
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
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["card bg-base-100 shadow-xl", @class]}>
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
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
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

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(McpWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(McpWeb.Gettext, "errors", msg, opts)
    end
  end
end
