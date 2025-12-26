defmodule Mcp.Platform.Changes.HashApiKey do
  @moduledoc """
  Ash change that generates and hashes an API key during creation.
  The raw key is stored in metadata for one-time display to the user.
  """
  use Ash.Resource.Change

  alias Mcp.Platform.ApiKey

  def change(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :key_hash) do
      changeset
    else
      prefix = Ash.Changeset.get_attribute(changeset, :prefix) || "mcp"
      # Generate 32 bytes of entropy, encoded as base64url to be URL-safe
      random_bytes = :crypto.strong_rand_bytes(32)
      secret_part = Base.url_encode64(random_bytes, padding: false)

      full_key = "#{prefix}_#{secret_part}"
      hashed_key = ApiKey.hash_key(full_key)

      changeset
      |> Ash.Changeset.force_change_attribute(:key_hash, hashed_key)
      |> Ash.Changeset.after_action(fn _changeset, result ->
        # Return the raw key in metadata so it can be shown to the user ONCE
        {:ok, Ash.Resource.put_metadata(result, :raw_key, full_key)}
      end)
    end
  end
end
