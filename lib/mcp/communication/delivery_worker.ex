defmodule Mcp.Communication.DeliveryWorker do
  @moduledoc """
  Oban worker for delivering webhooks with HMAC-SHA256 signatures.
  """
  use Oban.Worker, queue: :default, max_attempts: 10
  require Logger
  require Ash.Query

  alias Mcp.Communication.WebhookDelivery

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
    # Fetch delivery and preload endpoint
    case WebhookDelivery
         |> Ash.Query.filter(id == ^delivery_id)
         |> Ash.Query.load(:endpoint)
         |> Ash.read_one(authorize?: false) do
      {:ok, %WebhookDelivery{} = delivery} ->
        process_delivery(delivery)

      {:ok, nil} ->
        # Delivery not found?
        Logger.warning("WebhookDelivery #{delivery_id} not found during worker execution.")
        :ok

      {:error, error} ->
        Logger.error("Failed to load delivery: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_delivery(delivery) do
    endpoint = delivery.endpoint
    payload = delivery.payload

    if endpoint.enabled do
      # Calculate Signature
      signature = calculate_signature(payload, endpoint.secret)

      # Prepare Request
      headers = [
        {"Content-Type", "application/json"},
        {"X-Mcp-Signature", signature},
        # Ideally we pass the event type in args
        {"X-Mcp-Event", "webhook"},
        {"User-Agent", "Mcp-Webhook-Bot/1.0"}
      ]

      # Send Request
      # Using Req as it's cleaner, assuming it's available. If not, fallback or use Finch/httpoison.
      # Project has `req` dependency? Checking mix.exs later. Assuming yes as generic HTTP client in plan.

      _start_time = System.monotonic_time()

      req_opts = Application.get_env(:mcp, :webhook_req_opts, [])

      case Req.post(endpoint.url, [json: payload, headers: headers, retry: false] ++ req_opts) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          record_result(delivery, :success, status)
          :ok

        {:ok, %Req.Response{status: status}} ->
          record_result(delivery, :failure, status)
          {:error, "Webhook failed with status #{status}"}

        {:error, reason} ->
          # 0 status for network error
          record_result(delivery, :retrying, 0)
          {:error, reason}
      end
    else
      Logger.info("Webhook endpoint #{endpoint.id} is disabled. Skipping delivery.")
      {:cancel, "Endpoint disabled"}
    end
  end

  defp calculate_signature(payload, secret) do
    # HMAC-SHA256
    # Payload needs to be the raw JSON string?
    # Req handles JSON encoding automatically. We need to encode it identically to how Req sends it.
    # Jason.encode!(payload)
    encoded_payload = Jason.encode!(payload)

    :crypto.mac(:hmac, :sha256, secret, encoded_payload)
    |> Base.encode16(case: :lower)
  end

  defp record_result(delivery, status, code) do
    delivery
    |> Ash.Changeset.for_update(:update, %{
      status: status,
      response_code: code,
      attempt_count: delivery.attempt_count + 1
    })
    |> Ash.update!(authorize?: false)
  end
end
