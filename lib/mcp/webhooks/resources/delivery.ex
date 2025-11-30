defmodule Mcp.Webhooks.Delivery do
  use Ash.Resource,
    domain: Mcp.Webhooks,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  oban do
    triggers do
      trigger :create do
        action :create
        worker_module_name(Mcp.Webhooks.Delivery.AshOban.Worker.Create)
        scheduler_module_name(Mcp.Webhooks.Delivery.AshOban.Scheduler.Create)
      end
    end
  end

  postgres do
    table "webhook_deliveries"
    repo(Mcp.Repo)
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:endpoint_id, :event, :payload, :status, :response_code, :response_body]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :event, :string do
      allow_nil? false
    end

    attribute :payload, :map do
      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :success, :failure, :retrying]
      default :pending
      allow_nil? false
    end

    attribute :response_code, :integer do
      allow_nil? true
    end

    attribute :response_body, :string do
      allow_nil? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :endpoint, Mcp.Webhooks.Endpoint do
      allow_nil? false
    end
  end
end
