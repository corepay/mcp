defmodule Mcp.Underwriting.Adapters.QorPayBoarding do
  @moduledoc """
  Adapter for merchant boarding via QorPay.
  """
  @behaviour Mcp.Underwriting.Adapters.BoardingAdapter
  require Logger

  alias Mcp.Payments.Gateways.QorPay
  alias Mcp.Platform.Merchant
  alias Mcp.Utils.CircuitBreaker

  @cb_service {:boarding, :qorpay}

  @impl true
  def board_merchant(application, profile) do
    CircuitBreaker.execute(@cb_service, fn ->
      do_board_merchant(application, profile)
    end)
  end

  defp do_board_merchant(application, profile) do
    Logger.info("📤 Boarding to QorPay: #{application.id}")

    # 1. Fetch Merchant Data
    merchant =
      Merchant
      |> Ash.get!(application.subject_id, tenant: application.__metadata__.tenant)

    # 2. Map Underwriting/Platform data to QorPay Boarding Params
    merchant_params = %{
      "business_name" => merchant.business_name,
      "dba_name" => merchant.dba_name || merchant.business_name,
      "ein" => merchant.ein,
      "website" => merchant.website_url,
      "email" => merchant.support_email,
      "phone" => merchant.phone,
      "address" => %{
        "line1" => merchant.address_line1,
        "line2" => merchant.address_line2,
        "city" => merchant.city,
        "state" => merchant.state,
        "zip" => merchant.postal_code,
        "country" => merchant.country || "US"
      },
      "appetite" => %{
        "risk_level" => to_string(merchant.risk_level),
        "min_score" => profile.appetite_rules["min_score"],
        "max_monthly_volume" => profile.appetite_rules["max_monthly_volume"]
      },
      "metadata" => %{
        "platform_merchant_id" => merchant.id,
        "underwriting_application_id" => application.id,
        "bank_profile_id" => profile.id
      }
    }

    # 3. Call QorPay Gateway
    case QorPay.create_merchant(merchant_params, %{}) do
      {:ok, response} ->
        # Status can be :active or :pending based on gateway response
        status = if response["status"] == "approved", do: :active, else: :pending

        {:ok,
         %{
           mid: response["mid"] || ("QOR_" <> Ecto.UUID.generate()) |> String.slice(0, 10),
           tid: response["tid"] || ("QT_" <> Ecto.UUID.generate()) |> String.slice(0, 8),
           status: status
         }}

      {:error, reason} ->
        Logger.error("❌ QorPay Boarding Failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def check_status(boarding) do
    CircuitBreaker.execute(@cb_service, fn ->
      # Simulated QorPay status check
      # In reality, this would call QorPay.get_merchant_status(boarding.mid)
      case QorPay.get_merchant_status(boarding.mid, %{}) do
        {:ok, %{"status" => "approved"}} -> {:ok, %{status: :active}}
        {:ok, _} -> {:ok, %{status: :pending}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end
