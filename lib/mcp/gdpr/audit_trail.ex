defmodule Mcp.Gdpr.AuditTrail do
  @moduledoc """
  GDPR audit trail functionality.
  """

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
  Retrieves user actions from audit trail.
  """
  def get_user_actions(user_id, limit \\ 100) do
    GdprAuditLog
    |> Ecto.Query.where([a], a.user_id == ^user_id)
    |> Ecto.Query.order_by([a], desc: a.timestamp)
    |> Ecto.Query.limit(^limit)
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