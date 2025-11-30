defmodule Mcp.Registration.WorkflowOrchestrator do
  @moduledoc """
  Orchestrates the complete registration workflow.
  """

  alias Mcp.Registration.RegistrationService

  @doc """
  Executes the full registration workflow.

  ## Parameters
  - `workflow_data` - Map containing user_data and metadata

  ## Returns
  - `{:ok, result}` on success
  - `{:error, reason}` on failure
  """
  def execute_registration_workflow(%{user_data: user_data, metadata: metadata}) do
    # Merge metadata into user_data for registration
    registration_data = Map.merge(user_data, metadata)

    # Extract tenant_id from metadata if present
    opts = if metadata[:tenant_id], do: [tenant_id: metadata[:tenant_id]], else: []

    case RegistrationService.register_user(registration_data, opts) do
      {:ok, %Mcp.Accounts.User{} = user} ->
        {:ok, %{status: :completed, user: user}}
      
      {:ok, %Mcp.Accounts.RegistrationRequest{} = request} ->
         {:ok, %{status: :pending_approval, request: request}}

      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def execute_registration_workflow(_) do
    {:error, :invalid_data}
  end
end
