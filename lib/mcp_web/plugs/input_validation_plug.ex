defmodule McpWeb.Plugs.InputValidationPlug do
  @moduledoc """
  Plug for validating input parameters based on validation function.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, opts) do
    validation_func = Keyword.get(opts, :validate)

    if is_function(validation_func, 1) do
      case validation_func.(conn.params) do
        {:ok, validated_params} ->
          assign(conn, :validated_params, validated_params)

        {:error, reason} ->
          request_id = conn.assigns[:gdpr_request_id] || "unknown"

          conn
          |> put_status(:bad_request)
          |> json(%{
            error: "Invalid input parameters",
            reason: format_validation_error(reason),
            request_id: request_id
          })
          |> halt()
      end
    else
      conn
    end
  end

  defp format_validation_error(:invalid_uuid), do: "Invalid user ID format"
  defp format_validation_error(:unsupported_format), do: "Unsupported export format. Supported: json, csv, xml"
  defp format_validation_error(:empty_reason), do: "Deletion reason cannot be empty"
  defp format_validation_error(:reason_too_long), do: "Deletion reason is too long (max 1000 characters)"
  defp format_validation_error(:potentially_dangerous_content), do: "Input contains potentially dangerous content"
  defp format_validation_error(:invalid_params), do: "Invalid request parameters"
  defp format_validation_error(:no_valid_purposes), do: "No valid consent purposes provided"
  defp format_validation_error(:invalid_purposes), do: "Invalid consent purposes"
  defp format_validation_error(:invalid_legal_basis), do: "Invalid legal basis"
  defp format_validation_error(:invalid_consent_value), do: "Invalid consent value"
  defp format_validation_error(reason), do: "Validation error: #{inspect(reason)}"
end