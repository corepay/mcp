defmodule Mcp.Accounts.UserSchema do
  @moduledoc """
  Ecto schema for the users table.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :status, :string, default: "active"
    field :deleted_at, :utc_datetime_usec
    field :deletion_reason, :string
    field :gdpr_retention_expires_at, :utc_datetime_usec
    field :anonymized_at, :utc_datetime_usec
    field :confirmed_at, :utc_datetime_usec
    field :last_sign_in_at, :utc_datetime_usec
    field :last_sign_in_ip, :string
    field :sign_in_count, :integer, default: 0
    field :failed_attempts, :integer, default: 0
    field :locked_at, :utc_datetime_usec
    field :unlock_token, :string
    field :unlock_token_expires_at, :utc_datetime_usec
    field :password_change_required, :boolean, default: false
    field :totp_secret, :string
    field :backup_codes, {:array, :string}
    field :oauth_tokens, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :hashed_password, :status, :deleted_at, :deletion_reason, :gdpr_retention_expires_at, :anonymized_at])
    |> validate_required([:email, :status])
    |> validate_inclusion(:status, ["active", "suspended", "deleted"])
    |> unique_constraint(:email)
  end
end