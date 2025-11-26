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
    field :download_count, :integer, default: 0
    field :max_downloads, :integer, default: 3
    field :expires_at, :utc_datetime_usec
    field :metadata, :map
    field :error_message, :string

    belongs_to :user, Mcp.Accounts.UserSchema
    belongs_to :request, Mcp.Gdpr.Schemas.GdprRequest

    timestamps()
  end

  @doc false
  def changeset(gdpr_export, attrs) do
    gdpr_export
    |> cast(attrs, [
      :user_id,
      :request_id,
      :format,
      :status,
      :file_path,
      :file_size,
      :download_count,
      :max_downloads,
      :expires_at,
      :metadata,
      :error_message
    ])
    |> validate_required([:user_id, :request_id, :format, :status, :expires_at])
    |> validate_inclusion(:format, ["json", "csv", "xml", "pdf"])
    |> validate_inclusion(:status, ["pending", "processing", "ready", "expired", "failed"])
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> validate_number(:max_downloads, greater_than: 0)
  end
end
