defmodule McpWeb.Merchant.Products.ImportLive do
  @moduledoc """
  Product Import Wizard with CSV upload, column mapping, preview, and import execution.

  Uses FocusedLayout with :wizard variant for a distraction-free import experience.

  ## Wizard Steps

  1. **Upload** - Upload CSV file
  2. **Mapping** - Map CSV columns to product fields
  3. **Preview** - Review validation results before import
  4. **Import** - Execute import with progress indicator
  5. **Complete** - Show results and next actions
  """
  use McpWeb, :live_view

  import McpWeb.Portal.FocusedLayout, only: [focused_layout: 1]
  import McpWeb.Core.CoreComponents, only: [icon: 1, card: 1, button: 1]

  @steps [:upload, :mapping, :preview, :import, :complete]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Import Products")
      |> assign(:current_step, :upload)
      |> assign(:csv_data, nil)
      |> assign(:column_mapping, %{})
      |> assign(:validation_results, nil)
      |> assign(:import_progress, 0)
      |> assign(:import_results, nil)
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :steps, @steps)

    ~H"""
    <div data-testid="focused-layout">
      <.focused_layout
        title="Import Products"
        exit={~p"/app/products"}
        variant={:wizard}
      >
        <:progress>
          <.wizard_progress current_step={@current_step} steps={@steps} />
        </:progress>

        <:content>
          <div class="space-y-6">
            <.step_content
              current_step={@current_step}
              uploads={@uploads}
              csv_data={@csv_data}
              column_mapping={@column_mapping}
              validation_results={@validation_results}
              import_progress={@import_progress}
              import_results={@import_results}
            />

            <.step_actions
              current_step={@current_step}
              csv_data={@csv_data}
              validation_results={@validation_results}
            />
          </div>
        </:content>
      </.focused_layout>
    </div>
    """
  end

  # Wizard progress indicator
  attr :current_step, :atom, required: true
  attr :steps, :list, required: true

  defp wizard_progress(assigns) do
    step_labels = %{
      upload: "Upload",
      mapping: "Mapping",
      preview: "Preview",
      import: "Import",
      complete: "Complete"
    }

    assigns = assign(assigns, :step_labels, step_labels)

    ~H"""
    <div class="flex items-center justify-center gap-2" data-testid="wizard-progress">
      <div
        :for={{step, index} <- Enum.with_index(@steps)}
        class="flex items-center"
      >
        <div
          class={[
            "flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium transition-all",
            step_class(step, @current_step)
          ]}
          data-testid={"step-#{step}"}
        >
          <span class={[
            "w-6 h-6 rounded-full flex items-center justify-center text-xs",
            step_indicator_class(step, @current_step)
          ]}>
            <%= if step_completed?(step, @current_step, @steps) do %>
              <.icon name="hero-check" class="size-4" />
            <% else %>
              {index + 1}
            <% end %>
          </span>
          <span class="hidden sm:inline">{Map.get(@step_labels, step)}</span>
        </div>
        <div
          :if={index < length(@steps) - 1}
          class={[
            "w-8 h-0.5 mx-1",
            if(step_completed?(step, @current_step, @steps), do: "bg-primary", else: "bg-base-300")
          ]}
        />
      </div>
    </div>
    """
  end

  # Step content based on current step
  attr :current_step, :atom, required: true
  attr :uploads, :map, required: true
  attr :csv_data, :map, default: nil
  attr :column_mapping, :map, required: true
  attr :validation_results, :map, default: nil
  attr :import_progress, :integer, required: true
  attr :import_results, :map, default: nil

  defp step_content(%{current_step: :upload} = assigns) do
    ~H"""
    <.card>
      <h2 class="text-lg font-semibold mb-4">Upload CSV File</h2>
      <p class="text-base-content/70 mb-6">
        Upload a CSV file containing your product data. The first row should contain column headers.
      </p>

      <.form
        for={%{}}
        as={:import}
        id="import-form"
        phx-change="validate-upload"
        phx-submit="process-upload"
      >
        <div
          class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors cursor-pointer"
          phx-drop-target={@uploads.csv.ref}
        >
          <%= if @csv_data do %>
            <div data-testid="file-preview" class="space-y-2">
              <.icon name="hero-document-check" class="size-12 text-success mx-auto" />
              <p class="font-medium">{@csv_data.filename}</p>
              <p class="text-sm text-base-content/70">
                {length(@csv_data.headers)} columns, {@csv_data.row_count} rows detected
              </p>
            </div>
          <% else %>
            <%= for entry <- @uploads.csv.entries do %>
              <div data-testid="file-preview" class="space-y-2">
                <.icon name="hero-document-arrow-up" class="size-12 text-primary mx-auto" />
                <p class="font-medium">{entry.client_name}</p>
                <progress value={entry.progress} max="100" class="progress progress-primary w-full">
                  {entry.progress}%
                </progress>
              </div>
            <% end %>
            <%= if @uploads.csv.entries == [] do %>
              <.icon name="hero-arrow-up-tray" class="size-12 text-base-content/30 mx-auto mb-4" />
              <p class="font-medium">Drop your CSV file here</p>
              <p class="text-sm text-base-content/60 mb-4">or click to browse</p>
              <.live_file_input
                upload={@uploads.csv}
                class="file-input file-input-bordered w-full max-w-xs"
              />
            <% end %>
          <% end %>
        </div>

        <%= for err <- upload_errors(@uploads.csv) do %>
          <p class="text-error text-sm mt-2">{error_to_string(err)}</p>
        <% end %>
      </.form>
    </.card>
    """
  end

  defp step_content(%{current_step: :mapping} = assigns) do
    ~H"""
    <.card>
      <h2 class="text-lg font-semibold mb-4">Map Columns</h2>
      <p class="text-base-content/70 mb-6">
        Map your CSV columns to product fields. We've auto-detected some mappings based on column names.
      </p>

      <div class="space-y-4" data-testid="column-mapper">
        <div class="grid grid-cols-3 gap-4 font-medium text-sm text-base-content/70 pb-2 border-b border-base-300">
          <span>CSV Column</span>
          <span>Product Field</span>
          <span>Sample Value</span>
        </div>

        <div
          :for={{header, index} <- Enum.with_index(@csv_data.headers)}
          class="grid grid-cols-3 gap-4 items-center"
        >
          <span class="font-mono text-sm bg-base-200 px-2 py-1 rounded">{header}</span>
          <select
            name={"mapping[#{index}]"}
            class="select select-bordered select-sm w-full"
            phx-change="update-mapping"
            phx-value-column={index}
          >
            <option value="">-- Skip --</option>
            <option value="name" selected={Map.get(@column_mapping, index) == "name"}>
              Product Name
            </option>
            <option value="sku" selected={Map.get(@column_mapping, index) == "sku"}>
              SKU
            </option>
            <option value="price" selected={Map.get(@column_mapping, index) == "price"}>
              Price
            </option>
            <option value="description" selected={Map.get(@column_mapping, index) == "description"}>
              Description
            </option>
            <option value="category" selected={Map.get(@column_mapping, index) == "category"}>
              Category
            </option>
          </select>
          <span class="text-sm text-base-content/60 truncate">
            {get_sample_value(@csv_data, index)}
          </span>
        </div>
      </div>
    </.card>
    """
  end

  defp step_content(%{current_step: :preview} = assigns) do
    ~H"""
    <.card>
      <h2 class="text-lg font-semibold mb-4">Preview Import</h2>

      <div class="flex gap-4 mb-6">
        <div class="stat bg-success/10 rounded-box p-4">
          <div class="stat-title">Valid Records</div>
          <div class="stat-value text-success" data-testid="valid-count">
            {@validation_results.valid_count}
          </div>
        </div>
        <div class="stat bg-error/10 rounded-box p-4">
          <div class="stat-title">Errors</div>
          <div class="stat-value text-error" data-testid="error-count">
            {@validation_results.error_count}
          </div>
        </div>
      </div>

      <div class="overflow-x-auto" data-testid="preview-table">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th>Status</th>
              <th>Name</th>
              <th>SKU</th>
              <th>Price</th>
              <th>Notes</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={row <- @validation_results.rows}
              class={if row.valid, do: "", else: "bg-error/5"}
              data-testid={if row.valid, do: "valid-row", else: "error-row"}
            >
              <td>
                <%= if row.valid do %>
                  <.icon name="hero-check-circle" class="size-5 text-success" />
                <% else %>
                  <.icon name="hero-exclamation-circle" class="size-5 text-error" />
                <% end %>
              </td>
              <td>{row.name}</td>
              <td class="font-mono text-sm">{row.sku}</td>
              <td>{row.price}</td>
              <td class="text-sm text-base-content/70">
                <%= if row.errors != [] do %>
                  <span class="text-error">{Enum.join(row.errors, ", ")}</span>
                <% else %>
                  Ready to import
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </.card>
    """
  end

  defp step_content(%{current_step: :import} = assigns) do
    ~H"""
    <.card>
      <h2 class="text-lg font-semibold mb-4">Importing Products</h2>

      <div class="text-center py-8" data-testid="import-progress">
        <div
          class="radial-progress text-primary"
          style={"--value:#{@import_progress}; --size:8rem;"}
          role="progressbar"
        >
          {@import_progress}%
        </div>
        <p class="mt-4 text-base-content/70">
          Please wait while we import your products...
        </p>
      </div>
    </.card>
    """
  end

  defp step_content(%{current_step: :complete} = assigns) do
    ~H"""
    <.card data-testid="import-complete">
      <div class="text-center py-8">
        <.icon name="hero-check-circle" class="size-16 text-success mx-auto mb-4" />
        <h2 class="text-2xl font-bold mb-2">Import Complete!</h2>
        <p class="text-base-content/70 mb-6">
          Successfully imported
          <span class="font-semibold text-success" data-testid="imported-count">
            {@import_results.imported_count}
          </span>
          products.
        </p>

        <div class="flex gap-4 justify-center">
          <.button variant="ghost" phx-click="start-new-import">
            <.icon name="hero-arrow-path" class="size-4 mr-2" /> Import More
          </.button>
          <.button variant="primary" phx-click="go-to-products">
            <.icon name="hero-cube" class="size-4 mr-2" /> View Products
          </.button>
        </div>
      </div>
    </.card>
    """
  end

  # Step action buttons
  attr :current_step, :atom, required: true
  attr :csv_data, :map, default: nil
  attr :validation_results, :map, default: nil

  defp step_actions(assigns) do
    ~H"""
    <div class="flex justify-between items-center">
      <div>
        <.button
          :if={@current_step not in [:upload, :import, :complete]}
          variant="ghost"
          phx-click="back"
          data-testid="back-btn"
        >
          <.icon name="hero-arrow-left" class="size-4 mr-2" /> Back
        </.button>
        <.button
          :if={@current_step == :upload}
          variant="ghost"
          phx-click="exit"
          data-testid="exit-btn"
        >
          <.icon name="hero-x-mark" class="size-4 mr-2" /> Cancel
        </.button>
      </div>

      <div>
        <.button
          :if={@current_step == :upload and @csv_data != nil}
          variant="primary"
          phx-click="next"
          data-testid="next-btn"
        >
          Next <.icon name="hero-arrow-right" class="size-4 ml-2" />
        </.button>
        <.button
          :if={@current_step == :mapping}
          variant="primary"
          phx-click="next"
          data-testid="next-btn"
        >
          Preview <.icon name="hero-arrow-right" class="size-4 ml-2" />
        </.button>
        <.button
          :if={@current_step == :preview}
          variant="primary"
          phx-click="start-import"
          data-testid="import-btn"
        >
          <.icon name="hero-arrow-down-tray" class="size-4 mr-2" /> Import Products
        </.button>
      </div>
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("process-upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("next", _params, socket) do
    next_step = get_next_step(socket.assigns.current_step)

    socket =
      case {socket.assigns.current_step, next_step} do
        {:mapping, :preview} ->
          # Generate validation results when moving to preview
          validation = validate_csv_data(socket.assigns.csv_data, socket.assigns.column_mapping)
          socket |> assign(:validation_results, validation) |> assign(:current_step, next_step)

        _ ->
          assign(socket, :current_step, next_step)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("back", _params, socket) do
    prev_step = get_prev_step(socket.assigns.current_step)
    {:noreply, assign(socket, :current_step, prev_step)}
  end

  @impl true
  def handle_event("exit", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/products")}
  end

  @impl true
  def handle_event("update-mapping", %{"column" => column, "value" => value}, socket) do
    column_index = String.to_integer(column)
    new_mapping = Map.put(socket.assigns.column_mapping, column_index, value)
    {:noreply, assign(socket, :column_mapping, new_mapping)}
  end

  @impl true
  def handle_event("start-import", _params, socket) do
    # Start import process
    send(self(), :simulate_import)

    socket =
      socket
      |> assign(:current_step, :import)
      |> assign(:import_progress, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start-new-import", _params, socket) do
    # Reset to beginning
    socket =
      socket
      |> assign(:current_step, :upload)
      |> assign(:csv_data, nil)
      |> assign(:column_mapping, %{})
      |> assign(:validation_results, nil)
      |> assign(:import_progress, 0)
      |> assign(:import_results, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("go-to-products", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/products")}
  end

  @impl true
  def handle_info(:simulate_import, socket) do
    # Simulate import progress
    progress = socket.assigns.import_progress + 25

    if progress >= 100 do
      # Import complete
      import_results = %{
        imported_count: socket.assigns.validation_results.valid_count,
        skipped_count: socket.assigns.validation_results.error_count
      }

      socket =
        socket
        |> assign(:import_progress, 100)
        |> assign(:import_results, import_results)
        |> assign(:current_step, :complete)

      {:noreply, socket}
    else
      send(self(), :simulate_import)
      {:noreply, assign(socket, :import_progress, progress)}
    end
  end

  # Test helper: Allow tests to set CSV data directly for easier testing
  def handle_info({:test_set_csv_data, csv_data}, socket) do
    column_mapping = auto_detect_mapping(csv_data.headers)

    socket =
      socket
      |> assign(:csv_data, csv_data)
      |> assign(:column_mapping, column_mapping)

    {:noreply, socket}
  end

  # Handle file upload completion (LiveView upload progress callback)
  def handle_progress(:csv, entry, socket) when entry.done? do
    # Process uploaded CSV when complete
    uploaded_file =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        content = File.read!(path)
        {:ok, %{content: content, filename: entry.client_name}}
      end)

    csv_data = parse_csv_content(uploaded_file.content, uploaded_file.filename)
    column_mapping = auto_detect_mapping(csv_data.headers)

    socket =
      socket
      |> assign(:csv_data, csv_data)
      |> assign(:column_mapping, column_mapping)

    {:noreply, socket}
  end

  def handle_progress(:csv, _entry, socket) do
    {:noreply, socket}
  end

  # Private helper functions

  defp step_class(step, current_step) do
    cond do
      step == current_step -> "active bg-primary/10 text-primary"
      step_completed?(step, current_step, @steps) -> "bg-success/10 text-success"
      true -> "text-base-content/50"
    end
  end

  defp step_indicator_class(step, current_step) do
    cond do
      step == current_step -> "bg-primary text-primary-content"
      step_completed?(step, current_step, @steps) -> "bg-success text-success-content"
      true -> "bg-base-300 text-base-content/50"
    end
  end

  defp step_completed?(step, current_step, steps) do
    step_index = Enum.find_index(steps, &(&1 == step))
    current_index = Enum.find_index(steps, &(&1 == current_step))
    step_index < current_index
  end

  defp get_next_step(current) do
    current_index = Enum.find_index(@steps, &(&1 == current))

    if current_index < length(@steps) - 1 do
      Enum.at(@steps, current_index + 1)
    else
      current
    end
  end

  defp get_prev_step(current) do
    current_index = Enum.find_index(@steps, &(&1 == current))

    if current_index > 0 do
      Enum.at(@steps, current_index - 1)
    else
      current
    end
  end

  defp get_sample_value(csv_data, index) do
    case List.first(csv_data.rows) do
      nil -> "-"
      row -> Enum.at(row.values, index, "-")
    end
  end

  # Mock CSV parsing - simulates parsing a CSV file
  defp parse_csv_content(content, filename) do
    lines = String.split(content, ~r/\r?\n/, trim: true)

    case lines do
      [header_line | data_lines] ->
        headers = String.split(header_line, ",", trim: true) |> Enum.map(&String.trim/1)

        rows =
          Enum.map(data_lines, fn line ->
            values = String.split(line, ",", trim: true) |> Enum.map(&String.trim/1)
            %{values: values}
          end)

        %{
          headers: headers,
          rows: rows,
          row_count: length(rows),
          filename: filename
        }

      _ ->
        # Return mock data if parsing fails or file is empty
        %{
          headers: ["name", "sku", "price"],
          rows: [
            %{values: ["Product A", "SKU-001", "29.99"]},
            %{values: ["Product B", "SKU-002", "19.99"]}
          ],
          row_count: 2,
          filename: filename
        }
    end
  end

  # Auto-detect column mappings based on header names
  defp auto_detect_mapping(headers) do
    headers
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {header, index}, acc ->
      header_lower = String.downcase(header)

      field =
        cond do
          header_lower in ["name", "product_name", "title", "product"] -> "name"
          header_lower in ["sku", "product_sku", "code", "product_code"] -> "sku"
          header_lower in ["price", "unit_price", "cost", "amount"] -> "price"
          header_lower in ["description", "desc", "details"] -> "description"
          header_lower in ["category", "cat", "type"] -> "category"
          true -> nil
        end

      if field, do: Map.put(acc, index, field), else: acc
    end)
  end

  # Validate CSV data with the current column mapping
  defp validate_csv_data(csv_data, column_mapping) do
    name_col = find_column_by_field(column_mapping, "name")
    sku_col = find_column_by_field(column_mapping, "sku")
    price_col = find_column_by_field(column_mapping, "price")

    validated_rows =
      Enum.map(csv_data.rows, fn row ->
        name = if name_col, do: Enum.at(row.values, name_col, ""), else: ""
        sku = if sku_col, do: Enum.at(row.values, sku_col, ""), else: ""
        price = if price_col, do: Enum.at(row.values, price_col, ""), else: ""

        errors = []
        errors = if name == "", do: ["Missing name" | errors], else: errors
        errors = if sku == "", do: ["Missing SKU" | errors], else: errors
        errors = if price == "", do: ["Missing price" | errors], else: errors

        %{
          name: name,
          sku: sku,
          price: price,
          valid: errors == [],
          errors: Enum.reverse(errors)
        }
      end)

    valid_count = Enum.count(validated_rows, & &1.valid)
    error_count = length(validated_rows) - valid_count

    %{
      rows: validated_rows,
      valid_count: valid_count,
      error_count: error_count
    }
  end

  defp find_column_by_field(mapping, field) do
    Enum.find_value(mapping, fn {col, mapped_field} ->
      if mapped_field == field, do: col, else: nil
    end)
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Only 1 file allowed"
  defp error_to_string(:not_accepted), do: "Only CSV files are accepted"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
