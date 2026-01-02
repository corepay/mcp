defmodule Mcp.Underwriting.Note do
  @moduledoc """
  Notes for application collaboration in the deal room.
  Supports @mentions and visibility controls.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_notes"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:content, :visibility, :mentions]
      argument :application_id, :uuid, allow_nil?: false
      argument :author_id, :uuid, allow_nil?: false

      change manage_relationship(:application_id, :application, type: :append_and_remove)
      change manage_relationship(:author_id, :author, type: :append_and_remove)
    end

    update :update do
      accept [:content]
    end

    read :for_application do
      argument :application_id, :uuid, allow_nil?: false
      filter expr(application_id == ^arg(:application_id))
      prepare build(sort: [inserted_at: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 10_000
    end

    attribute :visibility, :atom do
      constraints one_of: [:internal, :shared_with_applicant]
      default :internal
    end

    attribute :mentions, {:array, :uuid} do
      default []
      description "User IDs mentioned in this note"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application do
      domain Mcp.Underwriting
    end

    belongs_to :author, Mcp.Accounts.User do
      domain Mcp.Accounts
    end
  end

  code_interface do
    define :create
    define :read
    define :for_application, args: [:application_id]
    define :update
    define :destroy
  end
end
