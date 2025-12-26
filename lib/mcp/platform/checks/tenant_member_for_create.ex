defmodule Mcp.Platform.Checks.TenantMemberForCreate do
  @moduledoc """
  Policy check that verifies the actor is a member of the tenant being referenced.
  Used for create actions where owner_type is :tenant.
  """
  use Ash.Policy.Check
  alias Mcp.Platform.TeamMember

  def describe(_opts), do: "actor is a member of the tenant owner (create)"

  def strict_check(actor, %{changeset: changeset}, _opts) do
    owner_type = Ash.Changeset.get_attribute(changeset, :owner_type)
    owner_id = Ash.Changeset.get_attribute(changeset, :owner_id)

    if owner_type == :tenant do
      if tenant_member?(actor, owner_id) do
        {:ok, true}
      else
        {:ok, false}
      end
    else
      {:ok, false}
    end
  end

  def strict_check(_actor, _context, _opts), do: {:ok, :unknown}

  def match?(_actor, _context, _opts), do: false

  defp tenant_member?(%Mcp.Accounts.User{id: user_id}, tenant_id) do
    TeamMember
    |> Ash.Query.filter(
      user_id == ^user_id and team.entity_type == :tenant and team.entity_id == ^tenant_id
    )
    |> Ash.exists?(authorize?: false)
  end

  defp tenant_member?(_, _), do: false
end
