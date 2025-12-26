defmodule Mcp.Platform.TenantHelpers do
  @moduledoc """
  Helper functions for tenant access and membership queries.
  """
  alias Mcp.Platform.Team
  alias Mcp.Platform.TeamMember
  require Ash.Query

  def get_actor_tenant_ids(nil), do: []

  def get_actor_tenant_ids(%Mcp.Accounts.User{id: user_id}) do
    team_ids =
      TeamMember
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.team_id)

    Team
    |> Ash.Query.filter(id in ^team_ids and entity_type == :tenant)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.entity_id)
  end
end
