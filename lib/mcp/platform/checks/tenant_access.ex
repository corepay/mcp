defmodule Mcp.Platform.Checks.TenantAccess do
  use Ash.Policy.FilterCheck
  alias Mcp.Platform.{Team, TeamMember}

  @moduledoc """
  Checks if the actor is a member of the tenant that owns the resource.
  """

  def describe(_opts), do: "actor is a member of the tenant owner"

  def filter(actor, _context, _opts) do
    tenant_ids = get_actor_tenant_ids(actor)
    expr(owner_type == :tenant and owner_id in ^tenant_ids)
  end

  def match?(actor, context, _opts) do
    changeset = Map.get(context, :changeset)
    record = Map.get(context, :record)

    {owner_type, owner_id} =
      cond do
        changeset ->
          {Ash.Changeset.get_attribute(changeset, :owner_type),
           Ash.Changeset.get_attribute(changeset, :owner_id)}

        record ->
          {Map.get(record, :owner_type), Map.get(record, :owner_id)}

        true ->
          {nil, nil}
      end

    if owner_type == :tenant do
      owner_id in get_actor_tenant_ids(actor)
    else
      false
    end
  end

  defp get_actor_tenant_ids(nil), do: []

  defp get_actor_tenant_ids(%Mcp.Accounts.User{id: user_id}) do
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
