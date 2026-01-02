defmodule Mcp.Underwriting.Services.DocumentValidator do
  @moduledoc """
  Validates documents before submission using The Eye analysis.
  Provides immediate feedback on document quality and completeness.

  This service builds on TheEye to provide:
  - Quality scores
  - Specific suggestions for fixing issues
  - Graceful degradation when service unavailable
  """

  alias Mcp.Underwriting.Services.TheEye

  defstruct [:valid?, :quality_score, :issues, :suggestions, :extracted_data]

  @type t :: %__MODULE__{
          valid?: boolean(),
          quality_score: non_neg_integer(),
          issues: [String.t()],
          suggestions: [String.t()],
          extracted_data: map() | nil
        }

  @doc """
  Validates a document by analyzing its content and checking for required fields.

  Uses The Eye service for document analysis, then validates the extracted content
  against document type requirements.

  Returns:
  - `{:ok, %DocumentValidator{}}` when document passes validation
  - `{:error, %DocumentValidator{}}` when document fails validation
  """
  @spec validate(binary(), String.t(), atom()) :: {:ok, t()} | {:error, t()}
  def validate(file_content, filename, document_type) do
    case TheEye.analyze_document(file_content, filename) do
      {:ok, %{status: "success", markdown_content: content, structured_data: data}} ->
        validation = validate_extracted_content(content, document_type)
        add_extracted_data(validation, data)

      {:ok, %{status: status}} ->
        {:error,
         %__MODULE__{
           valid?: false,
           quality_score: 0,
           issues: ["Document analysis failed: #{status}"],
           suggestions: ["Please upload a clearer image"]
         }}

      {:error, :service_unavailable} ->
        # Gracefully degrade - allow submission but flag for manual review
        {:ok,
         %__MODULE__{
           valid?: true,
           quality_score: 50,
           issues: [],
           suggestions: ["Document will be verified manually"]
         }}

      {:error, reason} ->
        {:error,
         %__MODULE__{
           valid?: false,
           quality_score: 0,
           issues: ["Failed to process document: #{inspect(reason)}"],
           suggestions: ["Please try uploading again"]
         }}
    end
  end

  @doc """
  Validates extracted text content against document type requirements.
  Public for testing without The Eye service.
  """
  @spec validate_extracted_content(String.t(), atom()) :: {:ok, t()} | {:error, t()}
  def validate_extracted_content(content, :government_id) do
    checks = [
      {contains_any?(content, ["name", "Name", "NAME"]), "Name not found",
       "Ensure the full name is visible and not obscured"},
      {contains_any?(content, ["DOB", "Date of Birth", "birth", "Birth", "BIRTH"]),
       "Date of birth not found", "Make sure the birth date area is clearly visible"},
      {contains_any?(content, ["expires", "Expires", "EXP", "EXPIR"]), "Expiration date not found",
       "Include the expiration date in the photo"},
      {String.length(content) > 50, "Document appears unreadable",
       "Take a new photo with better lighting"}
    ]

    build_validation_result(checks)
  end

  def validate_extracted_content(content, :bank_statement) do
    checks = [
      {contains_any?(content, ["balance", "Balance", "BALANCE"]), "Balance not found",
       "Statement must show account balance"},
      {contains_any?(content, ["account", "Account", "ACCOUNT"]), "Account info not found",
       "Statement must show account number"},
      {contains_any?(content, ["bank", "Bank", "BANK", "Credit Union"]), "Bank name not found",
       "Statement header should be visible"},
      {String.length(content) > 100, "Document appears unreadable",
       "Upload a complete, legible statement"}
    ]

    build_validation_result(checks)
  end

  def validate_extracted_content(content, :business_license) do
    checks = [
      {contains_any?(content, ["license", "License", "LICENSE", "permit", "Permit", "PERMIT"]),
       "License type not found", "Document must clearly show license type"},
      {String.length(content) > 30, "Document appears unreadable",
       "Take a clearer photo of the license"}
    ]

    build_validation_result(checks)
  end

  def validate_extracted_content(_content, _type) do
    # Unknown type - basic validation only, lower confidence
    {:ok,
     %__MODULE__{
       valid?: true,
       quality_score: 70,
       issues: [],
       suggestions: []
     }}
  end

  @doc """
  Checks basic image quality metrics.
  Returns quality indicators for resolution, brightness, blur.

  Note: In production, this would use an image processing library.
  Currently returns default acceptable metrics for stub implementation.
  """
  @spec check_image_quality(binary()) :: map()
  def check_image_quality(_image_bytes) do
    # In production, this would use image processing library
    # For now, return default acceptable metrics
    %{
      resolution_ok: true,
      brightness_ok: true,
      blur_detected: false,
      recommended_action: nil
    }
  end

  # Private functions

  defp build_validation_result(checks) do
    failed_checks = Enum.filter(checks, fn {passed, _, _} -> not passed end)
    issues = Enum.map(failed_checks, fn {_, issue, _} -> issue end)
    suggestions = Enum.map(failed_checks, fn {_, _, suggestion} -> suggestion end)

    passed_count = length(checks) - length(failed_checks)
    quality_score = round(passed_count / length(checks) * 100)

    if Enum.empty?(issues) do
      {:ok,
       %__MODULE__{
         valid?: true,
         quality_score: quality_score,
         issues: [],
         suggestions: []
       }}
    else
      {:error,
       %__MODULE__{
         valid?: false,
         quality_score: quality_score,
         issues: issues,
         suggestions: suggestions
       }}
    end
  end

  defp add_extracted_data({status, validation}, extracted_data) do
    {status, %{validation | extracted_data: extracted_data}}
  end

  defp contains_any?(content, terms) do
    Enum.any?(terms, &String.contains?(content, &1))
  end
end
