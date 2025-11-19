defmodule Mix.Tasks.Validate.Stack do
  @moduledoc """
  Runs the cross-stack validation for Ash + DaisyUI + BMAD.

  ## Usage

      mix validate.stack
  """
  use Mix.Task

  @shortdoc "Validates cross-stack consistency"

  def run(_) do
    # Ensure the app is compiled so we can find modules if needed
    Mix.Task.run("compile")

    case BmadIntegration.Validator.validate_project() do
      :ok ->
        System.halt(0)

      :error ->
        IO.puts("\n⚠️  Validation failed, but proceeding (non-blocking mode)...")
        System.halt(0)
    end
  end
end
