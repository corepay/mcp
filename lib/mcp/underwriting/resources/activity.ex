defmodule Mcp.Underwriting.Activity do
  @moduledoc """
  Activity log for underwriting events.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_activities"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:type, :metadata, :actor_id]
      argument :application_id, :uuid, allow_nil?: false
      change manage_relationship(:application_id, :application, type: :append_and_remove)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      constraints one_of: [
                    :status_change,
                    :comment,
                    :alert,
                    :system_event,
                    :internal_note,
                    :risk_assessment,
                    :document_upload,
                    :kyc_failure,
                    :kyc_success,
                    :kyb_failure,
                    :kyb_success
                  ]

      allow_nil? false
    end

    attribute :metadata, :map do
      default %{}
    end

    # Could be User ID or System
    attribute :actor_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application do
      domain Mcp.Underwriting
    end
  end

  code_interface do
    define :create
    define :read
  end
end
