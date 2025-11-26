defmodule McpWeb.InputValidation do
  @moduledoc """
  Input validation and sanitization for GDPR endpoints.
  """

  import Plug.Conn
  import Phoenix.Controller
  require Logger

  @doc """
  Validate and sanitize user ID parameter.
  """
  def validate_user_id(user_id) when is_binary(user_id) do
    case UUID.info(user_id) do
      {:ok, _uuid_info} -> {:ok, user_id}
      {:error, _reason} -> {:error, :invalid_uuid}
    end
  end

  def validate_user_id(_), do: {:error, :invalid_type}

  @doc """
  Validate and sanitize export format parameter.
  """
  def validate_export_format(format) when is_binary(format) do
    case String.downcase(format) do
      "json" -> {:ok, "json"}
      "csv" -> {:ok, "csv"}
      "xml" -> {:ok, "xml"}
      _ -> {:error, :unsupported_format}
    end
  end

  def validate_export_format(_), do: {:error, :invalid_type}

  @doc """
  Validate and sanitize deletion reason parameter.
  """
  def validate_deletion_reason(reason) when is_binary(reason) do
    sanitized = String.trim(reason)

    cond do
      byte_size(sanitized) == 0 ->
        {:error, :empty_reason}

      byte_size(sanitized) > 1000 ->
        {:error, :reason_too_long}

      String.contains?(sanitized, ["<script", "javascript:", "data:"]) ->
        {:error, :potentially_dangerous_content}

      true ->
        {:ok, sanitized}
    end
  end

  def validate_deletion_reason(_), do: {:error, :invalid_type}

  @doc """
  Validate and sanitize consent parameters.
  """
  def validate_consent_params(params) when is_map(params) do
    with {:ok, purposes} <- validate_consent_purposes(params["purposes"]),
         {:ok, legal_basis} <- validate_legal_basis(params["legal_basis"]),
         {:ok, consent_given} <- validate_consent_given(params["consent_given"]) do
      {:ok,
       %{
         purposes: purposes,
         legal_basis: legal_basis,
         consent_given: consent_given,
         valid_until: params["valid_until"] || get_default_expiry()
       }}
    else
      error -> error
    end
  end

  def validate_consent_params(_), do: {:error, :invalid_params}

  defp validate_consent_purposes(purposes) when is_list(purposes) do
    valid_purposes = ["marketing", "analytics", "personalization", "third_party_sharing"]

    sanitized_purposes =
      purposes
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 in valid_purposes))
      |> Enum.uniq()

    if Enum.empty?(sanitized_purposes) do
      {:error, :no_valid_purposes}
    else
      {:ok, sanitized_purposes}
    end
  end

  defp validate_consent_purposes(purposes) when is_binary(purposes) do
    validate_consent_purposes([purposes])
  end

  defp validate_consent_purposes(_), do: {:error, :invalid_purposes}

  defp validate_legal_basis(legal_basis) when is_binary(legal_basis) do
    valid_bases = [
      "consent",
      "contract",
      "legal_obligation",
      "vital_interests",
      "public_task",
      "legitimate_interests"
    ]

    sanitized = String.downcase(String.trim(legal_basis))

    if sanitized in valid_bases do
      {:ok, sanitized}
    else
      {:error, :invalid_legal_basis}
    end
  end

  defp validate_legal_basis(_), do: {:error, :invalid_legal_basis}

  defp validate_consent_given(value) when is_boolean(value) do
    {:ok, value}
  end

  defp validate_consent_given("true"), do: {:ok, true}
  defp validate_consent_given("false"), do: {:ok, false}
  defp validate_consent_given("1"), do: {:ok, true}
  defp validate_consent_given("0"), do: {:ok, false}

  defp validate_consent_given(_), do: {:error, :invalid_consent_value}

  defp get_default_expiry do
    DateTime.add(DateTime.utc_now(), 365, :day)
  end

  @doc """
  Validate pagination parameters.
  """
  def validate_pagination_params(params) when is_map(params) do
    page = validate_integer_param(params["page"], 1, 1_000_000)
    limit = validate_integer_param(params["limit"], 10, 100)

    {:ok,
     %{
       page: page,
       limit: limit,
       offset: (page - 1) * limit
     }}
  end

  def validate_pagination_params(_), do: {:ok, %{page: 1, limit: 10, offset: 0}}

  defp validate_integer_param(value, default, max) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 and int <= max -> int
      {int, ""} when int <= 0 -> default
      {int, ""} when int > max -> max
      _ -> default
    end
  end

  defp validate_integer_param(_, default, _), do: default

  @doc """
  Sanitize string for logging (remove sensitive data).
  """
  def sanitize_for_logging(value) when is_binary(value) do
    value
    # Limit length
    |> String.slice(0, 100)
    # Replace special chars
    |> String.replace(~r/[^\w\s\-_.,]/, "*")
  end

  def sanitize_for_logging(value) when is_map(value) do
    "MAP#{:erlang.phash2(value)}"
  end

  def sanitize_for_logging(value), do: "VAL#{:erlang.phash2(value)}"

  @doc """
  Plug for validating GDPR input parameters.
  """
  def validate_gdpr_input(conn, validation_func) when is_function(validation_func, 1) do
    case validation_func.(conn.params) do
      {:ok, validated_params} ->
        assign(conn, :validated_params, validated_params)

      {:error, reason} ->
        request_id = conn.assigns[:gdpr_request_id] || "unknown"

        log_validation_error(conn, reason, conn.params)

        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Invalid input parameters",
          reason: format_validation_error(reason),
          request_id: request_id
        })
        |> halt()
    end
  end

  def validate_gdpr_input(conn, _validation_func) do
    request_id = conn.assigns[:gdpr_request_id] || "unknown"

    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "Invalid request format",
      request_id: request_id
    })
    |> halt()
  end

  defp log_validation_error(conn, reason, params) do
    sanitized_params = sanitize_for_logging(params)

    Logger.warning("GDPR Input Validation Failed", %{
      reason: reason,
      ip_address: conn.assigns[:gdpr_ip_address],
      user_agent: conn.assigns[:gdpr_user_agent],
      endpoint: conn.request_path,
      method: conn.method,
      sanitized_params: sanitized_params,
      request_id: conn.assigns[:gdpr_request_id]
    })
  end

  defp format_validation_error(:invalid_uuid), do: "Invalid user ID format"

  defp format_validation_error(:unsupported_format),
    do: "Unsupported export format. Supported: json, csv, xml"

  defp format_validation_error(:empty_reason), do: "Deletion reason cannot be empty"

  defp format_validation_error(:reason_too_long),
    do: "Deletion reason is too long (max 1000 characters)"

  defp format_validation_error(:potentially_dangerous_content),
    do: "Deletion reason contains potentially dangerous content"

  defp format_validation_error(:invalid_params), do: "Invalid request parameters"
  defp format_validation_error(:no_valid_purposes), do: "No valid consent purposes provided"
  defp format_validation_error(:invalid_purposes), do: "Invalid consent purposes"
  defp format_validation_error(:invalid_legal_basis), do: "Invalid legal basis"
  defp format_validation_error(:invalid_consent_value), do: "Invalid consent value"
  defp format_validation_error(reason), do: "Validation error: #{inspect(reason)}"

  @doc """
  Validate export request parameters.
  """
  def validate_export_params(params) when is_map(params) do
    with {:ok, format} <- validate_export_format(params["format"]),
         :ok <- validate_safety_of_params(params, ["format", "purpose"]) do
      {:ok,
       %{
         format: format
       }}
    else
      error -> error
    end
  end

  def validate_export_params(_), do: {:error, :invalid_params}

  @doc """
  Validate deletion request parameters.
  """
  def validate_deletion_params(params) when is_map(params) do
    case validate_deletion_reason(params["reason"]) do
      {:ok, reason} -> {:ok, %{reason: reason}}
      error -> error
    end
  end

  def validate_deletion_params(_), do: {:error, :invalid_params}

  @doc """
  Validate admin deletion request parameters.
  """
  def validate_admin_deletion_params(params) when is_map(params) do
    with {:ok, user_id} <- validate_user_id(params["user_id"]),
         {:ok, reason} <- validate_deletion_reason(params["reason"]) do
      {:ok,
       %{
         user_id: user_id,
         reason: reason
       }}
    else
      error -> error
    end
  end

  def validate_admin_deletion_params(_), do: {:error, :invalid_params}

  defp validate_safety_of_params(params, allowed_keys)
       when is_map(params) and is_list(allowed_keys) do
    Enum.each(allowed_keys, fn key ->
      value = Map.get(params, key)
      validate_param_value(key, value)
    end)

    :ok
  catch
    {:error, reason} -> {:error, reason}
  end

  defp validate_param_value(_key, nil), do: :ok
  defp validate_param_value(_key, value) when not is_binary(value), do: :ok

  defp validate_param_value(key, value) when is_binary(value) do
    if contains_dangerous_content?(value) do
      throw({:error, :potentially_dangerous_content})
    end
  end

  defp validate_safety_of_params(_, _), do: {:error, :invalid_params}

  @doc """
  Check if a string contains potentially dangerous content.
  """
  def contains_dangerous_content?(input) when is_binary(input) do
    dangerous_patterns = [
      ~r/<script/i,
      ~r/javascript:/i,
      ~r/data:/i,
      ~r/vbscript:/i,
      ~r/on\w+\s*=/i,
      ~r/<iframe/i,
      ~r/<object/i,
      ~r/<embed/i,
      ~r/<form/i,
      ~r/<input/i,
      ~r/<button/i
    ]

    Enum.any?(dangerous_patterns, fn pattern ->
      Regex.match?(pattern, input)
    end)
  end

  def contains_dangerous_content?(_), do: false
end
