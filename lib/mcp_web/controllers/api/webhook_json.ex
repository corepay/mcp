defmodule McpWeb.Api.WebhookJSON do
  alias Mcp.Webhooks.Endpoint

  def index(%{endpoints: endpoints}) do
    %{data: for(endpoint <- endpoints, do: data(endpoint))}
  end

  def show(%{endpoint: endpoint}) do
    %{data: data(endpoint)}
  end

  defp data(%Endpoint{} = endpoint) do
    %{
      id: endpoint.id,
      url: endpoint.url,
      secret: endpoint.secret, # In real app, might want to mask this
      events: endpoint.events,
      enabled: endpoint.enabled,
      inserted_at: endpoint.inserted_at,
      updated_at: endpoint.updated_at
    }
  end
end
