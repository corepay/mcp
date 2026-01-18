defmodule Mcp.Underwriting.DocumentAnalysis do
  @moduledoc """
  Service for analyzing underwriting documents.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "document_analyses"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :status,
        :analysis_type,
        :markdown_content,
        :structured_data,
        :forensics_report,
        :camera_telemetry,
        :provider,
        :merchant_id
      ]
    end

    update :update do
      accept [
        :status,
        :analysis_type,
        :markdown_content,
        :structured_data,
        :forensics_report,
        :camera_telemetry,
        :provider
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:pending, :processing, :completed, :failed]
      default :pending
      allow_nil? false
    end

    attribute :analysis_type, :atom do
      constraints one_of: [:ocr, :forensics, :multimodal]
      default :ocr
    end

    attribute :markdown_content, :string do
      allow_nil? true
    end

    attribute :structured_data, :map do
      allow_nil? true
    end

    attribute :forensics_report, :map do
      description "Detailed forensic analysis report (manipulation, AI detection, etc)."
      allow_nil? true
    end

    attribute :camera_telemetry, :map do
      description "Metadata from Magic Camera (GPS, device info)."
      allow_nil? true
    end

    attribute :provider, :atom do
      constraints one_of: [:marker, :chandra, :the_eye]
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :merchant, Mcp.Platform.Merchant do
      allow_nil? false
    end
  end
end
