defmodule Mcp.Accounts.RegistrationRequest do
  @moduledoc """
  Registration request resource for managing user registration workflows.

  Handles registration requests that require approval before user accounts
  are created. Supports different registration types and tenant associations.
  """

  use Ash.Resource,
    domain: Mcp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "registration_requests"
    schema("platform")
    repo(Mcp.Repo)

    custom_indexes do
      index([:tenant_id, :status])
      index([:email])
      index([:status, :created_at])
    end
  end

  json_api do
    type "registration_request"
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      description "Tenant ID for multi-tenancy"
    end

    attribute :type, :atom do
      constraints one_of: [:customer, :vendor, :merchant, :reseller, :developer, :admin]
      default :customer
      allow_nil? false
      description "Type of registration request"
    end

    attribute :email, :ci_string do
      allow_nil? false
      description "Email address for the registration request"
    end

    attribute :first_name, :string do
      allow_nil? true
      description "First name of the registrant"
    end

    attribute :last_name, :string do
      allow_nil? true
      description "Last name of the registrant"
    end

    attribute :phone, :string do
      allow_nil? true
      description "Phone number of the registrant"
    end

    attribute :company_name, :string do
      allow_nil? true
      description "Company or organization name"
    end

    attribute :registration_data, :map do
      default %{}
      description "Additional registration data as JSON"
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :submitted, :approved, :rejected]
      default :pending
      allow_nil? false
      description "Current status of the registration request"
    end

    attribute :submitted_at, :utc_datetime do
      description "When the request was submitted for review"
    end

    attribute :approved_at, :utc_datetime do
      description "When the request was approved"
    end

    attribute :rejected_at, :utc_datetime do
      description "When the request was rejected"
    end

    attribute :approved_by_id, :uuid do
      description "ID of the user who approved this request"
    end

    attribute :rejection_reason, :string do
      allow_nil? true
      description "Reason for rejection if status is rejected"
    end

    attribute :reviewed_by, :string do
      description "ID or email of the user who reviewed this request"
    end

    attribute :context, :map do
      default %{}
      description "Additional context metadata"
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant do
      domain Mcp.Platform
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :initialize do
      primary? true

      accept [
        :tenant_id,
        :type,
        :email,
        :first_name,
        :last_name,
        :phone,
        :company_name,
        :registration_data,
        :context
      ]

      change set_attribute(:status, :pending)
    end

    update :submit do
      accept [:context]
      require_atomic? false

      change set_attribute(:status, :submitted)
      change set_attribute(:submitted_at, DateTime.utc_now())
    end

    update :approve do
      accept [:rejection_reason]
      argument :approver_id, :uuid, allow_nil?: false
      require_atomic? false

      change set_attribute(:status, :approved)
      change set_attribute(:approved_at, DateTime.utc_now())
      change set_attribute(:approved_by_id, arg(:approver_id))
    end

    update :reject do
      accept [:rejection_reason, :reviewed_by]
      argument :reviewer_id, :string
      require_atomic? false

      change set_attribute(:status, :rejected)
      change set_attribute(:rejected_at, DateTime.utc_now())
      change set_attribute(:reviewed_by, arg(:reviewer_id))
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      get_by [:id]
    end

    read :by_email do
      argument :email, :ci_string, allow_nil?: false
      filter expr(email == ^arg(:email))
    end

    read :pending do
      filter expr(status == :pending)
    end

    read :submitted do
      filter expr(status == :submitted)
    end

    read :by_tenant do
      argument :tenant_id, :uuid, allow_nil?: false
      filter expr(tenant_id == ^arg(:tenant_id))
    end

    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end
  end

  code_interface do
    define :read

    define :initialize,
      args: [
        :tenant_id,
        :type,
        :email,
        :first_name,
        :last_name,
        :phone,
        :company_name,
        :registration_data,
        :context
      ]

    define :submit, args: [:context]
    define :approve, args: [:approver_id]
    define :reject, args: [:rejection_reason, :reviewer_id]
    define :by_id, args: [:id], get?: true
    define :by_email, args: [:email]
    define :pending
    define :submitted
    define :by_tenant, args: [:tenant_id]
    define :by_status, args: [:status]
    define :destroy
  end

  validations do
    validate match(:email, ~r/@/), where: changing(:email)
    validate present([:tenant_id, :type, :email])
  end
end
