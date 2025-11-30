defmodule Mcp.Underwriting.Jobs.RunPipeline do
  use Oban.Worker, queue: :underwriting, max_attempts: 3

  alias Mcp.Underwriting.Engine.Orchestrator

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"execution_id" => execution_id}}) do
    case Orchestrator.run_pipeline(execution_id) do
      {:ok, _execution} -> :ok
      {:error, reason} -> {:error, reason}
      # Handle other return types if necessary
      _ -> :ok
    end
  end
end
