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

    attribute :session_id, :string
    attribute :device_id, :string
    attribute :jti, :string

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
      accept [
        :user_id,
        :token,
        :expires_at,
        :context,
        :device_info,
        :session_id,
        :device_id,
        :jti
      ]

      change set_attribute(:type, :access)

      change fn changeset, _ ->
        if Ash.Changeset.get_attribute(changeset, :token) do
          changeset
        else
          Ash.Changeset.change_attribute(
            changeset,
            :token,
            Mcp.Accounts.JWT.generate_random_token()
          )
        end
      end
    end

    create :create_refresh_token do
      accept [
        :user_id,
        :token,
        :expires_at,
        :context,
        :device_info,
        :session_id,
        :device_id,
        :jti
      ]

      change set_attribute(:type, :refresh)

      change fn changeset, _ ->
        if Ash.Changeset.get_attribute(changeset, :token) do
          changeset
        else
          Ash.Changeset.change_attribute(
            changeset,
            :token,
            Mcp.Accounts.JWT.generate_random_token()
          )
        end
      end
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

    read :by_session do
      argument :session_id, :string, allow_nil?: false
      filter expr(session_id == ^arg(:session_id))
    end

    read :by_jti do
      argument :jti, :string, allow_nil?: false
      get? true
      filter expr(jti == ^arg(:jti))
    end

    update :revoke_by_session do
      argument :session_id, :string, allow_nil?: false
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
      filter expr(session_id == ^arg(:session_id) and is_nil(revoked_at))
    end

    update :revoke do
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
      require_atomic? false
    end

    update :mark_used do
      change set_attribute(:used_at, &DateTime.utc_now/0)
      require_atomic? false
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
    define :by_session, args: [:session_id]
    define :by_jti, args: [:jti], get?: true
    define :active_tokens
    define :revoke
    define :revoke_by_session, args: [:session_id]
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
         {:ok, user} <- Ash.load(token, :user),
         {:ok, _updated_token} <- mark_used(token) do
      {:ok, user.user}
    end
  end

  def generate_access_token(user_id, context, device_info) do
    expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

    create_access_token(%{
      user_id: user_id,
      token: Mcp.Accounts.JWT.generate_random_token(),
      expires_at: expires_at,
      context: context || %{},
      device_info: device_info || %{}
    })
  end

  def generate_refresh_token(user_id, context, device_info) do
    expires_at = DateTime.utc_now() |> DateTime.add(30, :day)

    create_refresh_token(%{
      user_id: user_id,
      token: Mcp.Accounts.JWT.generate_random_token(),
      expires_at: expires_at,
      context: context || %{},
      device_info: device_info || %{}
    })
  end

  def revoke_all_for_user(user_id) do
    case by_user(user_id) do
      {:ok, tokens} ->
        Enum.each(tokens, &revoke/1)
        :ok

      error ->
        error
    end
  end

  def generate_token_pair(user_id, context, device_info) do
    # This is a helper to generate both access and refresh tokens
    # In a real app, this might use JWT service, but here we create records

    expires_at = DateTime.utc_now() |> DateTime.add(3600, :second)

    with {:ok, access_token} <-
           create_access_token(%{
             user_id: user_id,
             token: Mcp.Accounts.JWT.generate_random_token(),
             expires_at: expires_at,
             context: context,
             device_info: device_info
           }),
         {:ok, refresh_token} <-
           create_refresh_token(%{
             user_id: user_id,
             token: Mcp.Accounts.JWT.generate_random_token(),
             expires_at: DateTime.add(expires_at, 30, :day),
             context: context,
             device_info: device_info
           }) do
      {:ok, %{access_token: access_token, refresh_token: refresh_token}}
    end
  end
end
