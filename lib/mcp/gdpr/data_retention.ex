defmodule Mcp.Gdpr.DataRetention do
  @moduledoc """
  GDPR data retention functionality.

  This module provides the core business logic for managing data retention
  policies, scheduling cleanup operations, and handling legal holds.
  """

  use GenServer
  require Logger

  alias Mcp.Gdpr.Resources.AuditTrail
  alias Mcp.Gdpr.Resources.RetentionPolicy

  @doc """
  Schedules data retention cleanup for a specific user and data categories.

  ## Parameters
  - user_id: The UUID of the user to schedule cleanup for
  - expires_at: When the data should expire
  - opts: Additional options
    - :categories - List of data categories to retain (default: ["core_identity"])
    - :tenant_id - The tenant ID (required)
    - :actor_id - The UUID of the actor performing the action

  ## Returns
  - {:ok, schedule_info} on success
  - {:error, reason} on failure
  """
  def schedule_cleanup(user_id, expires_at, opts \\ []) do
    categories = Keyword.get(opts, :categories, ["core_identity"])
    tenant_id = Keyword.get(opts, :tenant_id)
    actor_id = Keyword.get(opts, :actor_id)

    if is_nil(tenant_id) do
      {:error, :tenant_id_required}
    else
      # Create retention policies for each category
      policy_results =
        Enum.map(categories, fn category ->
          retention_days = calculate_retention_days(category, expires_at)

          Ash.create!(
            RetentionPolicy,
            %{
              tenant_id: tenant_id,
              entity_type: "user",
              retention_days: retention_days,
              action: category_action(category),
              conditions: %{
                "user_id" => user_id,
                "categories" => categories
              },
              description: "Automated retention policy for user #{user_id} - #{category}",
              actor_id: actor_id
            },
            action: :create_policy
          )
        end)

      # Check if all policies were created successfully
      case Enum.all?(policy_results, &(&1 != nil)) do
        true ->
          created_policies = Enum.map(policy_results, & &1.id)

          # Create audit entry
          create_audit_entry(
            user_id,
            "schedule_retention",
            actor_id,
            %{
              "categories" => categories,
              "expires_at" => expires_at,
              "policy_ids" => created_policies
            },
            categories
          )

          {:ok,
           %{
             user_id: user_id,
             expires_at: expires_at,
             categories: categories,
             policy_ids: created_policies,
             status: "scheduled"
           }}

        false ->
          {:error, :policy_creation_failed}
      end
    end
  rescue
    error ->
      Logger.error("Failed to schedule retention cleanup for user #{user_id}: #{inspect(error)}")

      {:error, {:scheduling_failed, error}}
  end

  @doc """
  Gets all retention schedules for a specific user.

  ## Parameters
  - user_id: The UUID of the user

  ## Returns
  - List of retention policies for the user
  """
  def get_user_schedules(user_id) do
    # Query for policies that apply to this user
    policies =
      Ash.read!(RetentionPolicy, action: :by_entity_type, input: %{entity_type: "user"})

    # Filter policies that apply to this specific user
    user_policies =
      Enum.filter(policies, fn policy ->
        policy.conditions["user_id"] == user_id
      end)

    Enum.map(user_policies, fn policy ->
      %{
        id: policy.id,
        entity_type: policy.entity_type,
        retention_days: policy.retention_days,
        action: policy.action,
        categories: policy.conditions["categories"] || [],
        legal_hold: policy.legal_hold,
        legal_hold_reason: policy.legal_hold_reason,
        legal_hold_until: policy.legal_hold_until,
        active: policy.active,
        last_processed_at: policy.last_processed_at,
        created_at: policy.inserted_at,
        updated_at: policy.updated_at
      }
    end)
  rescue
    error ->
      Logger.error("Failed to get user schedules for #{user_id}: #{inspect(error)}")
      []
  end

  @doc """
  Checks for active legal holds on user data.

  ## Parameters
  - user_id: The UUID of the user to check

  ## Returns
  - List of active legal holds
  - [] if no legal holds exist
  """
  def check_legal_holds(user_id) do
    # Get all policies for this user
    user_policies = get_user_schedules(user_id)

    # Filter for active legal holds
    active_holds =
      Enum.filter(user_policies, fn policy ->
        policy.legal_hold &&
          (is_nil(policy.legal_hold_until) ||
             DateTime.compare(policy.legal_hold_until, DateTime.utc_now()) != :lt)
      end)

    Enum.map(active_holds, fn policy ->
      %{
        policy_id: policy.id,
        user_id: user_id,
        reason: policy.legal_hold_reason,
        until: policy.legal_hold_until,
        categories: policy.categories,
        created_at: policy.created_at
      }
    end)
  rescue
    error ->
      Logger.error("Failed to check legal holds for user #{user_id}: #{inspect(error)}")
      []
  end

  @doc """
  Places a legal hold on user data.

  ## Parameters
  - user_id: The UUID of the user
  - case_reference: Reference for the legal case
  - reason: Reason for the legal hold
  - placed_by: UUID of the actor placing the hold
  - opts: Additional options
    - :hold_until - When the hold expires (optional)
    - :categories - Specific categories to hold (optional, defaults to all)

  ## Returns
  - {:ok, hold_info} on success
  - {:error, reason} on failure
  """
  def place_legal_hold(user_id, case_reference, reason, placed_by, opts \\ []) do
    hold_until = Keyword.get(opts, :hold_until)
    categories = Keyword.get(opts, :categories)
    tenant_id = Keyword.get(opts, :tenant_id)

    if is_nil(tenant_id) do
      {:error, :tenant_id_required}
    else
      # Get existing policies for this user
      existing_policies = get_user_schedules(user_id)

      # Filter policies based on categories if specified
      policies_to_hold = filter_policies_by_category(existing_policies, categories)

      # Place legal hold on each policy
      hold_results =
        Enum.map(policies_to_hold, fn policy ->
          Ash.update!(
            policy,
            %{
              legal_hold_reason: "#{case_reference}: #{reason}",
              legal_hold_until: hold_until,
              actor_id: placed_by
            },
            action: :place_on_legal_hold
          )
        end)

      # Check if all holds were placed successfully
      case Enum.all?(hold_results, &(&1 != nil)) do
        true ->
          held_policy_ids = Enum.map(policies_to_hold, & &1.id)

          # Create audit entry
          create_audit_entry(
            user_id,
            "place_legal_hold",
            placed_by,
            %{
              "case_reference" => case_reference,
              "reason" => reason,
              "hold_until" => hold_until,
              "categories" => categories,
              "policy_ids" => held_policy_ids
            },
            ["legal_hold"]
          )

          {:ok,
           %{
             user_id: user_id,
             case_reference: case_reference,
             reason: reason,
             hold_until: hold_until,
             categories: categories,
             held_policies: length(held_policy_ids),
             status: "active"
           }}

        false ->
          {:error, :legal_hold_failed}
      end
    end
  rescue
    error ->
      Logger.error("Failed to place legal hold for user #{user_id}: #{inspect(error)}")
      {:error, {:legal_hold_failed, error}}
  end

  @doc """
  Gets retention schedule for a specific entity type and tenant.

  ## Parameters
  - entity_type: The type of entity (e.g., "user", "audit_trail", "consent")
  - tenant_id: The UUID of the tenant

  ## Returns
  - List of active retention policies for the entity type
  """
  def get_retention_schedule(entity_type, tenant_id) do
    policies =
      Ash.read!(RetentionPolicy, action: :by_entity_type, input: %{entity_type: entity_type})

    # Filter by tenant and active policies
    tenant_policies =
      Enum.filter(policies, fn policy ->
        policy.tenant_id == tenant_id && policy.active
      end)

    Enum.map(tenant_policies, fn policy ->
      cutoff_date = DateTime.add(DateTime.utc_now(), -policy.retention_days * 86_400, :second)

      %{
        id: policy.id,
        entity_type: policy.entity_type,
        retention_days: policy.retention_days,
        action: policy.action,
        legal_hold: policy.legal_hold,
        legal_hold_until: policy.legal_hold_until,
        priority: policy.priority,
        conditions: policy.conditions,
        last_processed_at: policy.last_processed_at,
        processing_frequency_hours: policy.processing_frequency_hours,
        next_processing_at: calculate_next_processing(policy),
        cutoff_date: cutoff_date,
        description: policy.description
      }
    end)
    |> Enum.sort_by(& &1.priority)
  rescue
    error ->
      Logger.error("Failed to get retention schedule for #{entity_type}: #{inspect(error)}")
      []
  end

  @doc """
  Removes a legal hold from user data.

  ## Parameters
  - user_id: The UUID of the user
  - case_reference: Reference of the legal case to release
  - released_by: UUID of the actor releasing the hold

  ## Returns
  - {:ok, release_info} on success
  - {:error, reason} on failure
  """
  def remove_legal_hold(user_id, case_reference, released_by) do
    # Get policies with legal holds for this user
    user_policies = get_user_schedules(user_id)

    held_policies =
      Enum.filter(user_policies, fn policy ->
        policy.legal_hold && String.contains?(policy.legal_hold_reason || "", case_reference)
      end)

    # Remove legal hold from each policy
    release_results =
      Enum.map(held_policies, fn policy ->
        Ash.update!(policy, %{actor_id: released_by}, action: :remove_legal_hold)
      end)

    # Check if all holds were removed successfully
    case Enum.all?(release_results, &(&1 != nil)) do
      true ->
        released_policy_ids = Enum.map(held_policies, & &1.id)

        # Create audit entry
        create_audit_entry(
          user_id,
          "remove_legal_hold",
          released_by,
          %{
            "case_reference" => case_reference,
            "policy_ids" => released_policy_ids
          },
          ["legal_hold"]
        )

        {:ok,
         %{
           user_id: user_id,
           case_reference: case_reference,
           released_policies: length(released_policy_ids),
           status: "released"
         }}

      false ->
        {:error, :legal_hold_release_failed}
    end
  rescue
    error ->
      Logger.error("Failed to remove legal hold for user #{user_id}: #{inspect(error)}")
      {:error, {:legal_hold_release_failed, error}}
  end

  # Private helper functions

  # Calculate retention days based on category and expiration date
  defp calculate_retention_days(category, expires_at) do
    now = DateTime.utc_now()
    days_until_expiry = DateTime.diff(expires_at, now, :day)

    # Add buffer time based on category
    case category do
      # 30-day buffer, minimum 1 year
      "core_identity" -> max(days_until_expiry + 30, 365)
      # 90-day buffer, minimum 7 years
      "transaction_data" -> max(days_until_expiry + 90, 2555)
      # 60-day buffer, minimum 5 years
      "communication" -> max(days_until_expiry + 60, 1825)
      # 30-day buffer, minimum 1 year
      "analytics" -> max(days_until_expiry + 30, 365)
      # Default 30-day buffer, minimum 1 year
      _ -> max(days_until_expiry + 30, 365)
    end
  end

  # Determine action based on data category
  defp category_action(category) do
    case category do
      "core_identity" -> "anonymize"
      "transaction_data" -> "archive"
      "communication" -> "delete"
      "analytics" -> "anonymize"
      _ -> "anonymize"
    end
  end

  # Calculate next processing time for a policy
  defp calculate_next_processing(policy) do
    base_time = policy.last_processed_at || policy.inserted_at
    DateTime.add(base_time, policy.processing_frequency_hours * 3600, :second)
  end

  # Filter policies by category if specified
  defp filter_policies_by_category(policies, nil), do: policies

  defp filter_policies_by_category(policies, categories) do
    Enum.filter(policies, fn policy ->
      Enum.any?(policy.categories, &(&1 in categories))
    end)
  end

  # Create audit trail entry
  defp create_audit_entry(user_id, action_type, actor_id, details, data_categories) do
    Ash.create!(
      AuditTrail,
      %{
        user_id: user_id,
        action_type: action_type,
        actor_type: if(actor_id, do: "user", else: "system"),
        actor_id: actor_id,
        data_categories: data_categories,
        details: details,
        processed_at: DateTime.utc_now()
      },
      action: :create_entry
    )
  rescue
    error ->
      Logger.error("Failed to create audit entry: #{inspect(error)}")
      :ok
  end

  @doc """
  Starts the data retention GenServer.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting GDPR Data Retention GenServer")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:process_retention, state) do
    # Process retention policies (can be called periodically)
    Logger.info("Processing retention policies via GenServer")

    # Schedule next processing
    Process.send_after(self(), :process_retention, :timer.hours(1))

    {:noreply, state}
  end
end
