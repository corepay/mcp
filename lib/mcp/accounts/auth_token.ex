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
    schema "platform"
    repo Mcp.Repo

    custom_indexes do
      index [:token], unique: true
      index [:user_id]
      index [:type]
      index [:expires_at]
      index [:revoked_at]
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
      constraints [one_of: [:access, :refresh, :reset, :verification, :session]]
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

    create :generate_access_token do
      accept [:user_id, :context, :device_info]
      
      change fn changeset, _ ->
        # Generate JWT token
        user_id = Ash.Changeset.get_attribute(changeset, :user_id)
        
        claims = %{
          "sub" => user_id,
          "type" => "access",
          "iat" => DateTime.utc_now() |> DateTime.to_unix(),
          "exp" => DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.to_unix()
        }
        
        {:ok, token} = Mcp.Accounts.JWT.generate_token(claims)
        
        changeset
        |> Ash.Changeset.change_attribute(:token, token)
        |> Ash.Changeset.change_attribute(:type, :access)
        |> Ash.Changeset.change_attribute(:expires_at, DateTime.add(DateTime.utc_now(), 24, :hour))
      end
    end

    create :generate_refresh_token do
      accept [:user_id, :context, :device_info]
      
      change fn changeset, _ ->
        user_id = Ash.Changeset.get_attribute(changeset, :user_id)
        
        claims = %{
          "sub" => user_id,
          "type" => "refresh",
          "iat" => DateTime.utc_now() |> DateTime.to_unix(),
          "exp" => DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix()
        }
        
        {:ok, token} = Mcp.Accounts.JWT.generate_token(claims)
        
        changeset
        |> Ash.Changeset.change_attribute(:token, token)
        |> Ash.Changeset.change_attribute(:type, :refresh)
        |> Ash.Changeset.change_attribute(:expires_at, DateTime.add(DateTime.utc_now(), 30, :day))
      end
    end

    read :by_token do
      argument :token, :string, allow_nil?: false
      get? true
      filter expr(token == ^arg(:token) and is_nil(revoked_at) and expires_at > ^DateTime.utc_now())
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
    define :generate_access_token, args: [:user_id, :context, :device_info]
    define :generate_refresh_token, args: [:user_id, :context, :device_info]
    define :by_token, args: [:token], get?: true
    define :by_user, args: [:user_id]
    define :active_tokens
    define :revoke
    define :mark_used
    define :destroy
  end

  # Helper functions for token pair generation
  def generate_token_pair(user_id, context \\ %{}, device_info \\ %{}) do
    with {:ok, access_token} <- generate_access_token(user_id, context, device_info),
         {:ok, refresh_token} <- generate_refresh_token(user_id, context, device_info) do
      {:ok, %{access_token: access_token, refresh_token: refresh_token}}
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
