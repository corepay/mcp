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
    |> json(%{status: "error", message: inspect(error)})
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
    |> json(%{status: "error", message: inspect(reason)})
  end
end
