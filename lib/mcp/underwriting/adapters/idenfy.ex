defmodule Mcp.Underwriting.Adapters.Idenfy do
  @moduledoc """
  iDenfy adapter for the Underwriting Gateway.
  """

  @behaviour Mcp.Underwriting.Adapter

  require Logger

  @base_url "https://ivs.idenfy.com"

  @impl true
  def verify_identity(applicant_data, _context) do
    client = get_client()

    # iDenfy creates a session (token) and then redirects the user
    payload = %{
      # Using email as client ID for correlation
      clientId: applicant_data["email"] || "unknown",
      firstName: applicant_data["first_name"],
      lastName: applicant_data["last_name"],
      # Optional: success/error URLs could be configured
      successUrl: "http://localhost:4000/underwriting/success",
      errorUrl: "http://localhost:4000/underwriting/error"
    }

    case Req.post(client, url: "/api/v2/token", json: payload) do
      {:ok, %{status: 201, body: body}} ->
        token = body["authToken"]

        {:ok,
         %{
           provider: "idenfy",
           session_id: token,
           status: "pending",
           redirect_url: "#{@base_url}/api/v2/redirect?authToken=#{token}"
         }}

      {:ok, response} ->
        Logger.error("iDenfy token generation failed: #{inspect(response.body)}")
        {:error, "API Error: #{inspect(response.body)}"}

      {:error, reason} ->
        Logger.error("iDenfy connection failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def screen_business(business_data, _context) do
    client = get_client()

    # KYB Token Generation
    payload = %{
      tokenType: "FORM",
      clientId: business_data["email"] || "unknown_business"
    }

    case Req.post(client, url: "/kyb/tokens", json: payload) do
      {:ok, %{status: 201, body: body}} ->
        token = body["tokenString"]
        # KYB usually involves a form link
        {:ok,
         %{
           provider: "idenfy",
           check_id: token,
           status: "pending",
           # Constructing a hypothetical KYB link, actual link format might differ
           redirect_url: "https://kyb.idenfy.com/form/#{token}"
         }}

      {:ok, response} ->
        Logger.error("iDenfy KYB token failed: #{inspect(response.body)}")
        {:error, "API Error: #{inspect(response.body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def check_watchlist(name, context) do
    client = get_client()

    payload = %{
      name: name,
      # optional metadata from context
      birthDate: context[:birth_date],
      country: context[:country]
    }

    case Req.post(client, url: "/api/v2/aml/search", json: payload) do
      {:ok, %{status: 200, body: body}} ->
        # If there are NO hits, it's clear
        status = if Enum.empty?(body["hits"] || []), do: "clear", else: "match_found"

        {:ok,
         %{
           provider: "idenfy",
           status: status,
           hits: body["hits"],
           aml_reference: body["reference"]
         }}

      {:ok, response} ->
        Logger.error("iDenfy AML check failed: #{inspect(response.body)}")
        {:error, "API Error"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def document_check(document_image, type, _context) do
    # Direct processing requires a token first
    client = get_client()

    # 1. Generate Token
    token_payload = %{clientId: "doc_check_#{System.unique_integer()}"}

    # Map internal types to iDenfy types
    image_key =
      case type do
        :identity -> "FRONT"
        # Fallback
        _ -> "FRONT"
      end

    with {:ok, %{status: 201, body: %{"authToken" => token}}} <-
           Req.post(client, url: "/api/v2/token", json: token_payload),

         # 2. Upload/Process
         process_payload = %{
           authToken: token,
           images: %{
             image_key => Base.encode64(document_image)
           }
         },
         {:ok, %{status: 200, body: _body}} <-
           Req.post(client, url: "/api/v2/process", json: process_payload) do
      {:ok,
       %{
         provider: "idenfy",
         # ScanRef is usually associated with the token
         check_id: token,
         status: "pending"
       }}
    else
      {:ok, response} ->
        Logger.error("iDenfy document check failed: #{inspect(response.body)}")
        {:error, "API Error"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_client do
    config = Application.get_env(:mcp, :idenfy, [])
    api_key = config[:api_key]
    api_secret = config[:api_secret]
    base_url = config[:base_url] || @base_url

    # Basic Auth
    auth = Base.encode64("#{api_key}:#{api_secret}")

    Req.new(base_url: base_url)
    |> Req.Request.put_header("Authorization", "Basic #{auth}")
    |> Req.Request.put_header("Content-Type", "application/json")
  end
end
