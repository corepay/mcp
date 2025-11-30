defmodule McpWeb.FallbackController do
  @moduledoc """
  Translates controller return values to Plug.Conn responses.

  For example, if a controller returns `{:error, :not_found}`, this
  controller will render a "404 Not Found" JSON response.
  """
  use McpWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: McpWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause handles errors returned by Ash.
  def call(conn, {:error, %Ash.Error.Invalid{} = error}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "invalid_request",
        message: "Invalid request parameters",
        details: Ash.Error.to_ash_error(error) |> Map.get(:errors, []) |> Enum.map(&Map.take(&1, [:field, :message, :code]))
      }
    })
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: McpWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      error: %{
        code: "internal_server_error",
        message: "An unexpected error occurred",
        details: inspect(reason)
      }
    })
  end
end
