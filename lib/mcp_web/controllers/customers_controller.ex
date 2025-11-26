defmodule McpWeb.CustomersController do
  use McpWeb, :controller

  alias Mcp.Payments.Customer

  action_fallback McpWeb.FallbackController

  def create(conn, params) do
    # Convert params to atom keys
    inputs =
      try do
        Map.new(params, fn {k, v} -> {String.to_existing_atom(k), v} end)
      rescue
        _ -> params
      end

    case Customer.create(inputs) do
      {:ok, customer} ->
        conn
        |> put_status(:created)
        |> json(%{status: "success", data: customer})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def show(conn, %{"id" => id}) do
    case Customer.by_id(id) do
      {:ok, customer} ->
        json(conn, %{status: "success", data: customer})

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def update(conn, %{"id" => id} = params) do
    # Convert params to atom keys
    inputs =
      try do
        Map.new(params, fn {k, v} -> {String.to_existing_atom(k), v} end)
      rescue
        _ -> params
      end
      |> Map.delete(:id)

    with {:ok, customer} <- Customer.by_id(id),
         {:ok, updated_customer} <- Customer.update(customer, inputs) do
      json(conn, %{status: "success", data: updated_customer})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, customer} <- Customer.by_id(id),
         :ok <- Customer.destroy(customer) do
      json(conn, %{status: "success", message: "Customer deleted"})
    end
  end
end
