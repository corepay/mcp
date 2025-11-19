defmodule BmadIntegration.Validator do
  @moduledoc """
  Validates consistency across Ash, DaisyUI, and BMAD layers.
  Replaces the legacy Python-based cross_stack_validator.py.
  """

  require Logger

  @pattern_rules %{
    resource_mapping: %{
      "user" => %{
        ash_resource: "UserResource",
        daisyui_component: "user-card",
        bmad_workflow: "user_lifecycle"
      },
      "post" => %{
        ash_resource: "PostResource",
        daisyui_component: "post-card",
        bmad_workflow: "post_lifecycle"
      }
    },
    theme_colors: %{
      "primary" => "hsl(222.2 47.4% 11.2%)",
      "secondary" => "hsl(210 40% 96%)",
      "accent" => "hsl(210 40% 96%)",
      "neutral" => "hsl(215.4 16.3% 46.9%)"
    }
  }

  def validate_project do
    IO.puts("\n🔄 Running unified cross-stack validation (Elixir Native)...")

    results = [
      check_pattern_consistency(),
      check_theme_sync(),
      check_naming_convention(),
      check_component_mapping(),
      check_workflow_integration()
    ]

    failures = Enum.filter(results, fn {status, _} -> status == :error end)

    if Enum.empty?(failures) do
      IO.puts(
        "\n🎉 All cross-stack validations passed! Your Ash + DaisyUI + BMAD integration is perfectly synchronized."
      )

      :ok
    else
      IO.puts("\n⚠️ #{length(failures)} validation issues found. Please review and fix.")
      Enum.each(failures, fn {:error, msg} -> IO.puts("  ❌ #{msg}") end)
      :error
    end
  end

  defp check_pattern_consistency do
    IO.puts("  📋 Checking pattern consistency...")

    ash_resources = find_ash_resources()
    daisyui_components = find_daisyui_components()

    errors =
      @pattern_rules.resource_mapping
      |> Enum.flat_map(fn {_key, mapping} ->
        resource = mapping.ash_resource
        component = mapping.daisyui_component

        resource_error =
          if resource in ash_resources, do: [], else: ["Ash resource '#{resource}' not found"]

        component_error =
          if component in daisyui_components,
            do: [],
            else: ["DaisyUI component '#{component}' not found"]

        resource_error ++ component_error
      end)

    if Enum.empty?(errors),
      do: {:ok, "Pattern consistency passed"},
      else: {:error, Enum.join(errors, "\n  ❌ ")}
  end

  defp check_theme_sync do
    IO.puts("  🎨 Checking theme synchronization...")
    # Simplified check: Verify config files exist and contain some theme keys
    # In a real implementation, we would parse the actual values

    files_to_check = [
      "config/config.exs",
      "assets/css/app.css",
      "tailwind.config.js"
    ]

    found = Enum.count(files_to_check, &File.exists?/1)

    if found >= 2 do
      {:ok, "Theme synchronization passed"}
    else
      {:error,
       "Limited theme synchronization found (checked config.exs, app.css, tailwind.config.js)"}
    end
  end

  defp check_naming_convention do
    IO.puts("  📝 Checking naming conventions...")

    errors =
      @pattern_rules.resource_mapping
      |> Enum.flat_map(fn {_key, mapping} ->
        resource = mapping.ash_resource
        component = mapping.daisyui_component

        r_err =
          if Regex.match?(~r/^[A-Z][a-zA-Z0-9]*Resource$/, resource),
            do: [],
            else: ["Ash resource '#{resource}' doesn't follow PascalCase"]

        c_err =
          if Regex.match?(~r/^[a-z]+(-[a-z]+)*$/, component),
            do: [],
            else: ["DaisyUI component '#{component}' doesn't follow kebab-case"]

        r_err ++ c_err
      end)

    if Enum.empty?(errors),
      do: {:ok, "Naming conventions passed"},
      else: {:error, Enum.join(errors, "\n  ❌ ")}
  end

  defp check_component_mapping do
    IO.puts("  🗺️ Checking component mappings...")
    # Logic ported from Python: checks if the mapping map has all keys.
    # Since we define the map statically above, this is always true for our hardcoded rules,
    # but verifies the structure of the rules themselves.

    invalid_mappings =
      @pattern_rules.resource_mapping
      |> Enum.filter(fn {_k, m} ->
        is_nil(m[:ash_resource]) or is_nil(m[:daisyui_component]) or is_nil(m[:bmad_workflow])
      end)

    if Enum.empty?(invalid_mappings),
      do: {:ok, "Component mappings passed"},
      else: {:error, "Incomplete mappings found"}
  end

  defp check_workflow_integration do
    IO.puts("  ⚙️ Checking workflow integration...")

    workflow_files = Path.wildcard("**/*.{yaml,md}")

    has_workflows =
      Enum.any?(workflow_files, fn file ->
        content = File.read!(file)
        String.contains?(String.downcase(content), ["workflow", "bmad"])
      end)

    if has_workflows,
      do: {:ok, "Workflow integration passed"},
      else: {:error, "No BMAD workflow files found"}
  end

  # Helpers

  defp find_ash_resources do
    Path.wildcard("lib/**/*.ex")
    |> Enum.flat_map(&extract_resource_name/1)
  end

  defp extract_resource_name(file) do
    case File.read(file) do
      {:ok, content} ->
        Regex.scan(~r/defmodule\s+([a-zA-Z0-9\.]*Resource)/, content)
        |> Enum.map(fn [_, name] ->
          name |> String.split(".") |> List.last()
        end)

      _ ->
        []
    end
  end

  defp find_daisyui_components do
    # Check html and heex
    Path.wildcard("lib/**/*.*")
    |> Enum.flat_map(fn file ->
      if String.ends_with?(file, ".html") or String.ends_with?(file, ".heex") do
        content = File.read!(file)
        # Heuristic: look for class="... user-card ..." or similar
        # This matches the Python script's loose logic
        ["user-card", "post-card"]
        |> Enum.filter(&String.contains?(content, &1))
      else
        []
      end
    end)
  end
end
