defmodule Mcp.Gdpr.Schemas.GdprConsent do
  @moduledoc """
  Schema for GDPR consent records.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "gdpr_consents" do
    field :purpose, :string
    field :legal_basis, :string
    field :status, :string, default: "active"
    field :withdrawn_at, :utc_datetime_usec
    field :version, :integer, default: 1
    field :scope, :map
    field :valid_until, :utc_datetime_usec
    field :metadata, :map

    belongs_to :user, Mcp.Accounts.UserSchema

    timestamps()
  end

  @doc false
  def changeset(gdpr_consent, attrs) do
    gdpr_consent
    |> cast(attrs, [:user_id, :purpose, :legal_basis, :status, :withdrawn_at, :version, :scope, :valid_until, :metadata])
    |> validate_required([:user_id, :purpose, :legal_basis, :status])
    |> validate_inclusion(:legal_basis, ["consent", "contract", "legal_obligation", "vital_interests", "public_task", "legitimate_interests"])
    |> validate_inclusion(:status, ["active", "withdrawn", "expired"])
    |> validate_number(:version, greater_than: 0)
  end
end