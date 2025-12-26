defmodule Mcp.Platform.Checks.OwnerMatchesActor do
  @moduledoc """
  Policy check that verifies the actor's ID matches the record's owner_id.
  """
  use Ash.Policy.Check

  def describe(_opts), do: "actor.id matches record.owner_id"

  def strict_check(actor, %{changeset: changeset}, _opts) do
    owner_id = Ash.Changeset.get_attribute(changeset, :owner_id)
    # IO.warn("OwnerMatchesActor checking: #{inspect(owner_id)} vs #{inspect(actor.id)}")
    if owner_id == actor.id do
      {:ok, true}
    else
      {:ok, false}
    end
  end

  def strict_check(_actor, _context, _opts), do: {:ok, :unknown}

  def match?(_actor, _context, _opts), do: false
end
