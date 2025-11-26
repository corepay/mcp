defmodule Mcp.Payments.Gateways.Adapter do
  @moduledoc """
  Behaviour for payment gateway adapters.
  """

  @type context :: map()
  @type response :: {:ok, map()} | {:error, any()}

  @callback authorize(
              amount :: integer(),
              currency :: String.t(),
              source :: map(),
              context :: context()
            ) :: response()
  @callback capture(transaction_id :: String.t(), amount :: integer(), context :: context()) ::
              response()
  @callback refund(transaction_id :: String.t(), amount :: integer(), context :: context()) ::
              response()
  @callback void(transaction_id :: String.t(), context :: context()) :: response()
  @callback create_customer(customer_params :: map(), context :: context()) :: response()
  @callback tokenize(payment_method_params :: map(), context :: context()) :: response()

  @callback verify_webhook_signature(conn :: Plug.Conn.t(), secret :: String.t()) ::
              :ok | {:error, any()}
  @callback handle_webhook(payload :: map()) :: {:ok, map()} | {:error, any()}
  @callback get_transaction(id :: String.t(), context :: map()) :: {:ok, map()} | {:error, any()}

  # QorPay Specifics
  @callback create_merchant(merchant_params :: map(), context :: context()) :: response()
  @callback create_form_session(form_params :: map(), context :: context()) :: response()
  @callback lookup_bin(bin :: String.t(), context :: context()) :: response()
end
