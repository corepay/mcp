# OLA Phase 1: Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract OLA domain from Underwriting, build schema-driven renderer, prove with existing merchant flow

**Architecture:** Create `Mcp.Ola` domain with `ApplicationType` (schema definition) and `ApplicationInstance` (runtime). Build dynamic renderer that generates UI from schema. Migrate current hardcoded merchant wizard to use new system.

**Tech Stack:** Ash Framework, Phoenix LiveView, PostgreSQL (JSONB for schemas)

---

## Current State Summary

| Component | Location | Purpose |
|-----------|----------|---------|
| Application resource | `lib/mcp/underwriting/resources/application.ex` | Stores submitted applications |
| ApplicationLive | `lib/mcp_web/live/ola/application_live.ex` | 4-step hardcoded wizard |
| Template | `lib/mcp_web/live/ola/application_live.html.heex` | Hardcoded form HTML |
| Atlas context | `lib/mcp/underwriting/atlas/conversation_context.ex` | AI context with hardcoded fields |
| SubmissionService | `lib/mcp/underwriting/services/submission_service.ex` | Creates application, triggers screening |

## Target State

```
lib/mcp/ola/                          # NEW DOMAIN
├── ola.ex                            # Domain module
├── resources/
│   ├── application_type.ex           # Schema definition
│   └── application_instance.ex       # Runtime application
├── form_schema.ex                    # Embedded schema for form definition
└── renderer/
    ├── schema_parser.ex              # Parse and validate schemas
    ├── condition_evaluator.ex        # Evaluate show_when/require_when
    └── component_mapper.ex           # Map field types to components

lib/mcp_web/live/ola/
├── application_live.ex               # REFACTORED to use renderer
├── components/
│   └── fields/                       # NEW dynamic field components
│       ├── text_field.ex
│       ├── select_field.ex
│       └── ...
```

---

## Task 1: Create Ola Domain Module

**Files:**
- Create: `lib/mcp/ola/ola.ex`
- Create: `test/mcp/ola/ola_test.exs`

**Step 1: Write the domain test**

```elixir
# test/mcp/ola/ola_test.exs
defmodule Mcp.OlaTest do
  use Mcp.DataCase, async: true

  describe "domain" do
    test "Mcp.Ola is a valid Ash domain" do
      assert {:ok, _} = Spark.Info.dsl(Mcp.Ola)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/ola/ola_test.exs`
Expected: FAIL with "module Mcp.Ola is not available"

**Step 3: Create the domain module**

```elixir
# lib/mcp/ola/ola.ex
defmodule Mcp.Ola do
  @moduledoc """
  Domain for Online Application (OLA) functionality.
  Provides schema-driven application forms and dynamic rendering.
  """
  use Ash.Domain

  resources do
    # Resources will be added in subsequent tasks
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/ola/ola_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/ola/ola.ex test/mcp/ola/ola_test.exs
git commit -m "feat(ola): add Mcp.Ola domain module"
```

---

## Task 2: Create FormSchema Embedded Schema

**Files:**
- Create: `lib/mcp/ola/form_schema.ex`
- Create: `test/mcp/ola/form_schema_test.exs`

**Step 1: Write tests for FormSchema**

```elixir
# test/mcp/ola/form_schema_test.exs
defmodule Mcp.Ola.FormSchemaTest do
  use ExUnit.Case, async: true

  alias Mcp.Ola.FormSchema

  describe "field types" do
    test "all supported field types are defined" do
      types = FormSchema.supported_field_types()

      assert :text in types
      assert :email in types
      assert :phone in types
      assert :select in types
      assert :address in types
      assert :document in types
      assert :signature in types
    end
  end

  describe "validation" do
    test "valid schema passes validation" do
      schema = %{
        "ux_mode" => "wizard",
        "steps" => [
          %{
            "id" => "step_1",
            "label" => "Business Info",
            "fields" => [
              %{"id" => "business_name", "type" => "text", "label" => "Business Name", "required" => true}
            ]
          }
        ]
      }

      assert {:ok, _} = FormSchema.validate(schema)
    end

    test "schema without steps fails validation" do
      schema = %{"ux_mode" => "wizard"}

      assert {:error, errors} = FormSchema.validate(schema)
      assert "steps is required" in errors
    end

    test "step without id fails validation" do
      schema = %{
        "steps" => [%{"label" => "No ID", "fields" => []}]
      }

      assert {:error, errors} = FormSchema.validate(schema)
      assert Enum.any?(errors, &String.contains?(&1, "id"))
    end

    test "field with invalid type fails validation" do
      schema = %{
        "steps" => [
          %{
            "id" => "step_1",
            "label" => "Test",
            "fields" => [
              %{"id" => "f1", "type" => "invalid_type", "label" => "Test"}
            ]
          }
        ]
      }

      assert {:error, errors} = FormSchema.validate(schema)
      assert Enum.any?(errors, &String.contains?(&1, "invalid_type"))
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/ola/form_schema_test.exs`
Expected: FAIL with "module Mcp.Ola.FormSchema is not available"

**Step 3: Create FormSchema module**

