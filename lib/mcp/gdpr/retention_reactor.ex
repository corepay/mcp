defmodule Mcp.Gdpr.RetentionReactor do
  @moduledoc """
  Reactor for GDPR data retention cleanup.

  This reactor fetches retention policies and processes overdue data
  according to the configured strategy (anonymize, delete, or archive).
  """

  use Ash.Reactor

  alias Mcp.Gdpr.Resources.RetentionPolicy
  alias Mcp.Gdpr.Anonymizer
  alias Mcp.Gdpr.Resources.AuditTrail
  alias Mcp.Repo
  require Logger
  import Ecto.Query

  # Step 1: Load all active retention policies that need processing
  step :load_policies do
    run fn _args ->
      current_time = DateTime.utc_now()

      # Get policies that are active, not on legal hold, and due for processing
      policies_query =
        from(p in RetentionPolicy,
          where: p.active == true,
          where: p.legal_hold == false,
          where: is_nil(p.last_processed_at) or p.last_processed_at < ^current_time
        )

      all_policies = Repo.all(policies_query)

      # Filter policies that are actually due for processing
      policies = Enum.filter(all_policies, fn policy ->
        is_nil(policy.last_processed_at) or
        DateTime.diff(current_time, policy.last_processed_at) >= policy.processing_frequency_hours * 3600
      end)

      Logger.info("Found #{length(policies)} retention policies to process")

      {:ok, policies}
    end
  end

  # Step 2: Process each policy to find overdue records
  step :process_policies do
    run fn %{load_policies: policies} ->
      results =
        Enum.map(policies, fn policy ->
          cutoff_date = DateTime.utc_now() |> DateTime.add(-policy.retention_days * 86_400, :second)

          case find_overdue_records(policy.entity_type, cutoff_date) do
            {:ok, overdue_ids} ->
              Logger.info("Policy #{policy.id} (#{policy.entity_type}): #{length(overdue_ids)} overdue records")

              {:ok, %{
                policy: policy,
                cutoff_date: cutoff_date,
                overdue_ids: overdue_ids,
                records_processed: 0,
                errors: []
              }}

            {:error, reason} ->
              Logger.error("Error processing policy #{policy.id}: #{inspect(reason)}")

              {:ok, %{
                policy: policy,
                cutoff_date: cutoff_date,
                overdue_ids: [],
                records_processed: 0,
                errors: [reason]
              }}
          end
        end)

      {:ok, results}
    end
  end

  # Step 3: Apply retention actions to overdue records
  step :apply_retention_actions do
    run fn %{process_policies: policy_results} ->
      processing_results =
        Enum.map(policy_results, fn {:ok, policy_result} ->
          %{
            policy: policy_result.policy,
            overdue_count: length(policy_result.overdue_ids),
            result: process_retention_for_policy(policy_result)
          }
        end)

      total_processed = Enum.reduce(processing_results, 0, fn %{result: result}, acc ->
        case result do
          {:ok, %{records_processed: count}} -> acc + count
          {:error, _} -> acc
        end
      end)

      Logger.info("Retention processing complete: #{total_processed} records processed")

      {:ok, %{
        total_policies: length(processing_results),
        total_processed: total_processed,
        results: processing_results
      }}
    end
  end

  # Step 4: Update policy processing timestamps
  step :update_policy_timestamps do
    run fn %{apply_retention_actions: processing_results} ->
      Enum.each(processing_results.results, fn %{policy: policy, result: result} ->
        # Mark policies as processed regardless of individual record success/failure
        Ecto.Changeset.change(policy, %{last_processed_at: DateTime.utc_now()})
        |> Repo.update()

        case result do
          {:ok, policy_result} ->
            if length(policy_result.errors) > 0 do
              Logger.warning("Policy #{policy.id} completed with #{length(policy_result.errors)} errors")
            end

          {:error, reason} ->
            Logger.error("Policy #{policy.id} failed: #{inspect(reason)}")
        end
      end)

      {:ok, :completed}
    end
  end

  # Helper function to find overdue records based on entity type
  defp find_overdue_records("user", cutoff_date) do
    try do
      # Find users who need anonymization/deletion
      overdue_query =
        from(u in Mcp.Gdpr.Resources.User,
          where: u.inserted_at <= ^cutoff_date,
          where: is_nil(u.gdpr_anonymized_at),  # Not already anonymized
          where: u.status in ["active", "deleted"],  # Only process active or soft-deleted users
          select: u.id
        )

      overdue_ids = Repo.all(overdue_query)
      {:ok, overdue_ids}
    rescue
      error -> {:error, "Error finding overdue users: #{inspect(error)}"}
    end
  end

  defp find_overdue_records("audit_trail", cutoff_date) do
    try do
      overdue_query =
        from(a in "gdpr_audit_trail",
          where: a.inserted_at <= ^cutoff_date,
          select: a.id
        )

      overdue_ids = Repo.all(overdue_query)
      {:ok, overdue_ids}
    rescue
      error -> {:error, "Error finding overdue audit trails: #{inspect(error)}"}
    end
  end

  defp find_overdue_records("consent", cutoff_date) do
    try do
      overdue_query =
        from(c in "gdpr_consent",
          where: c.inserted_at <= ^cutoff_date,
          select: c.id
        )

      overdue_ids = Repo.all(overdue_query)
      {:ok, overdue_ids}
    rescue
      error -> {:error, "Error finding overdue consent records: #{inspect(error)}"}
    end
  end

  defp find_overdue_records("data_export", cutoff_date) do
    try do
      overdue_query =
        from(e in "gdpr_data_exports",
          where: e.inserted_at <= ^cutoff_date,
          where: not is_nil(e.downloaded_at),  # Only remove exported files that have been downloaded
          select: e.id
        )

      overdue_ids = Repo.all(overdue_query)
      {:ok, overdue_ids}
    rescue
      error -> {:error, "Error finding overdue data exports: #{inspect(error)}"}
    end
  end

  defp find_overdue_records(entity_type, _cutoff_date) do
    Logger.warning("Unsupported entity type for retention: #{entity_type}")
    {:ok, []}
  end

  # Process retention actions for a specific policy
  defp process_retention_for_policy(policy_result) do
    %{policy: policy, overdue_ids: overdue_ids} = policy_result

    case policy.action do
      "anonymize" ->
        process_anonymization(policy, overdue_ids)

      "delete" ->
        process_deletion(policy, overdue_ids)

      "archive" ->
        process_archiving(policy, overdue_ids)

      _ ->
        {:error, "Unknown retention action: #{policy.action}"}
    end
  end

  # Process anonymization for user records
  defp process_anonymization(policy, user_ids) when policy.entity_type == "user" do
    Logger.info("Anonymizing #{length(user_ids)} users for policy #{policy.id}")

    results = Enum.map(user_ids, fn user_id ->
      case Anonymizer.anonymize_user(user_id, strategy: :hash) do
        {:ok, result} ->
          # Create audit trail
          create_retention_audit(user_id, "anonymize_user", policy.id, result)
          {:ok, user_id}

        {:error, reason} ->
          Logger.error("Failed to anonymize user #{user_id}: #{inspect(reason)}")
          {:error, user_id, reason}
      end
    end)

    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    errors = Enum.filter(results, fn {status, _} -> status == :error end)

    {:ok, %{
      action: "anonymize",
      records_processed: success_count,
      errors: errors
    }}
  end

  # Process deletion for various entity types
  defp process_deletion(policy, record_ids) do
    Logger.info("Deleting #{length(record_ids)} #{policy.entity_type} records for policy #{policy.id}")

    try do
      case policy.entity_type do
        "audit_trail" ->
          from(a in "gdpr_audit_trail", where: a.id in ^record_ids)
          |> Repo.delete_all()

        "consent" ->
          from(c in "gdpr_consent", where: c.id in ^record_ids)
          |> Repo.delete_all()

        "data_export" ->
          from(e in "gdpr_data_exports", where: e.id in ^record_ids)
          |> Repo.delete_all()

        entity_type ->
          Logger.warning("Deletion not implemented for entity type: #{entity_type}")
          {0, nil}
      end

      # Create audit entries for deleted records
      Enum.each(record_ids, fn record_id ->
        create_retention_audit(record_id, "delete_record", policy.id, %{
          entity_type: policy.entity_type,
          action: "delete"
        })
      end)

      {:ok, %{
        action: "delete",
        records_processed: length(record_ids),
        errors: []
      }}
    rescue
      error ->
        Logger.error("Error deleting records: #{inspect(error)}")
        {:error, "Deletion failed: #{inspect(error)}"}
    end
  end

  # Process archiving (placeholder for future implementation)
  defp process_archiving(policy, record_ids) do
    Logger.info("Archiving #{length(record_ids)} #{policy.entity_type} records for policy #{policy.id}")

    # For now, just create audit entries
    Enum.each(record_ids, fn record_id ->
      create_retention_audit(record_id, "archive_record", policy.id, %{
        entity_type: policy.entity_type,
        action: "archive",
        status: "archived"
      })
    end)

    {:ok, %{
      action: "archive",
      records_processed: length(record_ids),
      errors: []
    }}
  end

  
  # Create audit trail entry for retention actions
  defp create_retention_audit(record_id, action, policy_id, details) do
    audit_entry = %{
      user_id: record_id,
      action_type: action,
      actor_type: "retention_policy",
      actor_id: policy_id,
      details: Map.merge(details, %{
        policy_id: policy_id,
        processed_at: DateTime.utc_now()
      }),
      data_categories: ["user_data"],
      processed_at: DateTime.utc_now()
    }

    # For now, just log the audit entry since the audit trail needs proper Ash integration
    Logger.info("GDPR Audit: #{action} for record #{record_id} - #{inspect(details)}")

    # TODO: Integrate with Ash AuditTrail resource once domain actions are properly set up
    :ok
  rescue
    error ->
      Logger.error("Failed to create retention audit: #{inspect(error)}")
  end
end