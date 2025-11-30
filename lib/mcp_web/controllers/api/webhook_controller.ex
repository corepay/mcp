defmodule McpWeb.Api.WebhookController do
  use McpWeb, :controller

  alias Mcp.Webhooks.Endpoint
  alias Mcp.Webhooks.Endpoint

  action_fallback McpWeb.FallbackController

  def create(conn, params) do
    # In a real app, we'd get tenant_id/merchant_id from conn.assigns
    # For now, we'll assume they are passed in params or derived from context
    create_params = Map.take(params, ["url", "secret", "events", "tenant_id", "merchant_id"])

    with {:ok, endpoint} <- Ash.create(Endpoint, create_params) do
      conn
      |> put_status(:created)
      |> render(:show, endpoint: endpoint)
    end
  end

  def index(conn, _params) do
    # Filter by tenant/merchant from context if available
    # For now, just list all (or filter by query params if implemented)
    endpoints = Ash.read!(Endpoint)
    render(conn, :index, endpoints: endpoints)
  end

  def update(conn, %{"id" => id} = params) do
    endpoint = Ash.get!(Endpoint, id)
    update_params = Map.take(params, ["url", "secret", "events", "enabled"])

    with {:ok, updated_endpoint} <- Ash.update(endpoint, update_params) do
      render(conn, :show, endpoint: updated_endpoint)
    end
  end

  def delete(conn, %{"id" => id}) do
    endpoint = Ash.get!(Endpoint, id)
    with :ok <- Ash.destroy(endpoint) do
      send_resp(conn, :no_content, "")
    end
  end
end
