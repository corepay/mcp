defmodule Mcp.Gdpr.Schemas.GdprAuditLog do
  @moduledoc """
  Schema for GDPR audit logs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "gdpr_audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :old_values, :map
    field :new_values, :map
    field :metadata, :map
    field :ip_address, :string
    field :user_agent, :string
    field :session_id, :string
    field :request_id, :string
    field :timestamp, :utc_datetime_usec

    belongs_to :user, Mcp.Accounts.UserSchema
    belongs_to :actor, Mcp.Accounts.UserSchema

    timestamps()
  end

  @doc false
  def changeset(gdpr_audit_log, attrs) do
    gdpr_audit_log
    |> cast(attrs, [:user_id, :actor_id, :action, :resource_type, :resource_id, :old_values, :new_values, :metadata, :ip_address, :user_agent, :session_id, :request_id, :timestamp])
    |> validate_required([:action, :timestamp])
    |> validate_inclusion(:action, ["delete_request", "export_request", "consent_updated", "consent_recorded", "consent_withdrawn", "anonymization_started", "anonymization_complete", "deletion_cancelled", "legal_hold_placed", "legal_hold_released"])
  end
end