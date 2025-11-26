defmodule McpWeb.PaymentsController do
  use McpWeb, :controller
  require Logger

  alias Mcp.Payments.Charge
  alias Mcp.Payments.Gateways.Factory
  alias Mcp.Payments.TransactionReactor

  def create(conn, params) do
    # Convert params to atom keys for Reactor input
    inputs = %{
      amount: params["amount"],
      currency: params["currency"],
      customer_id: params["customer_id"],
      payment_method_id: params["payment_method_id"],
      provider: if(params["provider"], do: String.to_existing_atom(params["provider"]))
    }

    # Filter out nil values
    inputs = Map.reject(inputs, fn {_k, v} -> is_nil(v) end)

    case TransactionReactor.process_payment(inputs) do
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
    case Charge.get_by_id(id) do
      {:ok, charge} ->
        json(conn, %{status: "success", data: charge})

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Charge not found"})
    end
  end

  # QorPay Specific Endpoints

  def board_merchant(conn, params) do
    # Hardcoded to QorPay as per route
    adapter = Factory.get_adapter(:qorpay)

    case adapter.create_merchant(params, %{}) do
      {:ok, result} ->
        json(conn, %{status: "success", data: result})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  def create_form_session(conn, params) do
    adapter = Factory.get_adapter(:qorpay)

    case adapter.create_form_session(params, %{}) do
      {:ok, result} ->
        json(conn, %{status: "success", data: result})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  def show_transaction(conn, %{"id" => id} = params) do
    provider = Map.get(params, "provider", "qorpay") |> String.to_existing_atom()
    adapter = Factory.get_adapter(provider)

    case adapter.get_transaction(id, %{}) do
      {:ok, transaction} ->
        json(conn, %{status: "success", data: transaction})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  def lookup_bin(conn, %{"bin" => bin}) do
    adapter = Factory.get_adapter(:qorpay)

    case adapter.lookup_bin(bin, %{}) do
      {:ok, result} ->
        json(conn, %{status: "success", data: result})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end
end
