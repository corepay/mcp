defmodule Mcp.Underwriting.Gateway do
  @moduledoc """
  Factory and facade for accessing Underwriting Adapters.
  """

  alias Mcp.Underwriting.Application
  alias Mcp.Underwriting.RiskAssessment


  def get_adapter(context \\ %{}) do
    Mcp.Underwriting.VendorRouter.select_adapter(context)
  end

  @doc """
  Runs a full screening suite for an application.
  """
  def screen_application(application_id, opts \\ []) do
    tenant = Keyword.get(opts, :tenant)
    application = Application.get_by_id!(application_id, load: [:merchant], tenant: tenant)
    adapter = get_adapter()

    # 1. Screen Business (KYB)
    with {:ok, kyb_result} <- adapter.screen_business(application.application_data, %{}),
         {:ok, _check} <- record_check(application, :extensive_screening_check, kyb_result),
         
         # 2. Screen Owners (KYC) - Simplified loop
         owners = Map.get(application.application_data, "owners", []),
         _ <- Enum.each(owners, fn owner -> 
            {:ok, _kyc_result} = adapter.verify_identity(owner, %{}) 
            # Ideally we'd link this to a Client record, but for now we just run it
         end),

         # 3. Screen Documents
         # We need to load documents if not already loaded
         application = Ash.load!(application, [:documents], tenant: tenant),
         
         doc_results = Enum.map(application.documents, fn doc ->
           # Fetch file content from S3/MinIO
           bucket = Elixir.Application.get_env(:mcp, :uploads)[:bucket]
           file_content = 
             ExAws.S3.get_object(bucket, doc.file_path)
             |> ExAws.request!()
             |> Map.get(:body)
             
           # Run check
           # We need a client_id. For now, we'll assume the first owner created earlier is the client.
           # In a real system, documents would be linked to specific clients.
           # HACK: Create a temporary client for the document check if we don't have one linked.
           # Or better, use the client_id from the document if available (we added it in Phase 6).
           
           context = if doc.client_id, do: %{client_id: doc.client_id}, else: %{}
           
           # If no client_id on doc, we might fail or skip. 
           # For this implementation, let's skip if no client_id, or try to use a default one from the application context if we had one.
           
           if context[:client_id] do
             adapter.document_check(file_content, doc.document_type, context)
           else
             {:error, :no_client_linked}
           end
         end),
         
         # 4. Calculate Risk Score
         score = calculate_risk_score(kyb_result) do
      
      # 5. Create Risk Assessment
      RiskAssessment.create!(%{
        merchant_id: application.merchant_id,
        application_id: application.id,
        score: score,
        factors: %{kyb: kyb_result, documents: doc_results},
        recommendation: if(score > 80, do: :approve, else: :manual_review)
      }, tenant: tenant)
      
      # 6. Update Application Status
      new_status = 
        cond do
          score >= 90 -> :approved # Auto-approve high scores
          score < 50 -> :rejected # Auto-reject low scores
          true -> :manual_review # HITL for the rest
        end

      Application.update!(application, %{
        status: new_status,
        risk_score: score
      }, tenant: tenant)
      
      {:ok, score}
    else
      error -> {:error, error}
    end
  end

  defp record_check(_application, _type, _result) do
    # Placeholder: In a real implementation, we would create a Check record linked to a Client
    {:ok, :check_recorded}
  end

  defp calculate_risk_score(kyb_result) do
    base_score = if kyb_result.status == :clear, do: 90, else: 50
    
    # Example of vendor-specific adjustment
    # e.g. iDenfy might be considered stricter or looser, or we just normalize.
    # For now, we just ensure the score is consistent.
    
    case kyb_result[:provider] do
      "idenfy" -> base_score # iDenfy specific logic if needed
      "comply_cube" -> base_score # ComplyCube specific logic if needed
      _ -> base_score
    end
  end
end
