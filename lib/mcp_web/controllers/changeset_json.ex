defmodule McpWeb.ChangesetJSON do
  @moduledoc """
  Renders Ecto changesets as JSON.
  """

  @doc """
  Renders a changeset as a JSON error response.
  """
  def error(%{changeset: changeset}) do
    %{
      error: %{
        code: "validation_error",
        message: "Validation failed",
        details: translate_errors(changeset)
      }
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
