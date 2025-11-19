defmodule BMADAsh.Generator.ResourceGenerator do
  @moduledoc """
  Generates Ash resources and matching DaisyUI components from BMAD module definitions
  """

  def generate_resource(bmad_module) do
    # Extract resource definition from BMAD module
    resource_name = extract_resource_name(bmad_module)
    actions = extract_actions(bmad_module)
    attributes = extract_attributes(bmad_module)

    # Generate Ash resource
    ash_resource = generate_ash_resource(resource_name, actions, attributes)

    # Generate matching DaisyUI component
    daisyui_component = generate_daisyui_component(resource_name, actions)

    # Generate usage rules
    usage_rules = generate_usage_rules(resource_name, actions)

    %{
      ash_resource: ash_resource,
      daisyui_component: daisyui_component,
      usage_rules: usage_rules
    }
  end

  defp generate_ash_resource(name, actions, attributes) do
    """
    defmodule #{Macro.camelize(to_string(name))} do
      use Ash.Resource

      attributes do
        #{Enum.map(attributes, &generate_attribute/1)}
      end

      actions do
        #{Enum.map(actions, &generate_action/1)}
      end
    end
    """
  end

  defp generate_daisyui_component(name, actions) do
    """
    <!-- #{Macro.camelize(to_string(name))} DaisyUI Component -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">#{Macro.camelize(to_string(name))}</h2>
        #{Enum.map(actions, &generate_component_action/1)}
      </div>
    </div>
    """
  end

  defp generate_usage_rules(name, actions) do
    """
    # #{Macro.camelize(to_string(name))} Usage Rules

    ## Derived from BMAD Module Definition

    #{Enum.map(actions, &generate_usage_rule/1)}

    ## DaisyUI Component Mappings
    - #{name}:show → user-card component with detail modifier
    - #{name}:list → user-card component with list modifier
    - #{name}:create → user-card component with form modifier
    """
  end

  # Helper functions for generating specific parts
  # Placeholder
  defp extract_resource_name(_module), do: "user"
  # Placeholder
  defp extract_actions(_module), do: [:show, :list, :create, :edit]
  # Placeholder
  defp extract_attributes(_module), do: [:name, :email, :role]

  defp generate_attribute({name, type}), do: "attribute :#{name}, #{type}"
  defp generate_action(:show), do: "read :show, primary?: true"
  defp generate_action(:list), do: "read :list"
  defp generate_action(:create), do: "create :create"
  defp generate_action(:edit), do: "update :edit"

  defp generate_component_action(:show),
    do: "<button class=\"btn btn-primary\">View Details</button>"

  defp generate_component_action(:list), do: "<div class=\"flex justify-between\">List Item</div>"

  defp generate_component_action(:create),
    do: "<button class=\"btn btn-success\">Create New</button>"

  defp generate_usage_rule(:show), do: "- show:admin_role → Require admin validation"

  defp generate_usage_rule(:create),
    do: "- create:email_verification → Auto-generate verification"
end
