defmodule Mcp.Gdpr.Consent do
  @moduledoc """
  GDPR consent management functionality.
  """

  alias Mcp.Gdpr.Schemas.GdprConsent
  alias Mcp.Repo
  import Ecto.Query

  @doc """
  Records user consent for a specific purpose.
  """
  def record_consent(user_id, purpose, legal_basis, actor_id \\ nil, opts \\ []) do
    consent_attrs = %{
      user_id: user_id,
      purpose: purpose,
      legal_basis: legal_basis,
      status: "active",
      scope: Keyword.get(opts, :scope, %{}),
      valid_until: Keyword.get(opts, :valid_until),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    %GdprConsent{}
    |> GdprConsent.changeset(consent_attrs)
    |> Repo.insert()
  end

  @doc """
  Gets user consents.
  """
  def get_user_consents(user_id) do
    GdprConsent
    |> Ecto.Query.where([c], c.user_id == ^user_id and c.status == "active")
    |> Repo.all()
  end

  @doc """
  Starts the consent GenServer.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end
end