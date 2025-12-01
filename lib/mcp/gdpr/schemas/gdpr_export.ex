defmodule Mcp.Gdpr.Schemas.GdprExport do
  @moduledoc """
  Schema for GDPR export tracking.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "gdpr_exports" do
    field :format, :string
    field :status, :string, default: "pending"
    field :file_path, :string
    field :file_size, :integer
    field :expires_at, :utc_datetime_usec
    field :error_message, :string

    belongs_to :user, Mcp.Accounts.UserSchema

    timestamps()
  end

  @doc false
  def changeset(gdpr_export, attrs) do
    gdpr_export
    |> cast(attrs, [
      :user_id,
      :format,
      :status,
      :file_path,
      :file_size,
      :expires_at,
      :error_message
    ])
    |> validate_required([:user_id, :format, :status, :expires_at])
    |> validate_inclusion(:format, ["json", "csv", "xml", "pdf"])
    |> validate_inclusion(:status, ["pending", "processing", "ready", "expired", "failed"])
  end
end