```elixir
# lib/mcp/ola/form_schema.ex
defmodule Mcp.Ola.FormSchema do
  @moduledoc """
  Defines and validates the structure of an application form schema.
  Used by ApplicationType to define form structure.
  """

  @supported_field_types ~w(
    text textarea email phone date currency percentage
    select radio checkbox checkboxes
    address ssn ein document signature
    repeater calculated hidden
  )a

  @doc "Returns list of all supported field types"
  def supported_field_types, do: @supported_field_types

  @doc """
  Validates a form schema map.
  Returns {:ok, schema} or {:error, [error_messages]}
  """
  def validate(schema) when is_map(schema) do
    errors = []
    |> validate_steps(schema)
    |> validate_ux_mode(schema)

    case errors do
      [] -> {:ok, schema}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  def validate(_), do: {:error, ["schema must be a map"]}

  defp validate_steps(errors, %{"steps" => steps}) when is_list(steps) do
    step_errors =
      steps
      |> Enum.with_index()
      |> Enum.flat_map(fn {step, idx} -> validate_step(step, idx) end)

    step_errors ++ errors
  end

  defp validate_steps(errors, _), do: ["steps is required" | errors]

  defp validate_step(step, idx) when is_map(step) do
    errors = []

    errors = if Map.has_key?(step, "id"), do: errors, else: ["step #{idx}: id is required" | errors]
    errors = if Map.has_key?(step, "label"), do: errors, else: ["step #{idx}: label is required" | errors]

    field_errors =
      step
      |> Map.get("fields", [])
      |> Enum.with_index()
      |> Enum.flat_map(fn {field, fidx} -> validate_field(field, idx, fidx) end)

    field_errors ++ errors
  end

  defp validate_step(_, idx), do: ["step #{idx}: must be a map"]

  defp validate_field(field, step_idx, field_idx) when is_map(field) do
    errors = []
    prefix = "step #{step_idx}, field #{field_idx}"

    errors = if Map.has_key?(field, "id"), do: errors, else: ["#{prefix}: id is required" | errors]
    errors = if Map.has_key?(field, "label"), do: errors, else: ["#{prefix}: label is required" | errors]

    type = Map.get(field, "type")
    type_atom = if is_binary(type), do: String.to_atom(type), else: type

    errors =
      if type_atom in @supported_field_types do
        errors
      else
        ["#{prefix}: invalid type '#{type}'" | errors]
      end

    errors
  end

  defp validate_field(_, step_idx, field_idx), do: ["step #{step_idx}, field #{field_idx}: must be a map"]

  defp validate_ux_mode(errors, %{"ux_mode" => mode}) when mode in ["wizard", "single_page", "conversational", "hybrid"] do
    errors
  end

  defp validate_ux_mode(errors, %{"ux_mode" => mode}) do
    ["invalid ux_mode '#{mode}'" | errors]
  end

  defp validate_ux_mode(errors, _), do: errors  # ux_mode is optional, defaults to wizard
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/ola/form_schema_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/ola/form_schema.ex test/mcp/ola/form_schema_test.exs
git commit -m "feat(ola): add FormSchema validation module"
```

---

## Task 3: Create ApplicationType Resource

**Files:**
- Create: `lib/mcp/ola/resources/application_type.ex`
- Modify: `lib/mcp/ola/ola.ex` (add resource)
- Create: `priv/repo/migrations/XXXXXX_create_application_types.exs`
- Create: `test/mcp/ola/resources/application_type_test.exs`

**Step 1: Write tests for ApplicationType**

```elixir
# test/mcp/ola/resources/application_type_test.exs
defmodule Mcp.Ola.ApplicationTypeTest do
  use Mcp.DataCase, async: true

  alias Mcp.Ola.ApplicationType

  @valid_schema %{
    "ux_mode" => "wizard",
    "steps" => [
      %{
        "id" => "business_info",
        "label" => "Business Information",
        "fields" => [
          %{"id" => "business_name", "type" => "text", "label" => "Business Name", "required" => true}
        ]
      }
    ]
  }

  describe "create" do
    test "creates application type with valid schema" do
      assert {:ok, app_type} =
               ApplicationType.create(%{
                 name: "Merchant Onboarding",
                 slug: "merchant-onboarding",
                 vertical: :fintech,
                 form_schema: @valid_schema
               })

      assert app_type.name == "Merchant Onboarding"
      assert app_type.slug == "merchant-onboarding"
      assert app_type.vertical == :fintech
      assert app_type.status == :draft
      assert app_type.form_schema == @valid_schema
    end

    test "requires name" do
      assert {:error, changeset} =
               ApplicationType.create(%{
                 slug: "test",
                 vertical: :fintech,
                 form_schema: @valid_schema
               })

      assert "is required" in errors_on(changeset).name
    end

    test "requires form_schema" do
      assert {:error, changeset} =
               ApplicationType.create(%{
                 name: "Test",
                 slug: "test",
                 vertical: :fintech
               })

      assert "is required" in errors_on(changeset).form_schema
    end

    test "validates form_schema structure" do
      assert {:error, changeset} =
               ApplicationType.create(%{
                 name: "Test",
                 slug: "test",
                 vertical: :fintech,
                 form_schema: %{"invalid" => true}
               })

      assert Enum.any?(errors_on(changeset).form_schema, &String.contains?(&1, "steps"))
    end
  end

  describe "publish" do
    test "changes status from draft to published" do
      {:ok, app_type} =
        ApplicationType.create(%{
          name: "Test",
          slug: "test",
          vertical: :fintech,
          form_schema: @valid_schema
        })

      assert app_type.status == :draft

      {:ok, published} = ApplicationType.publish(app_type)
      assert published.status == :published
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/ola/resources/application_type_test.exs`
Expected: FAIL with "module Mcp.Ola.ApplicationType is not available"

**Step 3: Create the ApplicationType resource**

