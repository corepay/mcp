defmodule Mcp.Accounts.AuthToken do
  @moduledoc """
  AuthToken resource for managing JWT-based authentication tokens.

  Handles access tokens, refresh tokens, and token lifecycle including
  expiration, revocation, and usage tracking.
  """

  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "auth_tokens"
    schema("platform")
    repo(Mcp.Repo)

    custom_indexes do
      index([:token], unique: true)
      index([:user_id])
      index([:type])
      index([:expires_at])
      index([:revoked_at])
    end
  end

  json_api do
    type "auth_token"
  end

  attributes do
    uuid_primary_key :id

    attribute :token, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :type, :atom do
      constraints one_of: [:access, :refresh, :reset, :verification, :session]
      allow_nil? false
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
    end

    attribute :revoked_at, :utc_datetime_usec
    attribute :used_at, :utc_datetime_usec

    attribute :context, :map do
      default %{}
    end

    attribute :device_info, :map do
      default %{}
    end

    timestamps(type: :utc_datetime_usec)
  end

  relationships do
    belongs_to :user, Mcp.Accounts.User do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create_access_token do
      accept [:user_id, :token, :expires_at, :context, :device_info]
      change set_attribute(:type, :access)
    end

    create :create_refresh_token do
      accept [:user_id, :token, :expires_at, :context, :device_info]
      change set_attribute(:type, :refresh)
    end

    read :by_token do
      argument :token, :string, allow_nil?: false
      get? true

      filter expr(
               token == ^arg(:token) and is_nil(revoked_at) and expires_at > ^DateTime.utc_now()
             )
    end

    read :by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_nil(revoked_at))
    end

    read :active_tokens do
      filter expr(is_nil(revoked_at) and expires_at > ^DateTime.utc_now())
    end

    update :revoke do
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    update :mark_used do
      change set_attribute(:used_at, &DateTime.utc_now/0)
    end

    destroy :revoke_all_for_user do
      require_atomic? false
    end
  end

  validations do
    validate present([:token, :type, :expires_at, :user_id])
  end

  code_interface do
    define :read
    define :create_access_token
    define :create_refresh_token
    define :by_token, args: [:token], get?: true
    define :by_user, args: [:user_id]
    define :active_tokens
    define :revoke
    define :mark_used
    define :destroy
  end

  # Helper function to find tokens by user
  def find_tokens_by_user(user_id) do
    case by_user(user_id) do
      {:ok, tokens} -> tokens
      _ -> []
    end
  end

  def verify_and_get_user(token_string) do
    with {:ok, token} <- by_token(token_string),
         {:ok, user} <- Ash.load(token, :user) do
      # Mark token as used
      mark_used(token)
      {:ok, user.user}
    end
  end
end
