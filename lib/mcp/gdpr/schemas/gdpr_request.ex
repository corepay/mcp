defmodule Mcp.Gdpr.Schemas.GdprRequest do
  @moduledoc """
  Schema for GDPR compliance requests.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "gdpr_requests" do
    field :type, :string
    field :status, :string, default: "pending"
    field :reason, :string
    field :data, :map
    field :expires_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :error_message, :string

    belongs_to :user, Mcp.Accounts.UserSchema
    belongs_to :actor, Mcp.Accounts.UserSchema

    timestamps()
  end

  @doc false
  def changeset(gdpr_request, attrs) do
    gdpr_request
    |> cast(attrs, [:user_id, :type, :status, :reason, :actor_id, :data, :expires_at, :completed_at, :error_message])
    |> validate_required([:user_id, :type, :status])
    |> validate_inclusion(:type, ["deletion", "export", "correction", "restriction"])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "failed"])
  end
end