```elixir
# lib/mcp/ola/resources/application_type.ex
defmodule Mcp.Ola.ApplicationType do
  @moduledoc """
  Defines a type of application (schema-driven form definition).
  ApplicationTypes are templates that define what fields, steps, and validations
  an application form will have.
  """
  use Ash.Resource,
    domain: Mcp.Ola,
    data_layer: AshPostgres.DataLayer

  alias Mcp.Ola.FormSchema

  postgres do
    table "ola_application_types"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :description, :vertical, :form_schema, :document_requirements, :routing_rules, :ai_config, :branding, :is_template]

      change fn changeset, _ ->
        case Ash.Changeset.get_attribute(changeset, :form_schema) do
          nil -> changeset
          schema ->
            case FormSchema.validate(schema) do
              {:ok, _} -> changeset
              {:error, errors} ->
                Ash.Changeset.add_error(changeset, field: :form_schema, message: Enum.join(errors, "; "))
            end
        end
      end
    end

    update :update do
      primary? true
      accept [:name, :slug, :description, :form_schema, :document_requirements, :routing_rules, :ai_config, :branding]

      change fn changeset, _ ->
        case Ash.Changeset.get_attribute(changeset, :form_schema) do
          nil -> changeset
          schema ->
            case FormSchema.validate(schema) do
              {:ok, _} -> changeset
              {:error, errors} ->
                Ash.Changeset.add_error(changeset, field: :form_schema, message: Enum.join(errors, "; "))
            end
        end
      end
    end

    update :publish do
      accept []
      change set_attribute(:status, :published)
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :description, :string

    attribute :version, :string, default: "1.0"

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived]
      default :draft
    end

    attribute :vertical, :atom do
      constraints one_of: [:fintech, :property, :lending, :underwriting_only]
      allow_nil?: false
    end

    # Schema (JSONB)
    attribute :form_schema, :map, allow_nil?: false
    attribute :document_requirements, {:array, :map}, default: []
    attribute :routing_rules, {:array, :map}, default: []
    attribute :ai_config, :map, default: %{}
    attribute :branding, :map, default: %{}

    # Template system
    attribute :is_template, :boolean, default: false
    attribute :parent_template_id, :uuid

    timestamps()
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant, allow_nil?: true
  end

  code_interface do
    define :create
    define :update
    define :read
    define :destroy
    define :publish
    define :archive
    define :get_by_id, action: :read, get_by: [:id]
    define :get_by_slug, action: :read, get_by: [:slug]
  end
end
```

**Step 4: Update domain to include resource**

```elixir
# lib/mcp/ola/ola.ex
defmodule Mcp.Ola do
  @moduledoc """
  Domain for Online Application (OLA) functionality.
  Provides schema-driven application forms and dynamic rendering.
  """
  use Ash.Domain

  resources do
    resource Mcp.Ola.ApplicationType
  end
end
```

**Step 5: Generate migration**

Run: `mix ash.codegen create_ola_application_types`

**Step 6: Run migration**

Run: `mix ecto.migrate`

**Step 7: Run test to verify it passes**

Run: `mix test test/mcp/ola/resources/application_type_test.exs`
Expected: PASS

**Step 8: Commit**

```bash
git add lib/mcp/ola/ test/mcp/ola/resources/ priv/repo/migrations/*application_types*
git commit -m "feat(ola): add ApplicationType resource with schema validation"
```

---

## Task 4: Create ApplicationInstance Resource

**Files:**
- Create: `lib/mcp/ola/resources/application_instance.ex`
- Modify: `lib/mcp/ola/ola.ex` (add resource)
- Create: `priv/repo/migrations/XXXXXX_create_application_instances.exs`
- Create: `test/mcp/ola/resources/application_instance_test.exs`

**Step 1: Write tests for ApplicationInstance**

```elixir
# test/mcp/ola/resources/application_instance_test.exs
defmodule Mcp.Ola.ApplicationInstanceTest do
  use Mcp.DataCase, async: true

  alias Mcp.Ola.{ApplicationType, ApplicationInstance}

  @valid_schema %{
    "ux_mode" => "wizard",
    "steps" => [
      %{
        "id" => "business_info",
        "label" => "Business Information",
        "fields" => [
          %{"id" => "business_name", "type" => "text", "label" => "Business Name", "required" => true}
        ]
      }
    ]
  }

  setup do
    {:ok, app_type} =
      ApplicationType.create(%{
        name: "Test App",
        slug: "test-app",
        vertical: :fintech,
        form_schema: @valid_schema
      })

    %{app_type: app_type}
  end

  describe "create" do
    test "creates instance for application type", %{app_type: app_type} do
      assert {:ok, instance} =
               ApplicationInstance.create(%{
                 application_type_id: app_type.id
               })

      assert instance.application_type_id == app_type.id
      assert instance.status == :draft
      assert instance.data == %{}
      assert instance.current_step == "business_info"  # first step from schema
    end
  end

  describe "save_progress" do
    test "updates data and current step", %{app_type: app_type} do
      {:ok, instance} = ApplicationInstance.create(%{application_type_id: app_type.id})

      {:ok, updated} =
        ApplicationInstance.save_progress(instance, %{
          data: %{"business_name" => "Acme Corp"},
          current_step: "business_info"
        })

      assert updated.data == %{"business_name" => "Acme Corp"}
    end
  end

  describe "submit" do
    test "changes status to submitted", %{app_type: app_type} do
      {:ok, instance} = ApplicationInstance.create(%{application_type_id: app_type.id})
      {:ok, submitted} = ApplicationInstance.submit(instance)

      assert submitted.status == :submitted
      assert submitted.submitted_at != nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/ola/resources/application_instance_test.exs`
Expected: FAIL with "module Mcp.Ola.ApplicationInstance is not available"

**Step 3: Create ApplicationInstance resource**

