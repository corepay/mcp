defmodule Mcp.Underwriting.Gateway do
  @moduledoc """
  Factory and facade for accessing Underwriting Adapters.
  """

  alias Mcp.Underwriting.{
    Activity,
    Application,
    Check,
    Client,
    RiskAssessment,
    RiskEngine,
    VendorRouter,
    VendorSettings
  }

  require Ash.Query
  require Logger

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
         {:ok, _check} <-
           record_kyb_check(application, :extensive_screening_check, kyb_result, opts) do
      # 2. Screen Owners (KYC) - Process each owner, record checks, and propagate errors
      owners = Map.get(application.application_data, "owners", [])

      with {:ok, _kyc_results} <-
             process_owner_kyc_checks(application, owners, adapter, tenant) do
        # 3. Screen Documents
        application = Ash.load!(application, [:documents], tenant: tenant)

        doc_results =
          Enum.map(application.documents, fn doc ->
            run_document_check(adapter, doc)
          end)

        policy_hash = Keyword.get(opts, :policy_hash)
        process_risk_assessment(application, kyb_result, doc_results, tenant, policy_hash)
      end
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

  defp process_risk_assessment(application, kyb_result, doc_results, tenant, policy_hash) do
    # 4. Calculate Risk Score
    vendor_data = %{kyb: kyb_result, documents: doc_results}
    evaluation = RiskEngine.evaluate(application, vendor_data)
    score = evaluation.score
    reasons = evaluation.reasons

    settings = fetch_thresholds(tenant)
    recommendation = determine_recommendation(score, settings)

    # 5. Create Risk Assessment
    RiskAssessment.create!(
      %{
        subject_id: application.subject_id,
        subject_type: application.subject_type,
        application_id: application.id,
        score: score,
        factors: %{kyb: kyb_result, documents: doc_results, risk_reasons: reasons},
        recommendation: recommendation,
        policy_hash: policy_hash
      },
      tenant: tenant
    )

    # 6. Update Application Status
    new_status =
      case recommendation do
        :approve -> :approved
        :reject -> :rejected
        :manual_review -> :manual_review
      end

    Application.update!(
      application,
      %{
        status: new_status,
        risk_score: score
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

  defp fetch_thresholds(tenant) do
    case VendorSettings.get_settings(tenant: tenant) do
      {:ok, [s | _]} -> s
      {:ok, s} when is_map(s) and not is_nil(s) -> s
      _ -> %{auto_approve_threshold: 90, auto_reject_threshold: 50}
    end
  end

  defp determine_recommendation(score, settings) do
    cond do
      score >= settings.auto_approve_threshold -> :approve
      score <= settings.auto_reject_threshold -> :reject
      true -> :manual_review
    end
  end

  # Process KYC checks for all owners, recording both successes and failures
  defp process_owner_kyc_checks(application, owners, adapter, tenant) do
    Enum.reduce_while(owners, {:ok, []}, fn owner, {:ok, acc} ->
      # Find or create client for this owner
      client = find_or_create_client(application, owner, tenant)

      case call_adapter(adapter, :verify_identity, [owner, %{}]) do
        {:ok, kyc_result} ->
          # Record successful KYC check
          {:ok, check} = record_kyc_check(client, :complete, kyc_result, tenant)
          {:cont, {:ok, [{:ok, check, kyc_result} | acc]}}

        {:error, reason} ->
          # Record failed KYC check
          {:ok, _check} = record_kyc_check(client, :failed, %{error: reason}, tenant)

          # Log activity for the failure
          log_kyc_failure_activity(application, owner, reason, tenant)

          {:halt, {:error, {:kyc_failed, owner["email"], reason}}}
      end
    end)
  end

  defp find_or_create_client(application, owner, tenant) do
    email = owner["email"]

    # Try to find existing client by email for this application
    existing =
      Client
      |> Ash.Query.filter(application_id == ^application.id and email == ^email)
      |> Ash.read_one(tenant: tenant)

    case existing do
      {:ok, nil} ->
        # Create new client
        {:ok, client} =
          Client
          |> Ash.Changeset.for_create(:create, %{
            type: :person,
            email: email,
            person_details: %{
              "first_name" => owner["first_name"],
              "last_name" => owner["last_name"],
              "dob" => owner["dob"]
            },
            application_id: application.id
          })
          |> Ash.create(tenant: tenant)

        client

      {:ok, client} ->
        client

      {:error, _} ->
        # Fallback: create new client
        {:ok, client} =
          Client
          |> Ash.Changeset.for_create(:create, %{
            type: :person,
            email: email,
            person_details: %{
              "first_name" => owner["first_name"],
              "last_name" => owner["last_name"]
            },
            application_id: application.id
          })
          |> Ash.create(tenant: tenant)

        client
    end
  end

  defp record_kyc_check(client, status, result, tenant) do
    outcome =
      case status do
        :complete -> :clear
        :failed -> :not_confirmed
      end

    Check
    |> Ash.Changeset.for_create(:create, %{
      type: :identity_check,
      status: status,
      outcome: outcome,
      raw_result: result,
      client_id: client.id
    })
    |> Ash.create(tenant: tenant)
  end

  defp log_kyc_failure_activity(application, owner, reason, tenant) do
    Activity.create!(
      %{
        application_id: application.id,
        type: :kyc_failure,
        metadata: %{
          owner_email: owner["email"],
          owner_name: "#{owner["first_name"]} #{owner["last_name"]}",
          reason: inspect(reason)
        },
        actor_id: nil
      },
      tenant: tenant
    )
  end

  defp call_adapter(adapter, function, args) do
    service_name = Atom.to_string(adapter)

    CircuitBreaker.execute(service_name, fn ->
      apply(adapter, function, args)
    end)
  end

  defp record_kyb_check(application, type, result, opts) do
    tenant = Keyword.get(opts, :tenant)
    client = find_or_create_business_client(application, tenant)

    Check
    |> Ash.Changeset.for_create(:create, %{
      type: type,
      status: :complete,
      outcome: map_kyb_outcome(result),
      raw_result: result,
      client_id: client.id
    })
    |> Ash.create(tenant: tenant)
  end

  defp find_or_create_business_client(application, tenant) do
    name = application.application_data["business_name"]

    existing =
      Client
      |> Ash.Query.filter(application_id == ^application.id and type == :company)
      |> Ash.read_one(tenant: tenant)

    case existing do
      {:ok, nil} ->
        Client
        |> Ash.Changeset.for_create(:create, %{
          type: :company,
          company_details: %{"name" => name},
          application_id: application.id
        })
        |> Ash.create!(tenant: tenant)

      {:ok, client} ->
        client
    end
  end

  defp map_kyb_outcome(result) do
    cond do
      result["status"] in ["clear", "passed", "approved"] -> :clear
      result["status"] in ["failed", "rejected"] -> :not_confirmed
      true -> :attention
    end
  end
end
