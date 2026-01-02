defmodule Mcp.Platform.ApiKey do
  @moduledoc """
  Resource representing API keys for authentication.
  Supports developer, merchant, and reseller key types with scoped access.
  """
  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "api_keys"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:prefix, :type, :scopes, :expires_at, :owner_id, :owner_type]
      argument :token, :string, sensitive?: true

      change Mcp.Platform.Changes.HashApiKey
    end

    update :revoke do
      accept []
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    update :update_last_used do
      accept []
      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end

    read :authenticate do
      argument :token, :string, sensitive?: true, allow_nil?: false

      prepare fn query, _ ->
        require Ash.Query
        token = Ash.Query.get_argument(query, :token)
        hashed = __MODULE__.hash_key(token)
        # Filter by hash and exclude revoked keys
        Ash.Query.filter(query, key_hash == ^hashed and is_nil(revoked_at))
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :key_hash, :string do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :prefix, :string do
      allow_nil? false
      constraints match: ~r/^[a-z0-9_]+$/
    end

    attribute :type, :atom do
      constraints one_of: [:developer, :merchant, :reseller]
      allow_nil? false
      default :developer
    end

    attribute :scopes, {:array, :string} do
      allow_nil? false
      default []
    end

    attribute :last_used_at, :utc_datetime_usec
    attribute :expires_at, :utc_datetime_usec
    attribute :revoked_at, :utc_datetime_usec

    attribute :owner_id, :uuid do
      allow_nil? false
    end

    # Polymorphic association could be handled by `owner_type` if needed,
    # but the plan specified `owner_id`. I'll stick to the plan but add `owner_type` for clarity if needed.
    # The plan says "Polymorphic: User or Tenant".
    # To support true polymorphism, we usually need `owner_type`.

    attribute :owner_type, :atom do
      constraints one_of: [:user, :tenant]
      allow_nil? false
    end

    timestamps()
  end

  calculations do
    # We might need a calculation to verify the key, but action logic is often better for security
  end

  code_interface do
    define :create
    define :revoke
    define :update_last_used
    define :authenticate, args: [:token], get?: true
  end

  def hash_key(key) do
    :crypto.hash(:sha256, key) |> Base.encode16(case: :lower)
  end
end
