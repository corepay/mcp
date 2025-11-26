defmodule McpWeb.RefundsController do
  use McpWeb, :controller

  alias Mcp.Payments.Refund
  alias Mcp.Payments.RefundReactor

  action_fallback McpWeb.FallbackController

  def create(conn, params) do
    # Convert params to atom keys for Reactor input
    inputs =
      try do
        Map.new(params, fn {k, v} -> {String.to_existing_atom(k), v} end)
      rescue
        _ -> params
      end

    case RefundReactor.process_refund(inputs) do
      {:ok, result} ->
        conn
        |> put_status(:created)
        |> json(%{status: "success", data: result})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Refund.get_by_id(id) do
      {:ok, refund} ->
        json(conn, %{status: "success", data: refund})

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Refund not found"})
    end
  end
end
