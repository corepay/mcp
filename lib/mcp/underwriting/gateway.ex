defmodule Mcp.Underwriting.Gateway do
  @moduledoc """
  Factory and facade for accessing Underwriting Adapters.
  """

  alias Mcp.Underwriting.{
    Activity,
    Application,
    RiskAssessment,
    RiskEngine,
    SlaCalculator,
    VendorRouter
  }

  alias Mcp.Utils.CircuitBreaker

  def get_adapter(context \\ %{}) do
    VendorRouter.select_adapter(context)
  end

  @doc """
  Runs a full screening suite for an application.
  """
  def screen_application(application_id, opts \\ []) do
    tenant = Keyword.get(opts, :tenant)
    application = Application.get_by_id!(application_id, tenant: tenant)
    adapter = get_adapter()

    # 1. Screen Business (KYB)
    # ... (previous code)
    with {:ok, kyb_result} <-
           call_adapter(adapter, :screen_business, [application.application_data, %{}]),
         {:ok, _check} <- record_check(application, :extensive_screening_check, kyb_result) do
      # 2. Screen Owners (KYC) - Simplified loop
      owners = Map.get(application.application_data, "owners", [])

      Enum.each(owners, fn owner ->
        {:ok, _kyc_result} = call_adapter(adapter, :verify_identity, [owner, %{}])
      end)

      # 3. Screen Documents
      application = Ash.load!(application, [:documents], tenant: tenant)

      doc_results =
        Enum.map(application.documents, fn doc ->
          run_document_check(adapter, doc)
        end)

      process_risk_assessment(application, kyb_result, doc_results, tenant)
    else
      error -> {:error, error}
    end
  end

  defp run_document_check(adapter, doc) do
    bucket = Elixir.Application.get_env(:mcp, :uploads)[:bucket]

    file_content =
      ExAws.S3.get_object(bucket, doc.file_path)
      |> ExAws.request!()
      |> Map.get(:body)

    context = if doc.client_id, do: %{client_id: doc.client_id}, else: %{}

    if context[:client_id] do
      call_adapter(adapter, :document_check, [file_content, doc.document_type, context])
    else
      {:error, :no_client_linked}
    end
  end

  defp process_risk_assessment(application, kyb_result, doc_results, tenant) do
    # 4. Calculate Risk Score
    vendor_data = %{kyb: kyb_result, documents: doc_results}
    evaluation = RiskEngine.evaluate(application, vendor_data)
    score = evaluation.score
    reasons = evaluation.reasons

    # Calculate SLA
    now = DateTime.utc_now()
    submitted_at = application.submitted_at || now
    sla_due_at = SlaCalculator.calculate_due_at(submitted_at)

    # 5. Create Risk Assessment
    RiskAssessment.create!(
      %{
        subject_id: application.subject_id,
        subject_type: application.subject_type,
        application_id: application.id,
        score: score,
        factors: %{kyb: kyb_result, documents: doc_results, risk_reasons: reasons},
        recommendation: if(score > 80, do: :approve, else: :manual_review)
      },
      tenant: tenant
    )

    # 6. Update Application Status & SLA
    new_status = determine_new_status(score)

    Application.update!(
      application,
      %{
        status: new_status,
        risk_score: score,
        submitted_at: submitted_at,
        sla_due_at: sla_due_at
      },
      tenant: tenant
    )

    # 7. Log Activity
    Activity.create!(
      %{
        application_id: application.id,
        type: :status_change,
        metadata: %{
          from: :submitted,
          to: new_status,
          score: score,
          reasons: reasons
        },
        actor_id: nil
      },
      tenant: tenant
    )

    {:ok, score}
  end

  defp determine_new_status(score) do
    cond do
      score >= 90 -> :approved
      score < 50 -> :rejected
      true -> :manual_review
    end
  end

  # Remove old calculate_risk_score if unused, or keep as fallback?
  # The RiskEngine replaces it.

  defp call_adapter(adapter, function, args) do
    service_name = Atom.to_string(adapter)

    CircuitBreaker.execute(service_name, fn ->
      apply(adapter, function, args)
    end)
  end

  defp record_check(_application, _type, _result) do
    # Placeholder: In a real implementation, we would create a Check record linked to a Client
    {:ok, :check_recorded}
  end
end
