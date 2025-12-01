defmodule Mcp.Gdpr.Export do
  @moduledoc """
  GDPR data export functionality.
  """

  use GenServer

  alias Mcp.Gdpr.Schemas.GdprExport
  alias Mcp.Repo

  @doc """
  Creates an export request.
  """
  def create_export(user_id, format, _opts \\ []) do
    expires_at = DateTime.add(DateTime.utc_now(), 7, :day)

    export_attrs = %{
      user_id: user_id,
      format: format,
      status: "pending",
      expires_at: expires_at
    }

    %GdprExport{}
    |> GdprExport.changeset(export_attrs)
    |> Repo.insert()
  end

  @doc """
  Starts the export GenServer.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end
end
