defmodule Mcp.Accounts.User do
  @moduledoc """
  User resource for authentication and account management.

  Handles user registration, authentication, password management,
  session tracking, and account status.
  """

  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication, AshJsonApi.Resource, AshCloak, AshArchival]

  cloak do
    vault(Mcp.Secrets)
    attributes([:totp_secret, :backup_codes, :oauth_tokens])
    decrypt_by_default([:totp_secret, :backup_codes, :oauth_tokens])
  end

  postgres do
    table "users"
    schema("platform")
    repo(Mcp.Repo)

    custom_indexes do
      index([:status])
      index([:inserted_at])
    end
  end

  authentication do
    domain Mcp.Accounts
    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        hash_provider(AshAuthentication.BcryptProvider)
        confirmation_required?(false)
        # Disable sign-in tokens
        sign_in_tokens_enabled?(false)
      end
    end

    # Tokens will be enabled in Story 1.2 when AuthToken resource is created
    # tokens do
    #   enabled? true
    #   token_resource Mcp.Accounts.AuthToken
    #   signing_secret fn _, _ ->
    #     Application.get_env(:mcp, :token_signing_secret, "dev-secret-change-in-production")
    #   end
    # end
  end

  json_api do
    type "user"
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    # 2FA fields
    attribute :totp_secret, :string do
      sensitive? true
    end

    attribute :backup_codes, {:array, :string} do
      default []
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime

    # OAuth tokens
    attribute :oauth_tokens, :map do
      default %{}
      sensitive? true
    end

    # Session tracking
    attribute :last_sign_in_at, :utc_datetime
    attribute :last_sign_in_ip, Mcp.Types.Inet

    attribute :sign_in_count, :integer do
      default 0
    end

    # Account status
    attribute :status, :atom do
      constraints one_of: [:active, :suspended]
      default :active
      allow_nil? false
    end

    attribute :role, :atom do
      constraints one_of: [:user, :admin, :moderator]
      default :user
      allow_nil? false
    end

    attribute :tenant_id, :uuid

    timestamps()
  end

  identities do
    identity :unique_email, [:email], pre_check?: true
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:email]
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true

      validate confirm(:password, :password_confirmation)

      change fn changeset, _ ->
        if changeset.valid? do
          password = Ash.Changeset.get_argument(changeset, :password)
          hashed = Bcrypt.hash_pwd_salt(password)
          Ash.Changeset.change_attribute(changeset, :hashed_password, hashed)
        else
          changeset
        end
      end
    end

    read :by_email do
      argument :email, :ci_string, allow_nil?: false
      get? true
      filter expr(email == ^arg(:email))
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      get_by [:id]
    end

    read :active_users do
      # AshArchival automatically filters out archived records
    end

    update :update do
      primary? true
      accept [:email, :status]
    end

    update :update_sign_in do
      accept []
      argument :ip_address, :string
      require_atomic? false

      change fn changeset, _ ->
        ip = Ash.Changeset.get_argument(changeset, :ip_address)

        changeset
        |> Ash.Changeset.change_attribute(:last_sign_in_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:last_sign_in_ip, ip)
        |> Ash.Changeset.change_attribute(
          :sign_in_count,
          (Ash.Changeset.get_attribute(changeset, :sign_in_count) || 0) + 1
        )
      end
    end

    update :suspend do
      require_atomic? false
      change set_attribute(:status, :suspended)
    end

    update :activate do
      require_atomic? false
      change set_attribute(:status, :active)
    end
  end

  validations do
    validate match(:email, ~r/@/)
  end

  code_interface do
    define :read
    define :register, args: [:email, :password, :password_confirmation]
    define :by_email, args: [:email], get?: true
    define :by_id, args: [:id], get?: true
    define :active_users
    define :update
    define :update_sign_in, args: [:ip_address]
    define :suspend
    define :activate
    define :destroy
  end

  # Compatibility wrappers for existing code
  def get(id), do: by_id(id)
  def get_by_email(email), do: by_email(email)

  def create(attrs),
    do: register(attrs["email"], attrs["password"], attrs["password_confirmation"])
end
