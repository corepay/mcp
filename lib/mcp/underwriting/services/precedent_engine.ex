defmodule Mcp.Underwriting.Services.PrecedentEngine do
  @moduledoc """
  Engine for harvesting past decisions and activities to provide context for new assessments.
  Implements the 'Precedent Engine' pattern (Graph RAG).
  """
  require Ash.Query
  alias Mcp.Underwriting.{Activity, RiskAssessment}

  @doc """
  Harvests precedents for a specific subject (merchant).
  Returns a summarized string of past decisions and reasons.
  """
  def harvest(subject_id, tenant_schema) do
    # Fetch past risk assessments linked to this subject
    risk_query =
      RiskAssessment
      |> Ash.Query.filter(subject_id == ^subject_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(5)

    assessments = Ash.read!(risk_query, tenant: tenant_schema)

    # Fetch past activities for ALL applications of this subject
    # Assuming Activity has a relationship 'application'
    activity_query =
      Activity
      |> Ash.Query.filter(application.subject_id == ^subject_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(10)

    activities =
      try do
        Ash.read!(activity_query, tenant: tenant_schema)
      rescue
        _ -> []
      end

    summarize(assessments, activities)
  end

  defp summarize([], []), do: "No previous precedents found for this subject."

  defp summarize(assessments, activities) do
    assessment_summary =
      Enum.map_join(assessments, "\n", fn a ->
        "- Assessment (#{a.inserted_at}): Score #{a.score}, Rec: #{a.recommendation}. Hash: #{a.policy_hash}. Factors: #{inspect(a.factors)}"
      end)

    activity_summary =
      Enum.map_join(activities, "\n", fn act ->
        "- Activity (#{act.inserted_at}): #{act.type}. Metadata: #{inspect(act.metadata)}"
      end)

    """
    PAST DECISION LINEAGE (PRECEDENTS):

    Assessments:
    #{assessment_summary}

    Activities:
    #{activity_summary}
    """
  end
end