```elixir
# lib/mcp/ola/resources/application_instance.ex
defmodule Mcp.Ola.ApplicationInstance do
  @moduledoc """
  A runtime instance of an application being filled out by a user.
  Stores the user's progress through the form defined by ApplicationType.
  """
  use Ash.Resource,
    domain: Mcp.Ola,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ola_application_instances"
    repo Mcp.Repo
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:application_type_id, :subject_id, :subject_type]

      change fn changeset, _ ->
        # Set initial step from the application type's schema
        app_type_id = Ash.Changeset.get_attribute(changeset, :application_type_id)

        if app_type_id do
          case Mcp.Ola.ApplicationType.get_by_id(app_type_id) do
            {:ok, app_type} ->
              first_step =
                app_type.form_schema
                |> Map.get("steps", [])
                |> List.first()
                |> case do
                  %{"id" => id} -> id
                  _ -> nil
                end

              Ash.Changeset.change_attribute(changeset, :current_step, first_step)

            _ ->
              changeset
          end
        else
          changeset
        end
      end
    end

    update :save_progress do
      accept [:data, :current_step, :validation_errors]
    end

    update :submit do
      accept []

      change set_attribute(:status, :submitted)
      change set_attribute(:submitted_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:draft, :submitted, :processing, :approved, :rejected, :more_info_required]
      default :draft
    end

    # Form data (JSONB)
    attribute :data, :map, default: %{}
    attribute :current_step, :string
    attribute :validation_errors, :map, default: %{}

    # Subject (polymorphic reference to what this application is for)
    attribute :subject_id, :uuid
    attribute :subject_type, :atom do
      constraints one_of: [:merchant, :individual, :organization]
    end

    attribute :submitted_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :application_type, Mcp.Ola.ApplicationType, allow_nil?: false
  end

  code_interface do
    define :create
    define :read
    define :destroy
    define :save_progress
    define :submit
    define :get_by_id, action: :read, get_by: [:id]
  end
end
```

**Step 4: Update domain**

```elixir
# lib/mcp/ola/ola.ex - add to resources block
resource Mcp.Ola.ApplicationInstance
```

**Step 5: Generate and run migration**

Run: `mix ash.codegen create_ola_application_instances && mix ecto.migrate`

**Step 6: Run test to verify it passes**

