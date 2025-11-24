defmodule Mcp.Gdpr.AuditTrail do
  @moduledoc """
  GDPR audit trail functionality.
  """

  use GenServer

  alias Mcp.Gdpr.Schemas.GdprAuditLog
  alias Mcp.Repo
  import Ecto.Query

  @doc """
  Logs a GDPR action for audit purposes.
  """
  def log_action(user_id, action, actor_id \\ nil, metadata \\ %{}) do
    audit_log = %GdprAuditLog{
      user_id: user_id,
      actor_id: actor_id,
      action: action,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    Repo.insert(audit_log)
  end

  @doc """
  Logs a GDPR event for audit purposes (alias for log_action).
  """
  def log_event(user_id, action, actor_id \\ nil, metadata \\ %{}) do
    log_action(user_id, action, actor_id, metadata)
  end

  @doc """
  Retrieves user actions from audit trail.
  """
  def get_user_actions(user_id, limit \\ 100) do
    GdprAuditLog
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.timestamp)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Starts the audit trail GenServer.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end
end