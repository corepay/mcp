defmodule Mcp.Platform.CustomDomain do
  @moduledoc """
  Resource representing custom domains for tenants with DNS verification.
  """
  use Ash.Resource,
    otp_app: :mcp,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mcp.Infrastructure.DnsVerifier

  postgres do
    table "custom_domains"
    repo(Mcp.Repo)
  end

  policies do
    # Strict policies for Tenant ownership
    policy action_type(:create) do
      authorize_if Mcp.Platform.Checks.TenantMemberForCreate
    end

    policy action_type(:read) do
      authorize_if Mcp.Platform.Checks.TenantMember
    end

    policy action_type(:update) do
      authorize_if Mcp.Platform.Checks.TenantMember
    end

    policy action_type(:destroy) do
      authorize_if Mcp.Platform.Checks.TenantMember
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :domain, :string do
      allow_nil? false
      public? true
      # Ensure lowercase and standard format
      constraints match:
                    ~r/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$/
    end

    attribute :state, :atom do
      constraints one_of: [:pending_verification, :verified, :active, :failed]
      default :pending_verification
      allow_nil? false
      # Visible to user
      public? true
      # Only writable via actions
      writable? false
    end

    attribute :verification_record_name, :string do
      allow_nil? false
      public? true
      default "_mcp_challenge"
    end

    attribute :verification_record_value, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:domain, :tenant_id]

      change set_attribute(:verification_record_value, &Ash.UUID.generate/0)
      change set_attribute(:state, :pending_verification)
    end

    action :verify do
      # Custom action to trigger verification
      transaction? true

      run fn input, context ->
        domain = input.data.domain
        expected_value = input.data.verification_record_value
        # Record name is assumed to be a subdomain prefix: _mcp_challenge.example.com
        # Or just checking TXT on the domain itself?
        # Plan said: `_mcp_challenge.<domain>`.
        full_record_name = "#{input.data.verification_record_name}.#{domain}"

        case DnsVerifier.verify_txt(full_record_name, expected_value) do
          {:ok, true} ->
            {:ok, Ash.Changeset.for_update(input.data, :set_verified) |> Ash.update!()}

          {:ok, false} ->
            {:error, Ash.Error.to_error_class("DNS Verification failed: Record not found")}

          {:error, reason} ->
            {:error, Ash.Error.to_error_class("DNS Check Error: #{inspect(reason)}")}
        end
      end
    end

    update :set_verified do
      accept []
      change set_attribute(:state, :verified)
    end

    update :activate do
      accept []
      change set_attribute(:state, :active)
    end
  end
end
