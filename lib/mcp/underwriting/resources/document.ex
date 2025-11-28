defmodule Mcp.Underwriting.Document do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_documents"
    repo Mcp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:file_path, :file_name, :mime_type, :document_type, :application_id]
    end

    update :update_status do
      accept [:status]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :file_path, :string do
      allow_nil? false
    end

    attribute :file_name, :string do
      allow_nil? false
    end

    attribute :mime_type, :string do
      allow_nil? false
    end

    attribute :document_type, :atom do
      constraints [one_of: [:identity, :address, :incorporation, :other]]
      default :other
    end

    attribute :status, :atom do
      constraints [one_of: [:pending, :verified, :rejected]]
      default :pending
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application
    belongs_to :client, Mcp.Underwriting.Client
  end

  code_interface do
    define :create
    define :read
    define :update_status
    define :destroy
  end
end
