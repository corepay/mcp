defmodule McpWeb.Merchant.Products.CategoriesLive do
  @moduledoc """
  Merchant Categories management page - displays hierarchical category tree with CRUD operations.

  Uses PageLayout with list variant for 2/3 + 1/3 split layout with sidebar.
  Supports nested subcategories, product counts, and drag-drop reordering.
  """
  use McpWeb, :live_view

  alias Phoenix.LiveView.JS

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]

  import McpWeb.Portal.ActionSidebar,
    only: [action_sidebar: 1, sidebar_action: 1]

  import McpWeb.Core.CoreComponents, only: [icon: 1, modal: 1, button: 1, input: 1]

  @impl true
  def mount(_params, _session, socket) do
    categories = get_sample_categories()

    socket =
      socket
      |> assign(:page_title, "Categories")
      |> assign(:categories, categories)
      |> assign(:show_category_modal, false)
      |> assign(:category_form, nil)
      |> assign(:editing_category, nil)
      |> assign(:parent_category_id, nil)
      |> assign(:show_delete_modal, false)
      |> assign(:deleting_category, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout variant={:list} title="Categories" data-testid="page-layout-list">
      <:toolbar>
        <div class="flex-1"></div>
        <.button variant="primary" phx-click="add_category" data-testid="add-category-btn">
          <.icon name="hero-plus" class="size-4" /> Add Category
        </.button>
      </:toolbar>

      <:content>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body p-0">
            <div class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>Category</th>
                    <th class="text-right">Products</th>
                    <th class="text-right">Actions</th>
                  </tr>
                </thead>
                <tbody id="categories-list" phx-hook="Sortable">
                  <%= for category <- @categories do %>
                    <.category_row category={category} level={0} />
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:actions>
            <.sidebar_action
              icon="hero-plus"
              label="Add Category"
              phx-click="add_category"
            />
            <.sidebar_action
              icon="hero-arrow-path"
              label="Refresh"
              phx-click="refresh_categories"
            />
          </:actions>

          <:insights>
            <div class="text-center text-sm text-base-content/50 py-4">
              AI insights coming in Phase 5
            </div>
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>

    <%!-- Category Modal (Create/Edit) --%>
    <div data-testid="category-modal">
      <.modal
        id="category-modal"
        show={@show_category_modal}
        on_cancel={hide_modal("category-modal")}
      >
        <:title>
          {if @editing_category, do: "Edit Category", else: "Add Category"}
        </:title>
        <.form
          for={@category_form}
          id="category-form"
          phx-submit="save_category"
          class="space-y-4"
        >
          <.input
            field={@category_form[:name]}
            label="Category Name"
            placeholder="e.g., Electronics"
            required
          />
          <.input
            field={@category_form[:description]}
            label="Description"
            type="textarea"
            placeholder="Optional description"
          />
          <input type="hidden" name="category[parent_id]" value={@parent_category_id || ""} />
          <input
            type="hidden"
            name="category[id]"
            value={(@editing_category && @editing_category.id) || ""}
          />
          <div class="modal-action">
            <.button variant="ghost" phx-click={hide_modal("category-modal")}>
              Cancel
            </.button>
            <.button type="submit" variant="primary" phx-disable-with="Saving...">
              {if @editing_category, do: "Save Changes", else: "Add Category"}
            </.button>
          </div>
        </.form>
      </.modal>
    </div>

    <%!-- Delete Confirmation Modal --%>
    <.modal
      id="delete-modal"
      show={@show_delete_modal}
      on_cancel={hide_modal("delete-modal")}
    >
      <:title>Delete Category</:title>
      <div class="py-4">
        <%= if @deleting_category && @deleting_category.product_count > 0 do %>
          <div
            class="alert alert-warning mb-4"
            data-testid="delete-warning"
          >
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <span>
              This category contains <strong>{@deleting_category.product_count}</strong> products.
              Deleting this category will not delete the products, but they will become uncategorized.
            </span>
          </div>
        <% end %>
        <p>
          Are you sure you want to delete <strong><%= @deleting_category && @deleting_category.name %></strong>?
        </p>
      </div>
      <div class="modal-action">
        <.button variant="ghost" phx-click={hide_modal("delete-modal")}>
          Cancel
        </.button>
        <.button
          variant="error"
          phx-click="confirm_delete"
          data-testid="confirm-delete"
          phx-disable-with="Deleting..."
        >
          Delete Category
        </.button>
      </div>
    </.modal>
    """
  end

  # Category row component with nesting support
  defp category_row(assigns) do
    ~H"""
    <tr data-testid="category-row" data-id={@category.id} class="hover">
      <td>
        <div class="flex items-center gap-2" style={"padding-left: #{@level * 24}px"}>
          <%= if @level > 0 do %>
            <.icon name="hero-arrow-turn-down-right" class="size-4 text-base-content/40" />
          <% end %>
          <.icon name="hero-folder" class="size-5 text-base-content/60" />
          <span class="font-medium">{@category.name}</span>
        </div>
      </td>
      <td class="text-right">
        <span class="badge badge-ghost" data-testid="category-count">
          {@category.product_count} products
        </span>
      </td>
      <td class="text-right">
        <div class="flex items-center justify-end gap-1">
          <.button
            variant="ghost"
            size="sm"
            phx-click="add_subcategory"
            phx-value-id={@category.id}
            data-testid={"add-subcategory-#{@category.id}"}
            title="Add subcategory"
          >
            <.icon name="hero-plus" class="size-4" />
          </.button>
          <.button
            variant="ghost"
            size="sm"
            phx-click="edit_category"
            phx-value-id={@category.id}
            data-testid={"edit-category-#{@category.id}"}
            title="Edit category"
          >
            <.icon name="hero-pencil" class="size-4" />
          </.button>
          <.button
            variant="ghost"
            size="sm"
            phx-click="delete_category"
            phx-value-id={@category.id}
            data-testid={"delete-category-#{@category.id}"}
            title="Delete category"
          >
            <.icon name="hero-trash" class="size-4 text-error" />
          </.button>
        </div>
      </td>
    </tr>
    <%!-- Render children recursively --%>
    <%= for child <- @category.children do %>
      <.category_row category={child} level={@level + 1} />
    <% end %>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("add_category", _params, socket) do
    form = to_form(%{"name" => "", "description" => ""}, as: :category)

    socket =
      socket
      |> assign(:show_category_modal, true)
      |> assign(:category_form, form)
      |> assign(:editing_category, nil)
      |> assign(:parent_category_id, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_subcategory", %{"id" => parent_id}, socket) do
    form = to_form(%{"name" => "", "description" => ""}, as: :category)

    socket =
      socket
      |> assign(:show_category_modal, true)
      |> assign(:category_form, form)
      |> assign(:editing_category, nil)
      |> assign(:parent_category_id, parent_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_category", %{"id" => category_id}, socket) do
    category = find_category(socket.assigns.categories, category_id)

    form =
      to_form(
        %{
          "name" => category.name,
          "description" => category.description || ""
        },
        as: :category
      )

    socket =
      socket
      |> assign(:show_category_modal, true)
      |> assign(:category_form, form)
      |> assign(:editing_category, category)
      |> assign(:parent_category_id, category.parent_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_category", %{"category" => params}, socket) do
    if socket.assigns.editing_category do
      # Update existing category
      updated_categories =
        update_category_in_tree(
          socket.assigns.categories,
          socket.assigns.editing_category.id,
          params["name"],
          params["description"]
        )

      socket =
        socket
        |> assign(:categories, updated_categories)
        |> assign(:show_category_modal, false)
        |> assign(:category_form, nil)
        |> assign(:editing_category, nil)
        |> put_flash(:info, "Category updated successfully")

      {:noreply, socket}
    else
      # Create new category
      new_category = %{
        id: "new_#{System.unique_integer([:positive])}",
        name: params["name"],
        slug: slugify(params["name"]),
        description: params["description"],
        parent_id: empty_to_nil(params["parent_id"]),
        position: 0,
        product_count: 0,
        children: []
      }

      updated_categories =
        if new_category.parent_id do
          add_subcategory_to_tree(socket.assigns.categories, new_category.parent_id, new_category)
        else
          socket.assigns.categories ++ [new_category]
        end

      socket =
        socket
        |> assign(:categories, updated_categories)
        |> assign(:show_category_modal, false)
        |> assign(:category_form, nil)
        |> assign(:parent_category_id, nil)
        |> put_flash(:info, "Category created successfully")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => category_id}, socket) do
    category = find_category(socket.assigns.categories, category_id)

    socket =
      socket
      |> assign(:show_delete_modal, true)
      |> assign(:deleting_category, category)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    category = socket.assigns.deleting_category

    updated_categories =
      remove_category_from_tree(socket.assigns.categories, category.id)

    socket =
      socket
      |> assign(:categories, updated_categories)
      |> assign(:show_delete_modal, false)
      |> assign(:deleting_category, nil)
      |> put_flash(:info, "Category deleted successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_event("reorder", %{"from" => from, "to" => to}, socket) do
    categories = socket.assigns.categories

    # Simple reorder at top level
    {item, remaining} = List.pop_at(categories, from)
    reordered = List.insert_at(remaining, to, item)

    # Update positions
    updated_categories =
      reordered
      |> Enum.with_index()
      |> Enum.map(fn {cat, idx} -> Map.put(cat, :position, idx) end)

    {:noreply, assign(socket, :categories, updated_categories)}
  end

  @impl true
  def handle_event("refresh_categories", _params, socket) do
    categories = get_sample_categories()
    {:noreply, assign(socket, :categories, categories)}
  end

  # Helper functions

  defp hide_modal(id) do
    JS.remove_class("modal-open", to: "##{id}")
  end

  defp find_category(categories, id) do
    Enum.find_value(categories, fn cat ->
      if cat.id == id do
        cat
      else
        find_category(cat.children, id)
      end
    end)
  end

  defp update_category_in_tree(categories, id, name, description) do
    Enum.map(categories, &update_single_category(&1, id, name, description))
  end

  defp update_single_category(cat, id, name, description) do
    if cat.id == id do
      cat
      |> Map.put(:name, name)
      |> Map.put(:description, description)
    else
      updated_children = update_category_in_tree(cat.children, id, name, description)
      Map.put(cat, :children, updated_children)
    end
  end

  defp add_subcategory_to_tree(categories, parent_id, new_category) do
    Enum.map(categories, &add_to_single_parent(&1, parent_id, new_category))
  end

  defp add_to_single_parent(cat, parent_id, new_category) do
    if cat.id == parent_id do
      Map.update!(cat, :children, fn children -> children ++ [new_category] end)
    else
      updated_children = add_subcategory_to_tree(cat.children, parent_id, new_category)
      Map.put(cat, :children, updated_children)
    end
  end

  defp remove_category_from_tree(categories, id) do
    categories
    |> Enum.reject(fn cat -> cat.id == id end)
    |> Enum.map(fn cat ->
      Map.update!(cat, :children, fn children ->
        remove_category_from_tree(children, id)
      end)
    end)
  end

  defp slugify(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  defp slugify(_), do: ""

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp get_sample_categories do
    [
      %{
        id: "1",
        name: "Electronics",
        slug: "electronics",
        description: "Electronic devices and gadgets",
        parent_id: nil,
        position: 0,
        product_count: 15,
        children: [
          %{
            id: "1a",
            name: "Phones",
            slug: "phones",
            description: "Mobile phones and smartphones",
            parent_id: "1",
            position: 0,
            product_count: 8,
            children: []
          },
          %{
            id: "1b",
            name: "Laptops",
            slug: "laptops",
            description: "Laptop computers",
            parent_id: "1",
            position: 1,
            product_count: 5,
            children: []
          }
        ]
      },
      %{
        id: "2",
        name: "Apparel",
        slug: "apparel",
        description: "Clothing and accessories",
        parent_id: nil,
        position: 1,
        product_count: 0,
        children: []
      },
      %{
        id: "3",
        name: "Home & Garden",
        slug: "home-garden",
        description: "Home improvement and garden supplies",
        parent_id: nil,
        position: 2,
        product_count: 12,
        children: [
          %{
            id: "3a",
            name: "Furniture",
            slug: "furniture",
            description: "Home furniture",
            parent_id: "3",
            position: 0,
            product_count: 7,
            children: []
          }
        ]
      }
    ]
  end
end
