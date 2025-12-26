defmodule Mcp.Platform.Changes.SetPrimary do
  use Ash.Resource.Change

  @moduledoc """
  Sets the `is_primary` attribute to true and unsets it for all other records
  belonging to the same owner.
  """

  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.change_attribute(:is_primary, true)
    |> Ash.Changeset.after_action(fn _changeset, result ->
      resource = result.__struct__
      owner_type = result.owner_type
      owner_id = result.owner_id
      record_id = result.id

      # Unset is_primary for all other records of this owner
      resource
      |> Ash.Query.filter(
        owner_type == ^owner_type and owner_id == ^owner_id and id != ^record_id
      )
      |> Ash.bulk_update!(:update, %{is_primary: false}, strategy: :atomic, authorize?: false)

      {:ok, result}
    end)
  end
end
