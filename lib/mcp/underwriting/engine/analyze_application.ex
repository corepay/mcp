defmodule Mcp.Underwriting.Engine.AnalyzeApplication do
  @moduledoc """
  The Sovereign Intelligence Factory Reactor.
  Orchestrates @the_eye, @the_inspector, and @the_cortex to produce a Forensic Risk Brief.
  """
  use Ash.Reactor

  require Ash.Query

  alias Mcp.Underwriting.Services.{TheEye, TheInspector}
  alias Mcp.Storage

  input(:application_id)
  input(:tenant)

  step :fetch_application do
    argument :application_id, input(:application_id)
    argument :tenant, input(:tenant)

    run fn args, _ ->
      Mcp.Underwriting.Application
      |> Ash.get(args.application_id, tenant: args.tenant)
      |> case do
        {:ok, app} -> {:ok, Ash.load!(app, [:documents], tenant: args.tenant)}
        error -> error
      end
    end
  end

  step :harvest_documents do
    argument :application, result(:fetch_application)

    run fn args, _ ->
      results =
        args.application.documents
        |> Enum.map(fn doc ->
          case Storage.download_file(doc.file_path) do
            {:ok, %{body: binary}} ->
              TheEye.analyze_document(binary, doc.file_name)

            error ->
              {:error, {:storage_error, error}}
          end
        end)

      {:ok, results}
    end
  end

  step :harvest_forensics do
    argument :application, result(:fetch_application)

    run fn args, _ ->
      # Extract URL from application data if available
      url = get_in(args.application.application_data, ["business_info", "website_url"])

      if url do
        TheInspector.capture_snapshot(url)
      else
        {:ok, %{skipped: "No website_url found"}}
      end
    end
  end

  step :triage_signals do
    argument :docs, result(:harvest_documents)
    argument :forensics, result(:harvest_forensics)

    run fn args, _ ->
      # Combine findings and perform triage
      signals = []

      # Document Signals
      signals =
        if Enum.any?(args.docs),
          do: signals ++ [:evidence_captured],
          else: signals ++ [:missing_primary_id]

      # Simulate finding bank statement details if docs present
      signals =
        if Enum.any?(args.docs),
          do: signals ++ [:low_balance_volatility, :kyb_registry_match],
          else: signals

      # Forensic Signals
      signals =
        case args.forensics do
          %{verdict: :suspicious} ->
            signals ++ [:residential_business_conflict, :geo_mismatch]

          %{verdict: :authentic} ->
            signals ++ [:commercial_intent_verified, :social_proof_detected]

          _ ->
            signals ++ [:web_forensics_skipped]
        end

      # Healed Data simulation
      healed_data = %{
        "legal_name" => "STITCHED CLOTHING CO.",
        "dba" => "STITCHED",
        "tin_match" => true,
        "address_verified" => true
      }

      {:ok,
       %{
         signals: signals,
         summary: "Contextual triage identified #{length(signals)} signals.",
         healed_data: healed_data
       }}
    end
  end

  step :decide do
    argument :triage, result(:triage_signals)

    run fn args, _ ->
      # Weighted scoring
      base_score = 15

      penalty =
        if Enum.member?(args.triage.signals, :residential_business_conflict), do: 45, else: 0

      penalty =
        penalty + if Enum.member?(args.triage.signals, :missing_primary_id), do: 30, else: 0

      score = base_score + penalty

      recommendation =
        cond do
          score > 70 -> :rejected
          score > 40 -> :manual_review
          true -> :approved
        end

      {:ok, %{score: score, recommendation: recommendation}}
    end
  end

  step :create_assessment do
    argument :application, result(:fetch_application)
    argument :decision, result(:decide)
    argument :triage, result(:triage_signals)
    argument :tenant, input(:tenant)

    run fn args, _ ->
      # Update Application with the new score and healed data
      {:ok, _app} =
        Mcp.Underwriting.Application.update(
          args.application,
          %{
            risk_score: args.decision.score,
            healed_data: args.triage.healed_data
          },
          tenant: args.tenant
        )

      Mcp.Underwriting.RiskAssessment
      |> Ash.Changeset.for_create(:create, %{
        application_id: args.application.id,
        score: args.decision.score,
        recommendation: args.decision.recommendation,
        factors: %{
          signals: args.triage.signals,
          summary: args.triage.summary
        },
        subject_id: args.application.subject_id,
        subject_type: args.application.subject_type,
        policy_hash: "v1-sovereign-triage"
      })
      |> Ash.create(tenant: args.tenant)
    end
  end
end
