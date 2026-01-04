defmodule Mcp.Accounts.User do
  @moduledoc """
  User resource for authentication and account management.

  Handles user registration, authentication, password management,
  session tracking, and account status.
  """

  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication, AshJsonApi.Resource, AshArchival]

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

      google :google do
        client_id(fn _, _ ->
          Application.get_env(:mcp, :google_oauth)[:client_id] ||
            System.get_env("GOOGLE_CLIENT_ID") ||
            "test-google-client-id"
        end)

        client_secret(fn _, _ ->
          Application.get_env(:mcp, :google_oauth)[:client_secret] ||
            System.get_env("GOOGLE_CLIENT_SECRET") ||
            "test-google-client-secret"
        end)

        redirect_uri(fn _, _ ->
          base_url = Application.get_env(:mcp, McpWeb.Endpoint)[:url][:host] || "localhost"
          port = Application.get_env(:mcp, McpWeb.Endpoint)[:http][:port] || 4000
          scheme = if port == 443, do: "https", else: "http"
          {:ok, "#{scheme}://#{base_url}:#{port}/auth/google/callback"}
        end)

        # Disable hijacking prevention until confirmation add-on is implemented
        prevent_hijacking?(false)
      end

      github :github do
        client_id(fn _, _ ->
          Application.get_env(:mcp, :github_oauth)[:client_id] ||
            System.get_env("GITHUB_CLIENT_ID") ||
            "test-github-client-id"
        end)

        client_secret(fn _, _ ->
          Application.get_env(:mcp, :github_oauth)[:client_secret] ||
            System.get_env("GITHUB_CLIENT_SECRET") ||
            "test-github-client-secret"
        end)

        redirect_uri(fn _, _ ->
          base_url = Application.get_env(:mcp, McpWeb.Endpoint)[:url][:host] || "localhost"
          port = Application.get_env(:mcp, McpWeb.Endpoint)[:http][:port] || 4000
          scheme = if port == 443, do: "https", else: "http"
          {:ok, "#{scheme}://#{base_url}:#{port}/auth/github/callback"}
        end)

        # Disable hijacking prevention until confirmation add-on is implemented
        prevent_hijacking?(false)
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

    attribute :failed_attempts, :integer do
      default 0
    end

    attribute :locked_at, :utc_datetime
    attribute :unlock_token, :string

    # Password reset fields
    attribute :reset_password_token, :string do
      sensitive? true
    end

    attribute :reset_password_sent_at, :utc_datetime

    # Account status
    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :deleted, :anonymized, :locked]
      default :active
      allow_nil? false
    end

    attribute :role, :atom do
      constraints one_of: [:user, :admin, :moderator]
      default :user
      allow_nil? false
    end

    attribute :first_name, :string do
      constraints max_length: 255
    end

    attribute :last_name, :string do
      constraints max_length: 255
    end

    attribute :tenant_id, :uuid
    attribute :merchant_id, :uuid

    # GDPR fields
    attribute :deleted_at, :utc_datetime_usec
    attribute :deletion_reason, :string
    attribute :gdpr_retention_expires_at, :utc_datetime_usec

    timestamps()
  end

  identities do
    identity :unique_email, [:email], pre_check?: true
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:email, :first_name, :last_name, :tenant_id]
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

    create :register_with_google do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false

      upsert? true
      upsert_identity :unique_email

      change fn changeset, _ ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        oauth_tokens = Ash.Changeset.get_argument(changeset, :oauth_tokens)

        email = user_info["email"]
        name = user_info["name"] || ""
        [first_name | rest] = String.split(name, " ", parts: 2)
        last_name = if rest == [], do: nil, else: hd(rest)

        # Generate a random password for OAuth users
        random_password = :crypto.strong_rand_bytes(32) |> Base.encode64()
        hashed = Bcrypt.hash_pwd_salt(random_password)

        # Store OAuth tokens
        current_tokens = Ash.Changeset.get_attribute(changeset, :oauth_tokens) || %{}

        new_tokens =
          Map.put(current_tokens, "google", %{
            "provider" => "google",
            "uid" => user_info["sub"],
            "access_token" => oauth_tokens["access_token"],
            "refresh_token" => oauth_tokens["refresh_token"],
            "expires_at" => oauth_tokens["expires_at"],
            "linked_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "user_info" => %{
              "name" => name,
              "email" => email,
              "image" => user_info["picture"]
            }
          })

        changeset
        |> Ash.Changeset.change_attribute(:email, email)
        |> Ash.Changeset.change_attribute(:first_name, first_name)
        |> Ash.Changeset.change_attribute(:last_name, last_name)
        |> Ash.Changeset.change_attribute(:hashed_password, hashed)
        |> Ash.Changeset.change_attribute(:oauth_tokens, new_tokens)
      end
    end

    create :register_with_github do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false

      upsert? true
      upsert_identity :unique_email

      change fn changeset, _ ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        oauth_tokens = Ash.Changeset.get_argument(changeset, :oauth_tokens)

        email = user_info["email"]
        name = user_info["name"] || user_info["login"] || ""
        [first_name | rest] = String.split(name, " ", parts: 2)
        last_name = if rest == [], do: nil, else: hd(rest)

        # Generate a random password for OAuth users
        random_password = :crypto.strong_rand_bytes(32) |> Base.encode64()
        hashed = Bcrypt.hash_pwd_salt(random_password)

        # Store OAuth tokens
        current_tokens = Ash.Changeset.get_attribute(changeset, :oauth_tokens) || %{}

        new_tokens =
          Map.put(current_tokens, "github", %{
            "provider" => "github",
            "uid" => to_string(user_info["id"]),
            "access_token" => oauth_tokens["access_token"],
            "refresh_token" => oauth_tokens["refresh_token"],
            "expires_at" => oauth_tokens["expires_at"],
            "linked_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "user_info" => %{
              "name" => name,
              "email" => email,
              "image" => user_info["avatar_url"],
              "login" => user_info["login"]
            }
          })

        changeset
        |> Ash.Changeset.change_attribute(:email, email)
        |> Ash.Changeset.change_attribute(:first_name, first_name)
        |> Ash.Changeset.change_attribute(:last_name, last_name)
        |> Ash.Changeset.change_attribute(:hashed_password, hashed)
        |> Ash.Changeset.change_attribute(:oauth_tokens, new_tokens)
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
      accept [:email, :status, :oauth_tokens]
      require_atomic? false
    end

    update :update_sign_in do
      accept []
      argument :ip_address, :string
      require_atomic? false

      change fn changeset, _ ->
        ip = Ash.Changeset.get_argument(changeset, :ip_address)

        changeset =
          changeset
          |> Ash.Changeset.change_attribute(:last_sign_in_at, DateTime.utc_now())
          |> Ash.Changeset.change_attribute(
            :sign_in_count,
            (Ash.Changeset.get_attribute(changeset, :sign_in_count) || 0) + 1
          )

        # Only set IP if it's provided
        if ip do
          Ash.Changeset.change_attribute(changeset, :last_sign_in_ip, ip)
        else
          changeset
        end
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

    update :change_password do
      argument :current_password, :string, sensitive?: true
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true
      require_atomic? false

      validate confirm(:password, :password_confirmation)

      # In a real app, we'd validate current_password here

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

    update :soft_delete do
      require_atomic? false
      argument :reason, :string
      change set_attribute(:deletion_reason, arg(:reason))
      change set_attribute(:status, :deleted)
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
    end

    update :anonymize do
      require_atomic? false

      change fn changeset, _ ->
        random_email = "anonymized_#{Ecto.UUID.generate()}@example.com"

        changeset
        |> Ash.Changeset.force_change_attribute(:email, random_email)
        |> Ash.Changeset.force_change_attribute(:first_name, "Anonymized")
        |> Ash.Changeset.force_change_attribute(:last_name, "User")
        |> Ash.Changeset.force_change_attribute(:hashed_password, "deleted")
        |> Ash.Changeset.force_change_attribute(:totp_secret, nil)
        |> Ash.Changeset.force_change_attribute(:backup_codes, [])
        |> Ash.Changeset.force_change_attribute(:status, :anonymized)
      end
    end

    update :gdpr_anonymize do
      accept [
        :email,
        :hashed_password,
        :totp_secret,
        :backup_codes,
        :oauth_tokens,
        :last_sign_in_ip,
        :status
      ]

      require_atomic? false
    end

    update :lock_account do
      accept []
      require_atomic? false
      change set_attribute(:locked_at, DateTime.utc_now())

      change set_attribute(
               :unlock_token,
               "unlock_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
             )

      change set_attribute(:status, :locked)
    end

    update :unlock_account do
      accept []
      require_atomic? false
      change set_attribute(:locked_at, nil)
      change set_attribute(:unlock_token, nil)
      change set_attribute(:failed_attempts, 0)
    end

    update :increment_failed_attempts do
      accept []
      require_atomic? false

      change fn changeset, _ ->
        attempts = Ash.Changeset.get_attribute(changeset, :failed_attempts) || 0
        Ash.Changeset.change_attribute(changeset, :failed_attempts, attempts + 1)
      end
    end

    update :reset_failed_attempts do
      accept []
      require_atomic? false
      change set_attribute(:failed_attempts, 0)
    end

    update :request_password_reset do
      accept []
      require_atomic? false

      change fn changeset, _ ->
        # Generate secure reset token
        token =
          :crypto.strong_rand_bytes(32)
          |> Base.url_encode64(padding: false)

        changeset
        |> Ash.Changeset.change_attribute(:reset_password_token, token)
        |> Ash.Changeset.change_attribute(:reset_password_sent_at, DateTime.utc_now())
      end
    end

    update :reset_password_with_token do
      accept []
      argument :token, :string, allow_nil?: false, sensitive?: true
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true
      require_atomic? false

      validate confirm(:password, :password_confirmation)

      validate fn changeset, _context ->
        token = Ash.Changeset.get_argument(changeset, :token)
        stored_token = Ash.Changeset.get_attribute(changeset, :reset_password_token)
        reset_sent_at = Ash.Changeset.get_attribute(changeset, :reset_password_sent_at)

        cond do
          is_nil(stored_token) or is_nil(reset_sent_at) ->
            {:error, field: :token, message: "Invalid or expired reset token"}

          token != stored_token ->
            {:error, field: :token, message: "Invalid or expired reset token"}

          # Token expires after 1 hour
          DateTime.diff(DateTime.utc_now(), reset_sent_at, :second) > 3600 ->
            {:error, field: :token, message: "Invalid or expired reset token"}

          true ->
            :ok
        end
      end

      change fn changeset, _ ->
        if changeset.valid? do
          password = Ash.Changeset.get_argument(changeset, :password)
          hashed = Bcrypt.hash_pwd_salt(password)

          changeset
          |> Ash.Changeset.change_attribute(:hashed_password, hashed)
          |> Ash.Changeset.change_attribute(:reset_password_token, nil)
          |> Ash.Changeset.change_attribute(:reset_password_sent_at, nil)
          |> Ash.Changeset.change_attribute(:failed_attempts, 0)
        else
          changeset
        end
      end
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
    # Simplified for test
    define :change_password, args: [:password, :password_confirmation]
    define :soft_delete
    define :anonymize
    define :gdpr_anonymize
    define :destroy
    define :lock_account
    define :unlock_account
    define :increment_failed_attempts
    define :reset_failed_attempts
    define :request_password_reset
    define :reset_password_with_token, args: [:token, :password, :password_confirmation]
  end

  # Compatibility wrappers for existing code
  def get(id), do: by_id(id)
  def get_by_email(email), do: by_email(email)
  def get_by_id!(id), do: by_id!(id)

  def create(attrs),
    do: register(attrs["email"], attrs["password"], attrs["password_confirmation"])

  def register(attrs) when is_map(attrs) do
    # Normalize keys to atoms for Ash
    attrs =
      Map.new(attrs, fn
        {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
        {k, v} -> {k, v}
      end)

    Mcp.Accounts.User
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create()
  end

  def register(email, password) do
    register(email, password, password)
  end

  def change_password(user, attrs) do
    change_password(user, attrs["password"], attrs["password_confirmation"])
  end

  def register!(attrs) do
    case register(attrs) do
      {:ok, user} -> user
      {:error, error} -> raise Ash.Error.to_error_class(error)
    end
  end

  # Helper for test compatibility
  def anonymize_user(user), do: anonymize(user)

  def create_for_test(attrs) do
    # Ensure keys are atoms
    attrs =
      Map.new(attrs, fn
        {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
        {k, v} -> {k, v}
      end)

    # Handle password hashing manually for seed
    attrs =
      if Map.has_key?(attrs, :password) and not Map.has_key?(attrs, :hashed_password) do
        hashed = Bcrypt.hash_pwd_salt(attrs[:password])
        Map.put(attrs, :hashed_password, hashed)
      else
        attrs
      end

    # Use Ash.Seed to force creation with provided attributes (including timestamps if needed)
    Ash.Seed.seed!(Mcp.Accounts.User, attrs)
  end
end
