defmodule Mcp.Gdpr.Resources.DataExport do
  @moduledoc """
  Ash resource for GDPR data export requests.

  Manages user data export requests including status tracking,
  file generation, and access control.
  """

  use Ash.Resource,
    domain: Mcp.Domains.Gdpr,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "gdpr_exports"
    repo Mcp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :string do
      default "pending"
    end

    attribute :format, :string do
      allow_nil? false
    end

    attribute :purpose, :string do
      default "user_request"
    end

    attribute :file_path, :string
    attribute :file_size, :integer
    attribute :download_url, :string
    attribute :downloaded_at, :utc_datetime_usec
    attribute :completed_at, :utc_datetime_usec
    attribute :error_message, :string
    attribute :expires_at, :utc_datetime_usec

    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :user_id, :uuid do
      allow_nil? false
    end

    attribute :actor_id, :uuid
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
    end

    read :by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end
      filter expr(user_id == ^arg(:user_id))
    end

    read :pending_exports do
      filter expr(status == "pending")
    end

    read :completed_exports do
      filter expr(status == "completed")
    end

    read :expired_exports do
      filter expr(expires_at < ^DateTime.utc_now())
    end

    create :create_export do
      accept [:user_id, :format, :purpose, :actor_id]
      change set_attribute(:status, "pending")
    end

    update :mark_processing do
      change set_attribute(:status, "processing")
    end

    update :mark_completed do
      accept [:file_path, :file_size, :download_url]
      change set_attribute(:status, "completed")
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :mark_failed do
      accept [:error_message]
      change set_attribute(:status, "failed")
    end

    update :mark_downloaded do
      change set_attribute(:downloaded_at, &DateTime.utc_now/0)
    end
  end

  relationships do
    belongs_to :user, Mcp.Gdpr.Resources.User do
      allow_nil? false
    end
  end

  validations do
    validate present([:user_id, :format])
  end
end