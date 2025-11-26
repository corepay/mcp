defmodule Mcp.Payments.Gateways.Stripe do
  @moduledoc """
  Stripe payment gateway adapter implementation.
  """

  @behaviour Mcp.Payments.Gateways.Adapter
  require Logger

  @impl true
  def authorize(_amount, _currency, _source, _context) do
    Logger.info("Stripe: Authorizing (Placeholder)")

    if System.get_env("FORCE_STRIPE_ERROR") do
      {:error, "Forced error"}
    else
      {:ok, %{id: "stripe_auth_123", status: "authorized"}}
    end
  end

  @impl true
  def capture(_transaction_id, _amount, _context) do
    {:ok, %{}}
  end

  @impl true
  def refund(_transaction_id, _amount, _context) do
    {:ok, %{}}
  end

  @impl true
  def void(_transaction_id, _context) do
    {:ok, %{}}
  end

  @impl true
  def create_customer(_customer_params, _context) do
    {:ok, %{}}
  end

  @impl true
  def tokenize(_payment_method_params, _context) do
    {:ok, %{}}
  end

  @impl true
  def verify_webhook_signature(_conn, _secret), do: :ok
  @impl true
  def handle_webhook(_payload), do: {:ok, %{}}

  @impl true
  def get_transaction(_id, _context), do: {:error, :not_implemented}

  # QorPay Specifics (Not implemented for Stripe)
  @impl true
  def create_merchant(_merchant_params, _context), do: {:error, :not_supported}
  @impl true
  def create_form_session(_form_params, _context), do: {:error, :not_supported}
  @impl true
  def lookup_bin(_bin, _context), do: {:error, :not_supported}
end
