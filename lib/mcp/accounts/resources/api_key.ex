defmodule Mcp.Accounts.ApiKey do
  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "api_keys"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :tenant_id, :merchant_id, :reseller_id, :rate_limit, :spending_limit, :permissions, :scopes]
      argument :key, :string, allow_nil?: false, sensitive?: true

      change fn changeset, _ ->
        key = Ash.Changeset.get_argument(changeset, :key)
        
        # Store hash and prefix
        hashed_key = Bcrypt.hash_pwd_salt(key)
        prefix = String.slice(key, 0, 7)
        
        changeset
        |> Ash.Changeset.change_attribute(:key_hash, hashed_key)
        |> Ash.Changeset.change_attribute(:prefix, prefix)
      end
    end

    read :by_prefix do
      argument :prefix, :string, allow_nil?: false
      filter expr(prefix == ^arg(:prefix))
    end

    update :update do
      accept [:last_used_at, :rate_limit, :spending_limit, :permissions, :scopes]
    end
  end

  code_interface do
    define :create
    define :by_prefix, args: [:prefix]
    define :update
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Human readable name for the key"
    end

    attribute :key_hash, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :prefix, :string do
      allow_nil? false
      description "First 7 chars of the key for lookup"
    end

    attribute :last_used_at, :utc_datetime_usec do
      allow_nil? true
    end

    attribute :reseller_id, :uuid do
      allow_nil? true
    end

    attribute :rate_limit, :integer do
      allow_nil? true
      description "Requests per minute"
    end

    attribute :spending_limit, :decimal do
      allow_nil? true
      description "Max spend in USD per month"
    end

    attribute :permissions, {:array, :string} do
      allow_nil? false
      default []
      description "Functional permissions (e.g. ['underwriting:read', 'rag:write'])"
    end

    attribute :scopes, {:array, :string} do
      allow_nil? false
      default []
      description "Entity scopes (e.g. ['merchant:uuid', 'reseller:uuid'])"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? true
    end

    belongs_to :merchant, Mcp.Platform.Merchant do
      allow_nil? true
    end
  end
end
