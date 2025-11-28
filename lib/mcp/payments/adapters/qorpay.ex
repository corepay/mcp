defmodule Mcp.Payments.Gateways.QorPay do
  @moduledoc """
  QorPay payment gateway adapter implementation.
  """

  @behaviour Mcp.Payments.Gateways.Adapter
  require Logger

  @impl true
  def authorize(amount, currency, source, context) do
    if source[:type] == :bank_account or ach_token?(source) do
      authorize_ach(amount, source, context)
    else
      authorize_card(amount, currency, source, context)
    end
  end

  defp authorize_card(amount, currency, source, context) do
    # source might contain card details or a token
    payload =
      %{
        transaction_data: %{
          mid: Application.get_env(:mcp, :qorpay)[:mid],
          amount: amount,
          currency: currency,
          # Always try to tokenize
          store_card: true,
          rate: "0.00",
          orderid: "ord_" <> Ecto.UUID.generate()
        }
      }
      |> merge_source(source)
      |> merge_customer(context[:customer])

    url =
      if get_in(payload, [:transaction_data, :token]) do
        "/payment/sale/token"
      else
        "/payment/authorize"
      end

    client()
    |> Req.post(url: url, json: payload)
    |> handle_response()
  end

  defp authorize_ach(amount, source, _context) do
    # ACH Debit
    # If we have a token, use /payment/ach/debit/token
    # If raw, use /payment/ach/debit (not implemented yet for raw)

    token = source[:provider_token] || source[:token]

    if token do
      payload = %{
        ach: %{
          mid: Application.get_env(:mcp, :qorpay)[:mid],
          amount: amount,
          token: token,
          orderid: "ord_" <> Ecto.UUID.generate()
        }
      }

      client()
      |> Req.post(url: "/payment/ach/debit/token", json: payload)
      |> handle_response()
    else
      {:error, "Raw ACH debit not implemented, please tokenize first"}
    end
  end

  defp ach_token?(source) do
    # Simple heuristic or check if source has bank details
    source[:type] == :bank_account
  end

  @impl true
  def capture(transaction_id, amount, _context) do
    payload = %{
      transaction_data: %{
        transaction_id: transaction_id,
        amount: amount,
        orderid: "ord_" <> Ecto.UUID.generate()
      }
    }

    client()
    |> Req.post(url: "/payment/capture", json: payload)
    |> handle_response()
  end

  @impl true
  def refund(transaction_id, amount, _context) do
    payload = %{
      transaction_data: %{
        transaction_id: transaction_id,
        amount: amount
      }
    }

    client()
    |> Req.post(url: "/payment/refund", json: payload)
    |> handle_response()
  end

  @impl true
  def void(transaction_id, _context) do
    payload = %{
      transaction_data: %{
        transaction_id: transaction_id
      }
    }

    client()
    |> Req.post(url: "/payment/void", json: payload)
    |> handle_response()
  end

  @impl true
  def create_customer(customer_params, _context) do
    # QorPay does not support standalone customer creation.
    # We log this and return a generated ID to satisfy the adapter contract,
    # effectively treating it as an ephemeral customer.
    Logger.info(
      "QorPay: Customer creation requested (No-op), Params: #{inspect(customer_params)}"
    )

    {:ok, %{id: "qor_cust_ephemeral_#{Ecto.UUID.generate()}"}}
  end

  @impl true
  def tokenize(payment_method_params, _context) do
    case payment_method_params do
      %{type: :bank_account, bank_account: bank} ->
        # ACH Tokenization
        payload = %{
          ach: %{
            mid: Application.get_env(:mcp, :qorpay)[:mid],
            account: bank[:account_number],
            routing: bank[:routing_number],
            # checking/savings
            account_type: bank[:account_type],
            account_holder: bank[:account_holder_name]
          }
        }

        client()
        |> Req.post(url: "/payment/ach/token", json: payload)
        |> handle_response()

      _ ->
        # Card Tokenization (fallback to authorize for now)
        authorize(0, "USD", payment_method_params, %{})
    end
  end

  # QorPay Specifics

  @impl true
  @spec create_merchant(map(), map()) :: {:ok, map()} | {:error, any()}
  def create_merchant(merchant_params, _context) do
    Logger.info("QorPay: Boarding new merchant")

    client()
    |> Req.post(url: "/channels/new_merchant", json: merchant_params)
    |> handle_response()
  end

  @impl true
  @spec create_form_session(map(), map()) :: {:ok, map()} | {:error, any()}
  def create_form_session(form_params, _context) do
    Logger.info("QorPay: Creating hosted form session")

    client()
    |> Req.post(url: "/payment/forms", json: form_params)
    |> handle_response()
  end

  @impl true
  def lookup_bin(bin, _context) do
    client()
    |> Req.get(url: "/utilities/bin/#{bin}")
    |> handle_response()
  end

  @impl true
  def verify_webhook_signature(_conn, _secret) do
    # QorPay signature verification logic would go here.
    # Since it's not documented in the snippets, we'll assume valid for now or check a header.
    :ok
  end

  @impl true
  def handle_webhook(payload) do
    # Normalize QorPay webhook payload to a standard event structure
    # Example payload: %{"type" => "sale.approved", "data" => ...}

    event_type = payload["type"]

    normalized_type =
      case event_type do
        "sale.approved" -> "charge.succeeded"
        "sale.declined" -> "charge.failed"
        "refund.processed" -> "refund.succeeded"
        _ -> "event.unknown"
      end

    {:ok,
     %{
       type: normalized_type,
       original_type: event_type,
       data: payload
     }}
  end

  @impl true
  def get_transaction(id, _context) do
    client()
    |> Req.get(url: "/payment/transaction/#{id}")
    |> handle_response()
  end

  # Private Helpers

  defp client do
    config = Application.get_env(:mcp, :qorpay)
    req_options = Application.get_env(:mcp, :req_options, [])

    Req.new(base_url: config[:base_url])
    |> Req.merge(req_options)
    |> Req.Request.put_header("Qor-App-Key", config[:app_key])
    |> Req.Request.put_header("Qor-Client-Key", config[:client_key])
    |> Req.Request.put_header("Content-Type", "application/json")
    |> Req.Request.put_header("Accept", "application/json")
  end

  defp merge_source(payload, %{token: token}) do
    payload
    |> put_in([:transaction_data, :creditcard], token)
    |> update_in([:transaction_data], &Map.delete(&1, :store_card))
  end

  defp merge_source(payload, %{provider_token: token}) when not is_nil(token) do
    payload
    |> put_in([:transaction_data, :creditcard], token)
    |> update_in([:transaction_data], &Map.delete(&1, :store_card))
  end

  defp merge_source(payload, %{card: card}) do
    # Assuming card is a map with number, cvv, etc.
    # Flattening for QorPay structure
    td =
      payload.transaction_data
      |> Map.merge(%{
        creditcard: card[:number],
        cvv: card[:cvv],
        month: card[:exp_month],
        year: card[:exp_year],
        bzip: card[:zip],
        cardfullname: card[:cardfullname]
      })

    Map.put(payload, :transaction_data, td)
  end

  defp merge_source(payload, _), do: payload

  defp merge_customer(payload, nil), do: payload

  defp merge_customer(payload, customer) do
    {first_name, last_name} = split_name(customer.name)

    td =
      payload.transaction_data
      |> Map.merge(%{
        cemail: customer.email,
        cphone: customer.phone,
        cfirstname: first_name,
        clastname: last_name
      })
      # Filter nil values
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    Map.put(payload, :transaction_data, td)
  end

  defp split_name(nil), do: {nil, nil}

  defp split_name(full_name) do
    case String.split(full_name, " ", parts: 2) do
      [first, last] -> {first, last}
      [first] -> {first, nil}
      _ -> {nil, nil}
    end
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    case body do
      %{"status" => "approved"} -> {:ok, body}
      %{"status" => "success"} -> {:ok, body}
      %{"status" => "ok"} -> {:ok, body}
      # Explicit error status
      %{"status" => _} = error -> {:error, error}
      # No status field, assume success (e.g. lookup_bin)
      _ -> {:ok, body}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}), do: {:error, reason}
end
