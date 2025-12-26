defmodule Mcp.Platform.Checks.TenantIdAccessForCreate do
  use Ash.Policy.Check
  alias Mcp.Platform.{Team, TeamMember}

  @moduledoc """
  Checks if the actor is a member of the tenant referenced by `tenant_id` attribute in the changeset.
  Used for create actions.
  """

  def describe(_opts), do: "actor is a member of the tenant (create)"

  def strict_check(actor, %{changeset: changeset}, _opts) do
    tenant_id = Ash.Changeset.get_attribute(changeset, :tenant_id)

    if tenant_id do
      case tenant_member?(actor, tenant_id) do
        true -> {:ok, true}
        false -> {:ok, false}
      end
    else
      {:ok, false}
    end
  end

  def strict_check(_actor, _context, _opts), do: {:ok, :unknown}

  def match?(_actor, _context, _opts), do: false

  defp tenant_member?(nil, _), do: false

  defp tenant_member?(%Mcp.Accounts.User{id: user_id}, tenant_id) do
    team_ids =
      TeamMember
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.team_id)

    Team
    |> Ash.Query.filter(id in ^team_ids and entity_type == :tenant and entity_id == ^tenant_id)
    |> Ash.exists?(authorize?: false)
  end
end
