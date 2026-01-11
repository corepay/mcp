defmodule McpWeb.Merchant.Products.NewLive do
  @moduledoc """
  Merchant Product Create page.

  Multi-section create form with:
  - Basic Info: name, sku, category_id, status, description
  - Media: Main image upload with preview, gallery images
  - Pricing: price, compare_at_price, cost
  - Inventory: track_inventory checkbox, quantity_on_hand, low_stock_threshold

  Uses PageLayout with `:detail` variant for 2/3 + 1/3 split layout.
  - Main content: Multi-section create form
  - Sidebar: Tips and form validation status
  """
  use McpWeb, :live_view

  import McpWeb.Portal.PageLayout, only: [page_layout: 1]
  import McpWeb.Portal.ActionSidebar, only: [action_sidebar: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, input: 1, button: 1]

  @impl true
  def mount(_params, _session, socket) do
    categories = get_mock_categories()

    form =
      to_form(
        %{
          "name" => "",
          "sku" => "",
          "description" => "",
          "price" => "",
          "compare_at_price" => "",
          "cost" => "",
          "status" => "draft",
          "category_id" => "",
          "track_inventory" => "false",
          "quantity_on_hand" => "0",
          "low_stock_threshold" => "10"
        },
        as: :product
      )

    socket =
      socket
      |> assign(:page_title, "New Product")
      |> assign(:form, form)
      |> assign(:categories, categories)
      |> assign(:errors, %{})
      |> assign(:uploaded_image, nil)
      |> allow_upload(:image,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 1,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout
      variant={:detail}
      title="New Product"
      back={~p"/app/products"}
      data-testid="page-layout-detail"
    >
      <:content>
        <.form
          for={@form}
          id="product-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-6"
        >
          <%!-- Basic Info Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Basic Information</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input
                field={@form[:name]}
                label="Product Name"
                placeholder="Enter product name"
                required
              />
              <.input
                field={@form[:sku]}
                label="SKU"
                placeholder="e.g., PROD-001"
                required
              />
              <div class="form-control w-full">
                <label class="label" for="product_category_id">
                  <span class="label-text">Category</span>
                </label>
                <select
                  id="product_category_id"
                  name="product[category_id]"
                  class="select select-bordered w-full focus:outline-none"
                >
                  <option value="">Select category</option>
                  <option
                    :for={c <- @categories}
                    value={c.id}
                    selected={@form[:category_id].value == c.id}
                  >
                    {c.name}
                  </option>
                </select>
              </div>
              <div class="form-control w-full">
                <label class="label" for="product_status">
                  <span class="label-text">Status</span>
                </label>
                <select
                  id="product_status"
                  name="product[status]"
                  class="select select-bordered w-full focus:outline-none"
                >
                  <option value="draft" selected={@form[:status].value == "draft"}>Draft</option>
                  <option value="active" selected={@form[:status].value == "active"}>Active</option>
                  <option value="archived" selected={@form[:status].value == "archived"}>
                    Archived
                  </option>
                </select>
              </div>
            </div>
            <div class="mt-4">
              <.input
                field={@form[:description]}
                label="Description"
                type="textarea"
                placeholder="Describe your product..."
              />
            </div>
          </.card>

          <%!-- Media Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Media</h3>
            <div class="space-y-4">
              <div class="flex items-start gap-6">
                <%!-- Image Upload Area --%>
                <div
                  class="w-48 h-48 border-2 border-dashed border-base-300 rounded-lg flex flex-col items-center justify-center cursor-pointer hover:border-primary transition-colors"
                  phx-drop-target={@uploads.image.ref}
                >
                  <%= if @uploaded_image do %>
                    <img
                      src={@uploaded_image}
                      alt="Product preview"
                      class="w-full h-full object-cover rounded-lg"
                      data-testid="image-preview"
                    />
                  <% else %>
                    <%= for entry <- @uploads.image.entries do %>
                      <div class="relative w-full h-full" data-testid="image-preview">
                        <.live_img_preview
                          entry={entry}
                          class="w-full h-full object-cover rounded-lg"
                        />
                        <button
                          type="button"
                          class="absolute top-1 right-1 btn btn-circle btn-xs btn-error"
                          phx-click="cancel-upload"
                          phx-value-ref={entry.ref}
                        >
                          <.icon name="hero-x-mark" class="size-3" />
                        </button>
                        <progress
                          value={entry.progress}
                          max="100"
                          class="absolute bottom-0 w-full"
                        >
                          {entry.progress}%
                        </progress>
                      </div>
                    <% end %>
                    <%= if @uploads.image.entries == [] do %>
                      <.icon name="hero-photo" class="size-12 text-base-content/30 mb-2" />
                      <span class="text-sm text-base-content/60">Drop image here</span>
                      <span class="text-xs text-base-content/40">or click to upload</span>
                    <% end %>
                  <% end %>
                </div>
                <div class="flex-1">
                  <label class="label">
                    <span class="label-text">Main Product Image</span>
                  </label>
                  <.live_file_input
                    upload={@uploads.image}
                    class="file-input file-input-bordered w-full"
                  />
                  <p class="text-xs text-base-content/60 mt-2">
                    Accepts: JPG, PNG, GIF, WebP. Max size: 10MB
                  </p>
                  <%= for err <- upload_errors(@uploads.image) do %>
                    <p class="text-error text-sm mt-1">{error_to_string(err)}</p>
                  <% end %>
                </div>
              </div>
            </div>
          </.card>

          <%!-- Pricing Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Pricing</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="form-control w-full">
                <label class="label" for="product_price">
                  <span class="label-text">Price</span>
                </label>
                <input
                  type="number"
                  id="product_price"
                  name="product[price]"
                  value={@form[:price].value}
                  step="0.01"
                  min="0"
                  placeholder="0.00"
                  required
                  class="input input-bordered w-full focus:outline-none"
                />
              </div>
              <div class="form-control w-full">
                <label class="label" for="product_compare_at_price">
                  <span class="label-text">Compare at Price</span>
                </label>
                <input
                  type="number"
                  id="product_compare_at_price"
                  name="product[compare_at_price]"
                  value={@form[:compare_at_price].value}
                  step="0.01"
                  min="0"
                  placeholder="0.00"
                  class="input input-bordered w-full focus:outline-none"
                />
              </div>
              <div class="form-control w-full">
                <label class="label" for="product_cost">
                  <span class="label-text">Cost</span>
                </label>
                <input
                  type="number"
                  id="product_cost"
                  name="product[cost]"
                  value={@form[:cost].value}
                  step="0.01"
                  min="0"
                  placeholder="0.00"
                  class="input input-bordered w-full focus:outline-none"
                />
              </div>
            </div>
          </.card>

          <%!-- Inventory Section --%>
          <.card>
            <h3 class="text-lg font-semibold mb-4">Inventory</h3>
            <div class="space-y-4">
              <div class="form-control">
                <label class="label cursor-pointer justify-start gap-4">
                  <input
                    type="checkbox"
                    name="product[track_inventory]"
                    value="true"
                    checked={@form[:track_inventory].value == "true"}
                    class="checkbox checkbox-primary"
                    phx-update="ignore"
                    id="product_track_inventory"
                  />
                  <span class="label-text">Track inventory for this product</span>
                </label>
              </div>
              <%= if @form[:track_inventory].value == "true" do %>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 pl-10">
                  <div class="form-control w-full">
                    <label class="label" for="product_quantity_on_hand">
                      <span class="label-text">Quantity on Hand</span>
                    </label>
                    <input
                      type="number"
                      id="product_quantity_on_hand"
                      name="product[quantity_on_hand]"
                      value={@form[:quantity_on_hand].value}
                      min="0"
                      placeholder="0"
                      class="input input-bordered w-full focus:outline-none"
                    />
                  </div>
                  <div class="form-control w-full">
                    <label class="label" for="product_low_stock_threshold">
                      <span class="label-text">Low Stock Threshold</span>
                    </label>
                    <input
                      type="number"
                      id="product_low_stock_threshold"
                      name="product[low_stock_threshold]"
                      value={@form[:low_stock_threshold].value}
                      min="0"
                      placeholder="10"
                      class="input input-bordered w-full focus:outline-none"
                    />
                  </div>
                </div>
              <% end %>
            </div>
          </.card>

          <%!-- Form Actions (visible on mobile, hidden on desktop - desktop uses toolbar) --%>
          <div class="lg:hidden flex gap-2 justify-end">
            <.button variant="ghost" type="button" phx-click="cancel" data-testid="cancel-btn-mobile">
              Cancel
            </.button>
            <.button variant="primary" type="submit" phx-disable-with="Creating...">
              <.icon name="hero-check" class="size-4 mr-2" /> Create Product
            </.button>
          </div>
        </.form>
      </:content>

      <:sidebar>
        <.action_sidebar data-testid="action-sidebar">
          <:actions>
            <.button
              variant="ghost"
              type="button"
              phx-click="cancel"
              data-testid="cancel-btn"
              class="w-full justify-start"
            >
              <.icon name="hero-x-mark" class="size-4 mr-2" /> Cancel
            </.button>
            <.button
              variant="primary"
              type="submit"
              form="product-form"
              phx-disable-with="Creating..."
              class="w-full justify-start"
            >
              <.icon name="hero-check" class="size-4 mr-2" /> Create Product
            </.button>
          </:actions>

          <:insights>
            <div class="bg-base-200 rounded-box p-4">
              <h4 class="font-medium text-sm mb-2">Tips</h4>
              <ul class="text-sm text-base-content/70 space-y-2">
                <li class="flex gap-2">
                  <.icon name="hero-light-bulb" class="size-4 shrink-0 mt-0.5 text-warning" />
                  <span>Use clear, descriptive product names</span>
                </li>
                <li class="flex gap-2">
                  <.icon name="hero-light-bulb" class="size-4 shrink-0 mt-0.5 text-warning" />
                  <span>Add high-quality images for better conversion</span>
                </li>
                <li class="flex gap-2">
                  <.icon name="hero-light-bulb" class="size-4 shrink-0 mt-0.5 text-warning" />
                  <span>Set a low stock threshold to get alerts</span>
                </li>
              </ul>
            </div>
            <div class="text-center text-sm text-base-content/50 py-4">
              AI insights coming in Phase 5
            </div>
          </:insights>
        </.action_sidebar>
      </:sidebar>
    </.page_layout>
    """
  end

  @impl true
  def handle_event("validate", %{"product" => params}, socket) do
    errors = validate_params(params)

    form =
      params
      |> to_form(as: :product, errors: format_errors_for_form(errors))

    {:noreply, assign(socket, form: form, errors: errors)}
  end

  @impl true
  def handle_event("save", %{"product" => params}, socket) do
    errors = validate_params(params, require_all: true)

    if errors == %{} do
      # Handle image uploads first
      uploaded_files =
        consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
          # For mock: just return a fake URL path
          # In production: upload to S3/MinIO
          filename = Path.basename(path)
          {:ok, "/uploads/#{filename}"}
        end)

      # In production, would merge image_url into params before saving
      _params_with_image =
        case uploaded_files do
          [url | _] -> Map.put(params, "image_url", url)
          [] -> params
        end

      # Mock product creation - generate a fake ID
      product_id = "prod_#{System.unique_integer([:positive])}"

      socket =
        socket
        |> put_flash(:info, "Product created successfully")
        |> push_navigate(to: ~p"/app/products/#{product_id}")

      {:noreply, socket}
    else
      form =
        params
        |> to_form(as: :product, errors: format_errors_for_form(errors))

      {:noreply, assign(socket, form: form, errors: errors)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/products")}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  # Private helpers

  defp get_mock_categories do
    [
      %{id: "cat_1", name: "Electronics"},
      %{id: "cat_2", name: "Accessories"},
      %{id: "cat_3", name: "Clothing"},
      %{id: "cat_4", name: "Food & Beverage"}
    ]
  end

  defp validate_params(params, opts \\ []) do
    require_all = Keyword.get(opts, :require_all, false)

    %{}
    |> validate_required_field(params, "name", :name, require_all)
    |> validate_required_field(params, "sku", :sku, require_all)
    |> validate_required_on_submit(params, "price", :price, require_all)
  end

  defp validate_required_field(errors, params, param_key, error_key, require_all) do
    value = params[param_key] || ""
    is_empty = String.trim(value) == ""
    field_provided = Map.has_key?(params, param_key)

    if (require_all and is_empty) or (field_provided and is_empty) do
      Map.put(errors, error_key, "is required")
    else
      errors
    end
  end

  defp validate_required_on_submit(errors, params, param_key, error_key, require_all) do
    value = params[param_key] || ""

    if require_all and String.trim(value) == "" do
      Map.put(errors, error_key, "is required")
    else
      errors
    end
  end

  defp format_errors_for_form(errors) do
    Enum.map(errors, fn {field, message} ->
      {field, {message, []}}
    end)
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Only 1 file allowed"
  defp error_to_string(:not_accepted), do: "Invalid file type"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
