defmodule Mcp.Underwriting.Engine.Orchestrator do
  @moduledoc """
  The "Brain" that runs the pipeline.
  Sequences the execution of agents and manages state.
  """

  require Ash.Query

  alias Mcp.Underwriting.AgentBlueprint
  alias Mcp.Underwriting.Engine.{AgentRunner, InstructionLookup}
  alias Mcp.Underwriting.InstructionSet

  def run_pipeline(execution_id, opts \\ []) do
    tenant = Keyword.get(opts, :tenant)

    execution =
      Mcp.Underwriting.Execution
      |> Ash.get!(execution_id, tenant: tenant)
      |> Ash.load!(:pipeline, tenant: tenant)

    pipeline = execution.pipeline

    # Update status to processing
    execution =
      execution
      |> Ash.Changeset.for_update(:update, %{status: :processing})
      |> Ash.update!(tenant: tenant)

    results =
      Enum.reduce(pipeline.stages, %{}, fn stage_config, acc_results ->
        blueprint_id = stage_config["blueprint_id"]
        blueprint = Ash.get!(AgentBlueprint, blueprint_id, tenant: tenant)

        # Find instruction set with proper tenant scoping
        instructions = InstructionLookup.find(blueprint_id, pipeline.tenant_id)

        # Merge previous results into context
        current_context = Map.merge(execution.context, acc_results)

        # Determine entity IDs for usage tracking
        tenant_id = pipeline.tenant_id
        merchant_id = if execution.subject_type == :merchant, do: execution.subject_id, else: nil
        # reseller_id = ... (TODO: Determine source)

        opts = [
          execution_id: execution.id,
          tenant_id: tenant_id,
          merchant_id: merchant_id
        ]

        {:ok, output} = AgentRunner.run(blueprint, instructions, current_context, opts)

        Map.put(acc_results, blueprint.name, output)
      end)

    # Update execution with results
    execution =
      execution
      |> Ash.Changeset.for_update(:update, %{
        status: :completed,
        results: results
      })
      |> Ash.update!(tenant: tenant)

    # Check if review is required
    if pipeline.review_required do
      review_response(execution, results, pipeline, tenant)
    else
      execution
    end
  end

  defp review_response(execution, results, pipeline, tenant) do
    # Find the Response Reviewer blueprint
    reviewer_blueprint =
      AgentBlueprint
      |> Ash.Query.filter(name == "ResponseReviewer")
      |> Ash.read_one!(tenant: tenant)

    if reviewer_blueprint do
      IO.puts("🕵️‍♂️ Running Response Reviewer...")

      # Create a temporary instruction set for the reviewer
      instructions = %InstructionSet{
        instructions:
          "Review the following execution results. Ensure safety, privacy, and quality."
      }

      # Context includes the original results
      context = %{
        original_results: results,
        execution_id: execution.id
      }

      # Determine entity IDs (same as main pipeline)
      tenant_id = pipeline.tenant_id
      merchant_id = if execution.subject_type == :merchant, do: execution.subject_id, else: nil

      opts = [
        execution_id: execution.id,
        tenant_id: tenant_id,
        merchant_id: merchant_id
      ]

      {:ok, review_output} = AgentRunner.run(reviewer_blueprint, instructions, context, opts)

      # Update execution with the review output
      # We might want to store this separately, but for now let's just append it to results
      updated_results = Map.put(results, "review", review_output)

      execution
      |> Ash.Changeset.for_update(:update, %{results: updated_results})
      |> Ash.update!(tenant: tenant)
    else
      IO.warn("Response Reviewer blueprint not found!")
      execution
    end
  end
end
