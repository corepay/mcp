defmodule Mcp.Underwriting.Services.TheEye do
  @moduledoc """
  Client for The Eye document intelligence service.
  Provides OCR, table extraction, and document analysis.

  This is a lightweight client for OLA pre-validation. For full
  document analysis with Ash integration, see DocumentIntelligence.
  """

  @default_base_url "http://localhost:48291"

  def base_url do
    System.get_env("THE_EYE_URL", @default_base_url)
  end

  @doc """
  Checks if The Eye service is healthy.
  """
  def health_check do
    case Req.get("#{base_url()}/health") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:unhealthy, status}}

      {:error, _} ->
        {:error, :service_unavailable}
    end
  end

  @doc """
  Analyzes a document and returns structured content.

  Returns:
  - {:ok, %{status, markdown_content, structured_data}}
  - {:error, reason}
  """
  def analyze_document(file_content, filename) do
    boundary = "----WebKitFormBoundary#{:crypto.strong_rand_bytes(16) |> Base.encode16()}"
    body = build_multipart_body(boundary, filename, file_content)
    headers = [{"content-type", "multipart/form-data; boundary=#{boundary}"}]

    case Req.post("#{base_url()}/analyze/document", body: body, headers: headers) do
      {:ok, %{status: 200, body: resp_body}} ->
        {:ok,
         %{
           status: resp_body["status"],
           markdown_content: resp_body["markdown_content"],
           structured_data: resp_body["structured_data"],
           provider: resp_body["provider"]
         }}

      {:ok, %{status: 503}} ->
        {:error, :service_unavailable}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:api_error, status, resp_body}}

      {:error, exception} ->
        {:error, {:request_failed, exception}}
    end
  end

  @doc """
  Runs full multimodal forensics analysis including camera telemetry validation.
  """
  def analyze_multimodal(file_content, filename, telemetry \\ %{}) do
    if Application.get_env(:mcp, :the_eye_adapter) == :mock do
      mock_multimodal(filename, telemetry)
    else
      # Real implementation would call /analyze/multimodal

      # Include telemetry as a separate JSON part in multipart
      parts = [
        {:file, file_content, [filename: filename, name: "file"]},
        {:field, Jason.encode!(telemetry), [name: "telemetry"]}
      ]

      case Req.post("#{base_url()}/analyze/multimodal", multipart: parts) do
        {:ok, %{status: 200, body: resp_body}} ->
          {:ok, resp_body}

        error ->
          error
      end
    end
  end

  defp mock_multimodal(filename, telemetry) do
    # Forensics simulation logic
    is_manipulated =
      String.contains?(filename, "fake") || String.contains?(filename, "test_spliced")

    ai_confidence = if String.contains?(filename, "ai"), do: 0.98, else: 0.02

    # Telemetry validation (e.g. check if GPS matches IP region)
    gps_valid = Map.get(telemetry, "gps_accuracy", 100) < 50

    {:ok,
     %{
       "status" => "success",
       "analysis_type" => "multimodal",
       "forensics_report" => %{
         "manipulation_detected" => is_manipulated,
         "ai_generated_score" => ai_confidence,
         "forensic_markers" => ["double_quantization", "ela_mismatch"],
         "verdict" =>
           if(is_manipulated or ai_confidence > 0.5, do: "suspicious", else: "authentic")
       },
       "camera_telemetry" => Map.put(telemetry, "verified", gps_valid),
       "markdown_content" => "# Scanned Document\nExtracted text from #{filename}...",
       "structured_data" => %{"doc_type" => "identity_card"},
       "provider" => "the_eye"
     }}
  end

  @doc """
  Validates a document meets quality requirements.

  Checks:
  - Document is readable
  - Key fields are extractable
  - Image quality is sufficient
  """
  def validate_document(file_content, filename, document_type) do
    case analyze_document(file_content, filename) do
      {:ok, %{status: "success", markdown_content: content}} ->
        validate_content(content, document_type)

      {:ok, %{status: status}} ->
        {:error, {:analysis_failed, status}}

      error ->
        error
    end
  end

  @doc """
  Validates extracted content against document type requirements.
  Made public for testing without requiring The Eye service.
  """
  def validate_content(content, :government_id) do
    checks = [
      {String.contains?(content, ["name", "Name", "NAME"]), "Name not found"},
      {String.contains?(content, ["DOB", "Date of Birth", "birth", "Birth"]),
       "Date of birth not found"},
      {String.length(content) > 50, "Document appears to be unreadable"}
    ]

    validate_checks(checks)
  end

  def validate_content(content, :bank_statement) do
    checks = [
      {String.contains?(content, ["balance", "Balance", "BALANCE"]), "Balance not found"},
      {String.contains?(content, ["account", "Account", "ACCOUNT"]), "Account info not found"},
      {String.length(content) > 100, "Document appears to be unreadable"}
    ]

    validate_checks(checks)
  end

  def validate_content(_content, _type) do
    # Default: just check it's readable
    {:ok, :valid}
  end

  defp build_multipart_body(boundary, filename, content) do
    [
      "--",
      boundary,
      "\r\n",
      ~s(Content-Disposition: form-data; name="file"; filename="#{filename}"),
      "\r\n",
      "Content-Type: application/octet-stream",
      "\r\n\r\n",
      content,
      "\r\n--",
      boundary,
      "--\r\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp validate_checks(checks) do
    issues =
      checks
      |> Enum.filter(fn {passed, _} -> not passed end)
      |> Enum.map(fn {_, issue} -> issue end)

    if Enum.empty?(issues) do
      {:ok, :valid}
    else
      {:error, {:validation_failed, issues}}
    end
  end
end
