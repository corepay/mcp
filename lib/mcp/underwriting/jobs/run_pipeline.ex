defmodule Mcp.Underwriting.Jobs.RunPipeline do
  @moduledoc """
  Oban worker for executing underwriting pipelines.
  """
  use Oban.Worker, queue: :underwriting, max_attempts: 3

  alias Mcp.Underwriting.Engine.Orchestrator

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"execution_id" => execution_id}}) do
    Orchestrator.run_pipeline(execution_id)
    :ok
  end
end
