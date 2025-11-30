defmodule Mcp.Underwriting.Engine.Orchestrator do
  @moduledoc """
  The "Brain" that runs the pipeline.
  Sequences the execution of agents and manages state.
  """

  require Ash.Query
  require Ash.Query
  alias Mcp.Underwriting.InstructionSet
  alias Mcp.Underwriting.Engine.AgentRunner

  def run_pipeline(execution_id) do
    execution = Mcp.Underwriting.Execution
    |> Ash.get!(execution_id)
    |> Ash.load!(:pipeline)

    pipeline = execution.pipeline
    
    # Update status to processing
    execution = 
      execution 
      |> Ash.Changeset.for_update(:update, %{status: :processing})
      |> Ash.update!()

    # Fetch Instruction Sets for this Tenant (Mocking this lookup for now)
    # In reality, we'd look up InstructionSet where tenant_id == pipeline.tenant_id
    
    results = 
      Enum.reduce(pipeline.stages, %{}, fn stage_config, acc_results ->
        blueprint_id = stage_config["blueprint_id"]
        blueprint = Ash.get!(AgentBlueprint, blueprint_id)
        
        # TODO: Find the actual instruction set for this blueprint + tenant
        # For now, we just grab the first one we find for this blueprint
        instructions = 
          InstructionSet
          |> Ash.Query.filter(blueprint_id == ^blueprint_id)
          |> Ash.read!()
          |> List.first()
        
        # If no instructions found, create a dummy one
        instructions = instructions || %InstructionSet{instructions: "Default policy."}

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
      |> Ash.update!()

    # Check if review is required
    if pipeline.review_required do
      review_response(execution, results, pipeline)
    else
      execution
    end
  end

  defp review_response(execution, results, pipeline) do
    # Find the Response Reviewer blueprint
    reviewer_blueprint = 
      AgentBlueprint
      |> Ash.Query.filter(name == "ResponseReviewer")
      |> Ash.read_one!()

    if reviewer_blueprint do
      IO.puts("🕵️‍♂️ Running Response Reviewer...")
      
      # Create a temporary instruction set for the reviewer
      instructions = %InstructionSet{
        instructions: "Review the following execution results. Ensure safety, privacy, and quality."
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
      |> Ash.update!()
    else
      IO.warn("Response Reviewer blueprint not found!")
      execution
    end
  end
end
