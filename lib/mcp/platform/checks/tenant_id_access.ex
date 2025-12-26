defmodule Mcp.Platform.Checks.TenantIdAccess do
  use Ash.Policy.FilterCheck
  alias Mcp.Platform.{Team, TeamMember}

  @moduledoc """
  Checks if the actor is a member of the tenant referenced by `tenant_id`.
  """

  def describe(_opts), do: "actor is a member of the tenant"

  def filter(actor, _context, _opts) do
    tenant_ids = get_actor_tenant_ids(actor)
    expr(tenant_id in ^tenant_ids)
  end

  def match?(actor, context, _opts) do
    changeset = Map.get(context, :changeset)
    record = Map.get(context, :record)

    tenant_id =
      cond do
        changeset ->
          Ash.Changeset.get_attribute(changeset, :tenant_id)

        record ->
          Map.get(record, :tenant_id)

        true ->
          nil
      end

    if tenant_id do
      tenant_id in get_actor_tenant_ids(actor)
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
