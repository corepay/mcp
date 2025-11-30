defmodule Mcp.Underwriting.Adapters.ComplyCube do
  @moduledoc """
  Adapter for ComplyCube identity verification service.
  """
  
  require Logger

  def verify_identity(applicant_data, _opts \\ %{}) do
    with {:ok, client} <- create_client(applicant_data),
         {:ok, check} <- create_check(client["id"], "standard_screening_check") do
      {:ok, %{
        id: check["id"],
        check_id: check["id"],
        status: "pending",
        client_id: client["id"],
        score: 0.0, # Initial score
        provider: "comply_cube",
        details: %{checks: ["document", "face"]}
      }}
    end
  end

  def screen_business(business_data, _opts \\ %{}) do
    with {:ok, client} <- create_corporate_client(business_data),
         {:ok, check} <- create_check(client["id"], "company_check") do
      {:ok, %{
        id: check["id"],
        check_id: check["id"],
        status: "pending",
        client_id: client["id"]
      }}
    end
  end

  def document_check(image, _type, context) do
    client_id = context[:client_id]
    
    with {:ok, doc} <- upload_document(client_id, image, "passport"),
         {:ok, check} <- create_check(client_id, "document_check", doc["id"]) do
      {:ok, %{
        id: check["id"],
        check_id: check["id"],
        status: "pending",
        document_id: doc["id"]
      }}
    end
  end

  # Private Helpers

  defp client do
    config = Application.get_env(:mcp, :comply_cube, [])
    base_url = config[:base_url] || "https://api.complycube.com/v1"
    api_key = config[:api_key]

    Req.new(base_url: base_url)
    |> Req.Request.put_header("Authorization", api_key)
    |> Req.Request.put_header("Content-Type", "application/json")
  end

  defp create_client(data) do
    payload = %{
      type: "person",
      email: data["email"],
      personDetails: %{
        firstName: data["first_name"],
        lastName: data["last_name"],
        dob: data["dob"]
      }
    }

    client()
    |> Req.post(url: "/clients", json: payload)
    |> handle_response()
  end

  defp create_corporate_client(data) do
    payload = %{
      type: "corporate",
      email: data["email"],
      companyDetails: %{
        name: data["business_name"],
        registrationNumber: data["registration_number"]
      }
    }

    client()
    |> Req.post(url: "/clients", json: payload)
    |> handle_response()
  end

  defp create_check(client_id, type, document_id \\ nil) do
    payload = %{
      clientId: client_id,
      type: type
    }
    
    payload = if document_id, do: Map.put(payload, :documentId, document_id), else: payload

    client()
    |> Req.post(url: "/checks", json: payload)
    |> handle_response()
  end

  defp upload_document(client_id, _image, type) do
    payload = %{
      clientId: client_id,
      type: type,
      fileName: "document.jpg",
      data: "base64_encoded_content" # In real impl, would encode image
    }

    client()
    |> Req.post(url: "/documents", json: payload)
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: _status, body: body}}) do
    {:error, body}
  end

  defp handle_response({:error, reason}), do: {:error, reason}
end