Run: `mix test test/mcp/ola/resources/application_instance_test.exs`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/mcp/ola/ test/mcp/ola/resources/ priv/repo/migrations/*application_instances*
git commit -m "feat(ola): add ApplicationInstance resource for runtime form state"
```

---

## Task 5: Create SchemaParser Module

**Files:**
- Create: `lib/mcp/ola/renderer/schema_parser.ex`
- Create: `test/mcp/ola/renderer/schema_parser_test.exs`

**Step 1: Write tests**

```elixir
# test/mcp/ola/renderer/schema_parser_test.exs
defmodule Mcp.Ola.Renderer.SchemaParserTest do
  use ExUnit.Case, async: true

  alias Mcp.Ola.Renderer.SchemaParser

  @merchant_schema %{
    "ux_mode" => "wizard",
    "steps" => [
      %{
        "id" => "business_info",
        "label" => "Business Information",
        "fields" => [
          %{"id" => "business_name", "type" => "text", "label" => "Business Name", "required" => true},
          %{"id" => "ein", "type" => "ein", "label" => "EIN", "required" => true}
        ]
      },
      %{
        "id" => "contact",
        "label" => "Contact Info",
        "fields" => [
          %{"id" => "email", "type" => "email", "label" => "Email", "required" => true}
        ]
      }
    ]
  }

  describe "parse/1" do
    test "parses schema into structured format" do
      {:ok, parsed} = SchemaParser.parse(@merchant_schema)

      assert parsed.ux_mode == :wizard
      assert length(parsed.steps) == 2
      assert hd(parsed.steps).id == "business_info"
    end
  end

  describe "get_step/2" do
    test "returns step by id" do
      {:ok, parsed} = SchemaParser.parse(@merchant_schema)
      step = SchemaParser.get_step(parsed, "contact")

      assert step.id == "contact"
      assert step.label == "Contact Info"
    end

    test "returns nil for unknown step" do
      {:ok, parsed} = SchemaParser.parse(@merchant_schema)
      assert SchemaParser.get_step(parsed, "unknown") == nil
    end
  end

  describe "get_fields_for_step/2" do
    test "returns fields for a step" do
      {:ok, parsed} = SchemaParser.parse(@merchant_schema)
      fields = SchemaParser.get_fields_for_step(parsed, "business_info")

      assert length(fields) == 2
      assert hd(fields).id == "business_name"
      assert hd(fields).type == :text
    end
  end

  describe "step_order/1" do
    test "returns ordered list of step ids" do
      {:ok, parsed} = SchemaParser.parse(@merchant_schema)
      order = SchemaParser.step_order(parsed)

      assert order == ["business_info", "contact"]
    end
  end

  describe "next_step/2 and prev_step/2" do
    test "returns next step id" do
      {:ok, parsed} = SchemaParser.parse(@merchant_schema)
      assert SchemaParser.next_step(parsed, "business_info") == "contact"
      assert SchemaParser.next_step(parsed, "contact") == nil
    end

    test "returns previous step id" do
      {:ok, parsed} = SchemaParser.parse(@merchant_schema)
      assert SchemaParser.prev_step(parsed, "contact") == "business_info"
      assert SchemaParser.prev_step(parsed, "business_info") == nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/ola/renderer/schema_parser_test.exs`
Expected: FAIL

**Step 3: Create SchemaParser module**

```elixir
# lib/mcp/ola/renderer/schema_parser.ex
defmodule Mcp.Ola.Renderer.SchemaParser do
  @moduledoc """
  Parses form schema JSON into structured Elixir data for rendering.
  """

  defmodule ParsedSchema do
    @moduledoc false
    defstruct [:ux_mode, :steps, :settings]
  end

  defmodule ParsedStep do
    @moduledoc false
    defstruct [:id, :label, :description, :icon, :conditions, :fields, :repeatable, :min, :max]
  end

  defmodule ParsedField do
    @moduledoc false
    defstruct [
      :id, :type, :label, :placeholder, :required, :help_text, :ai_hint,
      :validations, :conditions, :layout, :options
    ]
  end

  @doc "Parses a form schema map into structured data"
  def parse(schema) when is_map(schema) do
    parsed = %ParsedSchema{
      ux_mode: parse_ux_mode(schema["ux_mode"]),
      steps: parse_steps(schema["steps"] || []),
      settings: parse_settings(schema["settings"])
    }

    {:ok, parsed}
  end

  def parse(_), do: {:error, "schema must be a map"}

  @doc "Gets a step by id"
  def get_step(%ParsedSchema{steps: steps}, step_id) do
    Enum.find(steps, fn step -> step.id == step_id end)
  end

  @doc "Gets fields for a step"
  def get_fields_for_step(parsed_schema, step_id) do
    case get_step(parsed_schema, step_id) do
      nil -> []
      step -> step.fields
    end
  end

  @doc "Returns ordered list of step ids"
  def step_order(%ParsedSchema{steps: steps}) do
    Enum.map(steps, & &1.id)
  end

  @doc "Returns the next step id, or nil if at end"
  def next_step(parsed_schema, current_step_id) do
    order = step_order(parsed_schema)
    idx = Enum.find_index(order, &(&1 == current_step_id))

    if idx && idx < length(order) - 1 do
      Enum.at(order, idx + 1)
    else
      nil
    end
  end

  @doc "Returns the previous step id, or nil if at beginning"
  def prev_step(parsed_schema, current_step_id) do
    order = step_order(parsed_schema)
    idx = Enum.find_index(order, &(&1 == current_step_id))

    if idx && idx > 0 do
      Enum.at(order, idx - 1)
    else
      nil
    end
  end

  # Private helpers

  defp parse_ux_mode(nil), do: :wizard
  defp parse_ux_mode(mode) when is_binary(mode), do: String.to_atom(mode)
  defp parse_ux_mode(mode) when is_atom(mode), do: mode

  defp parse_steps(steps) when is_list(steps) do
    Enum.map(steps, &parse_step/1)
  end

  defp parse_step(step) when is_map(step) do
    %ParsedStep{
      id: step["id"],
      label: step["label"],
      description: step["description"],
      icon: step["icon"],
      conditions: step["conditions"],
      fields: parse_fields(step["fields"] || []),
      repeatable: step["repeatable"] || false,
      min: step["min"],
      max: step["max"]
    }
  end

  defp parse_fields(fields) when is_list(fields) do
    Enum.map(fields, &parse_field/1)
  end

  defp parse_field(field) when is_map(field) do
    %ParsedField{
      id: field["id"],
      type: parse_field_type(field["type"]),
      label: field["label"],
      placeholder: field["placeholder"],
      required: field["required"] || false,
      help_text: field["help_text"],
      ai_hint: field["ai_hint"],
      validations: field["validations"] || [],
      conditions: field["conditions"],
      layout: field["layout"],
      options: field["options"]
    }
  end

  defp parse_field_type(type) when is_binary(type), do: String.to_atom(type)
  defp parse_field_type(type) when is_atom(type), do: type
  defp parse_field_type(_), do: :text

  defp parse_settings(nil), do: %{}
  defp parse_settings(settings) when is_map(settings), do: settings
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/ola/renderer/schema_parser_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/ola/renderer/ test/mcp/ola/renderer/
git commit -m "feat(ola): add SchemaParser for form schema parsing"
```

---

## Task 6: Create ComponentMapper Module

**Files:**
- Create: `lib/mcp/ola/renderer/component_mapper.ex`
- Create: `test/mcp/ola/renderer/component_mapper_test.exs`

**Step 1: Write tests**

```elixir
# test/mcp/ola/renderer/component_mapper_test.exs
defmodule Mcp.Ola.Renderer.ComponentMapperTest do
  use ExUnit.Case, async: true

  alias Mcp.Ola.Renderer.ComponentMapper

  describe "get_component/1" do
    test "maps text type to text component" do
      assert ComponentMapper.get_component(:text) == McpWeb.Ola.Fields.TextField
    end

    test "maps email type to email component" do
      assert ComponentMapper.get_component(:email) == McpWeb.Ola.Fields.EmailField
    end

    test "maps select type to select component" do
      assert ComponentMapper.get_component(:select) == McpWeb.Ola.Fields.SelectField
    end

    test "maps unknown type to fallback text component" do
      assert ComponentMapper.get_component(:unknown) == McpWeb.Ola.Fields.TextField
    end
  end

  describe "all_types/0" do
    test "returns all registered field types" do
      types = ComponentMapper.all_types()

      assert :text in types
      assert :email in types
      assert :phone in types
      assert :select in types
      assert :address in types
      assert :ssn in types
      assert :document in types
      assert :signature in types
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/mcp/ola/renderer/component_mapper_test.exs`
Expected: FAIL

**Step 3: Create ComponentMapper module**

```elixir
# lib/mcp/ola/renderer/component_mapper.ex
defmodule Mcp.Ola.Renderer.ComponentMapper do
  @moduledoc """
  Maps field types to LiveView components for dynamic rendering.
  """

  @component_map %{
    text: McpWeb.Ola.Fields.TextField,
    textarea: McpWeb.Ola.Fields.TextareaField,
    email: McpWeb.Ola.Fields.EmailField,
    phone: McpWeb.Ola.Fields.PhoneField,
    date: McpWeb.Ola.Fields.DateField,
    currency: McpWeb.Ola.Fields.CurrencyField,
    percentage: McpWeb.Ola.Fields.PercentageField,
    select: McpWeb.Ola.Fields.SelectField,
    radio: McpWeb.Ola.Fields.RadioField,
    checkbox: McpWeb.Ola.Fields.CheckboxField,
    checkboxes: McpWeb.Ola.Fields.CheckboxesField,
    address: McpWeb.Ola.Fields.AddressField,
    ssn: McpWeb.Ola.Fields.SsnField,
    ein: McpWeb.Ola.Fields.EinField,
    document: McpWeb.Ola.Fields.DocumentField,
    signature: McpWeb.Ola.Fields.SignatureField,
    repeater: McpWeb.Ola.Fields.RepeaterField,
    calculated: McpWeb.Ola.Fields.CalculatedField,
    hidden: McpWeb.Ola.Fields.HiddenField
  }

  @fallback_component McpWeb.Ola.Fields.TextField

  @doc "Returns the component module for a field type"
  def get_component(field_type) do
    Map.get(@component_map, field_type, @fallback_component)
  end

  @doc "Returns all registered field types"
  def all_types do
    Map.keys(@component_map)
  end

  @doc "Checks if a field type is registered"
  def registered?(field_type) do
    Map.has_key?(@component_map, field_type)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/mcp/ola/renderer/component_mapper_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mcp/ola/renderer/component_mapper.ex test/mcp/ola/renderer/component_mapper_test.exs
git commit -m "feat(ola): add ComponentMapper for field type to component mapping"
```

---

## Task 7: Create Base Field Components

**Files:**
- Create: `lib/mcp_web/live/ola/fields/text_field.ex`
- Create: `lib/mcp_web/live/ola/fields/email_field.ex`
- Create: `lib/mcp_web/live/ola/fields/select_field.ex`
- Create: `lib/mcp_web/live/ola/fields/ssn_field.ex`
- Create: `lib/mcp_web/live/ola/fields/ein_field.ex`

**Step 1: Create base field behaviour**

```elixir
# lib/mcp_web/live/ola/fields/field_behaviour.ex
defmodule McpWeb.Ola.Fields.FieldBehaviour do
  @moduledoc """
  Behaviour for dynamic OLA field components.
  All field components must implement render/1 that accepts field assigns.
  """

  @callback render(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
end
```

**Step 2: Create TextField component**

```elixir
# lib/mcp_web/live/ola/fields/text_field.ex
defmodule McpWeb.Ola.Fields.TextField do
  @moduledoc "Dynamic text input field component"
  use McpWeb, :html

  @behaviour McpWeb.Ola.Fields.FieldBehaviour

  attr :field, :map, required: true
  attr :form, :any, required: true
  attr :value, :string, default: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label">
        <span class="label-text">
          {@field.label}
          <%= if @field.required do %>
            <span class="text-error">*</span>
          <% end %>
        </span>
      </label>
      <input
        type="text"
        name={"#{@form.name}[#{@field.id}]"}
        value={@value || Map.get(@form.params || %{}, @field.id)}
        placeholder={@field.placeholder}
        class="input input-bordered w-full"
        required={@field.required}
      />
      <%= if @field.help_text do %>
        <label class="label">
          <span class="label-text-alt text-base-content/60">{@field.help_text}</span>
        </label>
      <% end %>
    </div>
    """
  end
end
```

**Step 3: Create EmailField component**

```elixir
# lib/mcp_web/live/ola/fields/email_field.ex
defmodule McpWeb.Ola.Fields.EmailField do
  @moduledoc "Dynamic email input field component"
  use McpWeb, :html

  @behaviour McpWeb.Ola.Fields.FieldBehaviour

  attr :field, :map, required: true
  attr :form, :any, required: true
  attr :value, :string, default: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label">
        <span class="label-text">
          {@field.label}
          <%= if @field.required do %>
            <span class="text-error">*</span>
          <% end %>
        </span>
      </label>
      <input
        type="email"
        name={"#{@form.name}[#{@field.id}]"}
        value={@value || Map.get(@form.params || %{}, @field.id)}
        placeholder={@field.placeholder || "email@example.com"}
        class="input input-bordered w-full"
        required={@field.required}
      />
      <%= if @field.help_text do %>
        <label class="label">
          <span class="label-text-alt text-base-content/60">{@field.help_text}</span>
        </label>
      <% end %>
    </div>
    """
  end
end
```

**Step 4: Create SelectField component**

```elixir
# lib/mcp_web/live/ola/fields/select_field.ex
defmodule McpWeb.Ola.Fields.SelectField do
  @moduledoc "Dynamic select/dropdown field component"
  use McpWeb, :html

  @behaviour McpWeb.Ola.Fields.FieldBehaviour

  attr :field, :map, required: true
  attr :form, :any, required: true
  attr :value, :string, default: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label">
        <span class="label-text">
          {@field.label}
          <%= if @field.required do %>
            <span class="text-error">*</span>
          <% end %>
        </span>
      </label>
      <select
        name={"#{@form.name}[#{@field.id}]"}
        class="select select-bordered w-full"
        required={@field.required}
      >
        <option value="">Select...</option>
        <%= for opt <- @field.options || [] do %>
          <option value={option_value(opt)} selected={option_value(opt) == (@value || Map.get(@form.params || %{}, @field.id))}>
            {option_label(opt)}
          </option>
        <% end %>
      </select>
      <%= if @field.help_text do %>
        <label class="label">
          <span class="label-text-alt text-base-content/60">{@field.help_text}</span>
        </label>
      <% end %>
    </div>
    """
  end

  defp option_value(%{"value" => v}), do: v
  defp option_value(opt) when is_binary(opt), do: opt
  defp option_value(opt), do: to_string(opt)

  defp option_label(%{"label" => l}), do: l
  defp option_label(opt) when is_binary(opt), do: opt
  defp option_label(opt), do: to_string(opt)
end
```

**Step 5: Create SsnField component (masked input)**

```elixir
# lib/mcp_web/live/ola/fields/ssn_field.ex
defmodule McpWeb.Ola.Fields.SsnField do
  @moduledoc "Dynamic SSN input field with masking"
  use McpWeb, :html

  @behaviour McpWeb.Ola.Fields.FieldBehaviour

  attr :field, :map, required: true
  attr :form, :any, required: true
  attr :value, :string, default: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label">
        <span class="label-text">
          {@field.label}
          <%= if @field.required do %>
            <span class="text-error">*</span>
          <% end %>
        </span>
      </label>
      <input
        type="password"
        name={"#{@form.name}[#{@field.id}]"}
        value={@value || Map.get(@form.params || %{}, @field.id)}
        placeholder="XXX-XX-XXXX"
        class="input input-bordered w-full"
        maxlength="11"
        pattern="\d{3}-?\d{2}-?\d{4}"
        required={@field.required}
        phx-hook="SsnMask"
        id={"#{@form.name}_#{@field.id}"}
      />
      <label class="label">
        <span class="label-text-alt text-base-content/60">
          {@field.help_text || "Your SSN is encrypted and secure"}
        </span>
      </label>
    </div>
    """
  end
end
```

**Step 6: Create EinField component**

```elixir
# lib/mcp_web/live/ola/fields/ein_field.ex
defmodule McpWeb.Ola.Fields.EinField do
  @moduledoc "Dynamic EIN input field with masking"
  use McpWeb, :html

  @behaviour McpWeb.Ola.Fields.FieldBehaviour

  attr :field, :map, required: true
  attr :form, :any, required: true
  attr :value, :string, default: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label">
        <span class="label-text">
          {@field.label}
          <%= if @field.required do %>
            <span class="text-error">*</span>
          <% end %>
        </span>
      </label>
      <input
        type="text"
        name={"#{@form.name}[#{@field.id}]"}
        value={@value || Map.get(@form.params || %{}, @field.id)}
        placeholder="XX-XXXXXXX"
        class="input input-bordered w-full"
        maxlength="10"
        pattern="\d{2}-?\d{7}"
        required={@field.required}
        id={"#{@form.name}_#{@field.id}"}
      />
      <%= if @field.help_text do %>
        <label class="label">
          <span class="label-text-alt text-base-content/60">{@field.help_text}</span>
        </label>
      <% end %>
    </div>
    """
  end
end
```

**Step 7: Create remaining field stubs**

Create stub implementations for: `TextareaField`, `PhoneField`, `DateField`, `CurrencyField`, `PercentageField`, `RadioField`, `CheckboxField`, `CheckboxesField`, `AddressField`, `DocumentField`, `SignatureField`, `RepeaterField`, `CalculatedField`, `HiddenField` - each following the same pattern as TextField but with appropriate input types.

**Step 8: Commit**

```bash
git add lib/mcp_web/live/ola/fields/
git commit -m "feat(ola): add dynamic field components for form rendering"
```

---

## Task 8: Create DynamicFormRenderer Component

**Files:**
- Create: `lib/mcp_web/live/ola/components/dynamic_form_renderer.ex`
- Create: `test/mcp_web/live/ola/components/dynamic_form_renderer_test.exs`

**Step 1: Create the renderer component**

```elixir
# lib/mcp_web/live/ola/components/dynamic_form_renderer.ex
defmodule McpWeb.Ola.Components.DynamicFormRenderer do
  @moduledoc """
  Renders a form step dynamically from a parsed schema.
  """
  use McpWeb, :live_component

  alias Mcp.Ola.Renderer.{SchemaParser, ComponentMapper}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-semibold">{@step.label}</h3>
      <%= if @step.description do %>
        <p class="text-base-content/70">{@step.description}</p>
      <% end %>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <%= for field <- @step.fields do %>
          <div class={field_width_class(field)}>
            <.dynamic_field field={field} form={@form} value={get_value(@form_data, field.id)} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp dynamic_field(assigns) do
    component = ComponentMapper.get_component(assigns.field.type)
    component.render(assigns)
  end

  defp field_width_class(%{layout: %{"width" => "full"}}), do: "sm:col-span-2"
  defp field_width_class(%{layout: %{"width" => "third"}}), do: ""
  defp field_width_class(_), do: ""

  defp get_value(form_data, field_id) when is_map(form_data) do
    Map.get(form_data, field_id) || Map.get(form_data, to_string(field_id))
  end
  defp get_value(_, _), do: nil
end
```

**Step 2: Commit**

```bash
git add lib/mcp_web/live/ola/components/dynamic_form_renderer.ex
git commit -m "feat(ola): add DynamicFormRenderer component"
```

---

## Task 9: Create Merchant Onboarding Seed Data

**Files:**
- Create: `priv/repo/seeds/ola_merchant_application_type.exs`

**Step 1: Create the seed file**

```elixir
# priv/repo/seeds/ola_merchant_application_type.exs
alias Mcp.Ola.ApplicationType

merchant_schema = %{
  "ux_mode" => "wizard",
  "settings" => %{
    "save_resume" => true,
    "show_progress" => true,
    "progress_style" => "steps"
  },
  "steps" => [
    %{
      "id" => "business_info",
      "label" => "Business Information",
      "description" => "Tell us about your business",
      "icon" => "building",
      "fields" => [
        %{"id" => "business_name", "type" => "text", "label" => "Business Name", "required" => true},
        %{"id" => "dba_name", "type" => "text", "label" => "DBA Name", "required" => false},
        %{
          "id" => "business_type",
          "type" => "select",
          "label" => "Business Type",
          "required" => true,
          "options" => ["LLC", "Corporation", "Sole Proprietorship", "Partnership"]
        },
        %{"id" => "ein", "type" => "ein", "label" => "EIN / Tax ID", "required" => true}
      ]
    },
    %{
      "id" => "contact_info",
      "label" => "Contact Information",
      "description" => "How can we reach you?",
      "icon" => "phone",
      "fields" => [
        %{"id" => "email", "type" => "email", "label" => "Email Address", "required" => true},
        %{"id" => "phone", "type" => "phone", "label" => "Phone Number", "required" => true},
        %{"id" => "website", "type" => "text", "label" => "Website URL", "required" => false},
        %{
          "id" => "address",
          "type" => "address",
          "label" => "Business Address",
          "required" => true,
          "layout" => %{"width" => "full"}
        }
      ]
    },
    %{
      "id" => "business_details",
      "label" => "Business Details",
      "description" => "Help us understand your business",
      "icon" => "chart-bar",
      "fields" => [
        %{"id" => "monthly_volume", "type" => "currency", "label" => "Est. Monthly Volume", "required" => true},
        %{"id" => "average_ticket", "type" => "currency", "label" => "Average Ticket Size", "required" => true},
        %{
          "id" => "description",
          "type" => "textarea",
          "label" => "Description of Products/Services",
          "required" => true,
          "layout" => %{"width" => "full"}
        }
      ]
    },
    %{
      "id" => "documents",
      "label" => "Documents",
      "description" => "Upload required documents",
      "icon" => "document",
      "fields" => [
        %{
          "id" => "government_id",
          "type" => "document",
          "label" => "Government-Issued ID",
          "required" => true,
          "help_text" => "Driver's license, passport, or state ID"
        },
        %{
          "id" => "bank_statements",
          "type" => "document",
          "label" => "Bank Statements (3 months)",
          "required" => true
        }
      ]
    },
    %{
      "id" => "review",
      "label" => "Review & Submit",
      "description" => "Please review your information before submitting",
      "icon" => "check-circle",
      "fields" => [
        %{
          "id" => "signature",
          "type" => "signature",
          "label" => "Applicant Signature",
          "required" => true,
          "help_text" => "By signing, you agree to the terms and conditions",
          "layout" => %{"width" => "full"}
        }
      ]
    }
  ]
}

case ApplicationType.get_by_slug("merchant-onboarding") do
  {:ok, _existing} ->
    IO.puts("Merchant onboarding application type already exists")

  {:error, _} ->
    {:ok, _} = ApplicationType.create(%{
      name: "Merchant Onboarding",
      slug: "merchant-onboarding",
      description: "Standard merchant onboarding application for card processing",
      vertical: :fintech,
      form_schema: merchant_schema,
      is_template: true,
      document_requirements: [
        %{
          "id" => "gov_id",
          "type" => "government_id",
          "label" => "Government-Issued ID",
          "required" => true,
          "per" => "owner"
        },
        %{
          "id" => "bank_statements",
          "type" => "bank_statement",
          "label" => "Bank Statements",
          "required" => true,
          "count" => 3
        }
      ],
      routing_rules: [
        %{
          "id" => "default",
          "priority" => 100,
          "condition" => "always",
          "pipeline_id" => "standard",
          "reason" => "Standard processing"
        }
      ]
    })

    IO.puts("Created merchant onboarding application type")
end
```

**Step 2: Add to seeds.exs**

Add to `priv/repo/seeds.exs`:
```elixir
Code.require_file("seeds/ola_merchant_application_type.exs", __DIR__)
```

**Step 3: Run seeds**

Run: `mix run priv/repo/seeds/ola_merchant_application_type.exs`

**Step 4: Commit**

```bash
git add priv/repo/seeds/
git commit -m "feat(ola): add merchant onboarding seed data"
```

---

## Task 10: Refactor ApplicationLive to Use Dynamic Renderer

**Files:**
- Modify: `lib/mcp_web/live/ola/application_live.ex`
- Modify: `lib/mcp_web/live/ola/application_live.html.heex`

**Step 1: Update ApplicationLive to load schema**

Add to mount:
```elixir
# In mount, after other assigns:
{:ok, app_type} = Mcp.Ola.ApplicationType.get_by_slug("merchant-onboarding")
{:ok, parsed_schema} = Mcp.Ola.Renderer.SchemaParser.parse(app_type.form_schema)

socket =
  socket
  |> assign(:app_type, app_type)
  |> assign(:parsed_schema, parsed_schema)
  |> assign(:current_step_id, hd(Mcp.Ola.Renderer.SchemaParser.step_order(parsed_schema)))
```

**Step 2: Update step navigation**

```elixir
def handle_event("next_step", _params, socket) do
  next = SchemaParser.next_step(socket.assigns.parsed_schema, socket.assigns.current_step_id)
  if next do
    {:noreply, assign(socket, :current_step_id, next)}
  else
    {:noreply, socket}
  end
end

def handle_event("prev_step", _params, socket) do
  prev = SchemaParser.prev_step(socket.assigns.parsed_schema, socket.assigns.current_step_id)
  if prev do
    {:noreply, assign(socket, :current_step_id, prev)}
  else
    {:noreply, socket}
  end
end
```

**Step 3: Update template to use DynamicFormRenderer**

Replace the hardcoded step conditionals with:
```heex
<.live_component
  module={McpWeb.Ola.Components.DynamicFormRenderer}
  id="dynamic-form"
  step={SchemaParser.get_step(@parsed_schema, @current_step_id)}
  form={@form}
  form_data={@form.params || %{}}
/>
```

**Step 4: Test manually**

Run: `mix phx.server`
Navigate to: `http://localhost:4000/online-application`
Expected: Form renders dynamically from schema

**Step 5: Commit**

```bash
git add lib/mcp_web/live/ola/
git commit -m "refactor(ola): use dynamic form renderer in ApplicationLive"
```

---

## Task 11: Run Full Test Suite and Precommit

**Step 1: Run all tests**

Run: `mix test`
Expected: All tests pass

**Step 2: Run precommit**

Run: `mix precommit`
Expected: All checks pass

**Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address test and precommit issues"
```

---

## Summary

After completing all tasks:

| Component | Status |
|-----------|--------|
| Mcp.Ola domain | Created |
| ApplicationType resource | Created with schema validation |
| ApplicationInstance resource | Created with multitenancy |
| FormSchema validator | Created |
| SchemaParser | Created |
| ComponentMapper | Created |
| Dynamic field components | Created (text, email, select, ssn, ein + stubs) |
| DynamicFormRenderer | Created |
| Merchant seed data | Created |
| ApplicationLive refactor | Done - uses dynamic renderer |

**Validation**: Navigate to `/online-application` and verify the merchant application form renders identically to before, but now driven by schema.

---

**Document Author**: Claude (AI Assistant)
**Plan Version**: 1.0
**Estimated Tasks**: 11
