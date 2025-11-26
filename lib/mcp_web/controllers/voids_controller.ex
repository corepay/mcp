defmodule McpWeb.VoidsController do
  use McpWeb, :controller

  alias Mcp.Payments.VoidReactor

  action_fallback McpWeb.FallbackController

  def create(conn, params) do
    # Convert params to atom keys for Reactor input
    inputs =
      try do
        Map.new(params, fn {k, v} -> {String.to_existing_atom(k), v} end)
      rescue
        _ -> params
      end

    case VoidReactor.process_void(inputs) do
      {:ok, result} ->
        conn
        |> put_status(:created)
        |> json(%{status: "success", data: result})

      {:error, reason} ->
        {:error, reason}
    end
  end
end
