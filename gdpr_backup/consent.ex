defmodule Mcp.Gdpr.Consent do
  @moduledoc """
  GDPR consent management system.

  This module handles:
  - Recording user consent for data processing
  - Managing consent lifecycle (grant, revoke, expire)
  - Validating consent for specific processing activities
  - Generating consent reports
  """

  require Logger

  alias Mcp.Repo
  alias Ecto.{UUID, Multi, Query}

  # Consent record schema
  defmodule ConsentRecord do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id
    schema "gdpr_consent_records" do
      field :user_id, :binary_id
      field :consent_type, :string
      field :granted, :boolean
      field :legal_basis, :string
      field :purpose, :string
      field :data_categories, {:array, :string}
      field :granted_at, :utc_datetime
      field :revoked_at, :utc_datetime
      field :expires_at, :utc_datetime
      field :is_current, :boolean, default: true
      field :ip_address, :string
      field :user_agent, :string
      field :request_id, :string
      field :consent_form_version, :string

      timestamps(type: :utc_datetime)
    end

    def changeset(consent, attrs) do
      consent
      |> cast(attrs, [
        :user_id, :consent_type, :granted, :legal_basis, :purpose,
        :data_categories, :granted_at, :revoked_at, :expires_at,
        :is_current, :ip_address, :user_agent, :request_id,
        :consent_form_version
      ])
      |> validate_required([:user_id, :consent_type, :granted, :legal_basis, :purpose])
      |> validate_inclusion(:consent_type, ["marketing", "analytics", "essential", "third_party"])
      |> validate_inclusion(:legal_basis, ["consent", "contract", "legal_obligation", "legitimate_interest"])
      |> validate_inclusion(:granted, [true, false])
      |> validate_current_consent()
    end

    defp validate_current_consent(changeset) do
      granted = get_field(changeset, :granted)
      is_current = get_field(changeset, :is_current)

      if granted && !is_current do
        add_error(changeset, :is_current, "must be true when consent is granted")
      else
        changeset
      end
    end
  end

  @doc """
  Records user consent for data processing.

  ## Parameters
  - user_id: UUID of the user
  - consent_type: Type of consent being recorded
  - legal_basis: Legal basis for processing
  - purpose: Purpose of data processing
  - opts: Additional options

  ## Returns
  - {:ok, consent_record} on success
  - {:error, reason} on failure
  """
  def record_consent(user_id, consent_type, legal_basis, purpose, opts \\ []) do
    Logger.info("Recording consent for user #{user_id}, type: #{consent_type}")

    Multi.new()
    |> Multi.run(:revoke_existing, fn _repo, _changes ->
      revoke_existing_consent(user_id, consent_type)
    end)
    |> Multi.insert(:new_consent, fn _changes ->
      build_consent_record(user_id, consent_type, true, legal_basis, purpose, opts)
    end)
    |> Repo.transaction()
    |> handle_consent_result()
  end

  @doc """
  Revokes user consent for data processing.

  ## Parameters
  - user_id: UUID of the user
  - consent_type: Type of consent to revoke
  - opts: Additional options

  ## Returns
  - {:ok, consent_record} on success
  - {:error, reason} on failure
  """
  def revoke_consent(user_id, consent_type, opts \\ []) do
    Logger.info("Revoking consent for user #{user_id}, type: #{consent_type}")

    Query.from(c in ConsentRecord,
      where: c.user_id == ^user_id and c.consent_type == ^consent_type and c.is_current == true
    )
    |> Repo.update_all([set: [
      is_current: false,
      revoked_at: DateTime.utc_now()
    ]])
    |> case do
      {0, nil} -> {:error, :no_active_consent}
      {count, _} -> {:ok, %{revoked_count: count}}
    end
  end

  @doc """
  Checks if a user has valid consent for a specific processing activity.

  ## Parameters
  - user_id: UUID of the user
  - consent_type: Type of consent to check

  ## Returns
  - {:ok, true} if valid consent exists
  - {:ok, false} if no valid consent
  - {:error, reason} on failure
  """
  def has_valid_consent?(user_id, consent_type) do
    query = Query.from(c in ConsentRecord,
      where: c.user_id == ^user_id and
             c.consent_type == ^consent_type and
             c.granted == true and
             c.is_current == true and
             (c.revoked_at is null) and
             (c.expires_at is null or c.expires_at > ^DateTime.utc_now())
    )

    case Repo.exists?(query) do
      true -> {:ok, true}
      false -> {:ok, false}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Gets all current consents for a user.

  ## Parameters
  - user_id: UUID of the user

  ## Returns
  - {:ok, consents} list of consent records
  - {:error, reason} on failure
  """
  def get_user_consents(user_id) do
    query = Query.from(c in ConsentRecord,
      where: c.user_id == ^user_id and c.is_current == true,
      order_by: [desc: c.granted_at]
    )

    case Repo.all(query) do
      consents -> {:ok, consents}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Gets consent history for a user.

  ## Parameters
  - user_id: UUID of the user
  - consent_type: Optional filter by consent type
  - opts: Additional options (limit, offset)

  ## Returns
  - {:ok, consents} list of all consent records
  - {:error, reason} on failure
  """
  def get_consent_history(user_id, consent_type \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query = Query.from(c in ConsentRecord,
      where: c.user_id == ^user_id,
      order_by: [desc: c.granted_at],
      limit: ^limit,
      offset: ^offset
    )

    query =
      if consent_type do
        Query.from(c in query, where: c.consent_type == ^consent_type)
      else
        query
      end

    case Repo.all(query) do
      consents -> {:ok, consents}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Revokes all consents for a user (typically on account deletion).

  ## Parameters
  - user_id: UUID of the user

  ## Returns
  - {:ok, count} number of consents revoked
  - {:error, reason} on failure
  """
  def revoke_all_consents(user_id) do
    Logger.info("Revoking all consents for user #{user_id}")

    Query.from(c in ConsentRecord,
      where: c.user_id == ^user_id and c.is_current == true
    )
    |> Repo.update_all([set: [
      is_current: false,
      revoked_at: DateTime.utc_now()
    ]])
    |> case do
      {count, _} -> {:ok, count}
      error -> {:error, error}
    end
  end

  @doc """
  Checks for expired consents and marks them as inactive.

  ## Returns
  - {:ok, count} number of expired consents processed
  """
  def process_expired_consents do
    Logger.info("Processing expired consents")

    Query.from(c in ConsentRecord,
      where: c.is_current == true and
             c.expires_at < ^DateTime.utc_now()
    )
    |> Repo.update_all([set: [is_current: false]])
    |> case do
      {count, _} -> {:ok, count}
      error -> {:error, error}
    end
  end

  @doc """
  Gets consent statistics for reporting.

  ## Parameters
  - opts: Filtering options

  ## Returns
  - Map with consent statistics
  """
  def get_consent_statistics(opts \\ []) do
    date_from = Keyword.get(opts, :date_from, DateTime.add(DateTime.utc_now(), -30, :day))
    date_to = Keyword.get(opts, :date_to, DateTime.utc_now())

    base_query = Query.from(c in ConsentRecord,
      where: c.granted_at >= ^date_from and c.granted_at <= ^date_to
    )

    %{
      total_consent_records: Repo.aggregate(base_query, :count, :id),
      active_consents: get_active_consent_count(),
      revoked_consents: get_revoked_consent_count(base_query),
      consent_by_type: get_consent_by_type(base_query),
      consent_by_legal_basis: get_consent_by_legal_basis(base_query)
    }
  end

  # Private helper functions

  defp revoke_existing_consent(user_id, consent_type) do
    Query.from(c in ConsentRecord,
      where: c.user_id == ^user_id and
             c.consent_type == ^consent_type and
             c.is_current == true
    )
    |> Repo.update_all([set: [
      is_current: false,
      revoked_at: DateTime.utc_now()
    ]])
    |> case do
      {count, _} -> {:ok, count}
      error -> error
    end
  end

  defp build_consent_record(user_id, consent_type, granted, legal_basis, purpose, opts) do
    data_categories = Keyword.get(opts, :data_categories, get_default_categories(consent_type))
    expires_at = calculate_expires_at(consent_type, opts)

    ConsentRecord.changeset(%ConsentRecord{}, %{
      user_id: user_id,
      consent_type: consent_type,
      granted: granted,
      legal_basis: legal_basis,
      purpose: purpose,
      data_categories: data_categories,
      granted_at: DateTime.utc_now(),
      expires_at: expires_at,
      is_current: true,
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent),
      request_id: Keyword.get(opts, :request_id),
      consent_form_version: Keyword.get(opts, :consent_form_version, "1.0")
    })
  end

  defp get_default_categories("marketing"), do: ["email", "name", "preferences"]
  defp get_default_categories("analytics"), do: ["activity_logs", "behavioral_data", "preferences"]
  defp get_default_categories("essential"), do: ["core_identity", "authentication_data"]
  defp get_default_categories("third_party"), do: ["email", "name", "preferences"]

  defp calculate_expires_at("essential", _opts), do: nil # Essential consent doesn't expire
  defp calculate_expires_at(_consent_type, opts) do
    case Keyword.get(opts, :expires_in_days) do
      days when is_integer(days) ->
        DateTime.add(DateTime.utc_now(), days * 24 * 60 * 60, :second)

      _ ->
        # Default expiration: 2 years for marketing/analytics, 1 year for third-party
        days = case _consent_type do
          "marketing" -> 730 # 2 years
          "analytics" -> 730 # 2 years
          "third_party" -> 365 # 1 year
          _ -> 365 # Default 1 year
        end

        DateTime.add(DateTime.utc_now(), days * 24 * 60 * 60, :second)
    end
  end

  defp handle_consent_result({:ok, result}) do
    Logger.info("Successfully recorded consent #{result.new_consent.id}")
    {:ok, result.new_consent}
  end

  defp handle_consent_result({:error, failed_op, reason, _changes}) do
    Logger.error("Failed to record consent at #{failed_op}: #{inspect(reason)}")
    {:error, reason}
  end

  defp get_active_consent_count do
    Query.from(c in ConsentRecord, where: c.is_current == true and c.granted == true)
    |> Repo.aggregate(:count, :id)
  end

  defp get_revoked_consent_count(query) do
    Query.from(c in query, where: c.revoked_at is not null)
    |> Repo.aggregate(:count, :id)
  end

  defp get_consent_by_type(query) do
    query
    |> group_by([c], c.consent_type)
    |> select([c], {c.consent_type, count(c.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_consent_by_legal_basis(query) do
    query
    |> group_by([c], c.legal_basis)
    |> select([c], {c.legal_basis, count(c.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end
end