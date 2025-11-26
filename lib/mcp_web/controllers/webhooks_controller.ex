defmodule McpWeb.WebhooksController do
  use McpWeb, :controller
  require Logger

  alias Mcp.Payments.Gateways.Factory

  def handle_webhook(conn, %{"provider" => provider_name}) do
    provider = String.to_existing_atom(provider_name)
    adapter = Factory.get_adapter(provider)
    secret = Application.get_env(:mcp, provider)[:webhook_secret]

    with :ok <- adapter.verify_webhook_signature(conn, secret),
         body <- conn.assigns[:raw_body] || "",
         params <- Jason.decode!(body),
         {:ok, event} <- adapter.handle_webhook(params) do
      # Dispatch event (log for now)
      Logger.info("Webhook received: #{inspect(event)}")

      # Here we would dispatch to a reactor or handler
      # Mcp.Payments.WebhookHandler.handle_event(event)

      conn
      |> put_status(:ok)
      |> json(%{status: "received"})
    else
      {:error, reason} ->
        Logger.warning("Webhook processing failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Invalid request"})
    end
  rescue
    e ->
      Logger.error("Webhook error: #{inspect(e)}")

      conn
      |> put_status(:internal_server_error)
      |> json(%{status: "error", message: "Internal error"})
  end
end
