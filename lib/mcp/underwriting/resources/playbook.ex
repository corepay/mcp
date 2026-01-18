defmodule Mcp.Underwriting.Playbook do
  @moduledoc """
  Represents a Human-Architected or AI-Assisted Playbook for underwriting.
  Playbooks define rules, industry context, and risk thresholds.
  """
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "underwriting_playbooks"
    repo(Mcp.Repo)
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :industry, :rules_markdown, :thresholds, :is_active]
      change &calculate_hash/2
    end

    update :update do
      require_atomic? false
      accept [:name, :industry, :rules_markdown, :thresholds, :is_active]
      change &calculate_hash/2
    end

    read :active do
      filter expr(is_active == true)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "The name of the Playbook (e.g. 'Standard SaaS Risk Profile')."
    end

    attribute :industry, :string do
      description "The industry sector this playbook is optimized for."
    end

    attribute :rules_markdown, :string do
      allow_nil? false
      description "Markdown-formatted rules that define the risk logic."
    end

    attribute :thresholds, :map do
      description "Dynamic thresholds for auto-approval/rejection."
      default %{auto_approve: 90, auto_reject: 50}
    end

    attribute :hash, :string do
      description "SHA-256 fingerprint for decision lineage."
    end

    attribute :is_active, :boolean do
      default true
    end

    timestamps()
  end

  def calculate_hash(changeset, _) do
    rules = Ash.Changeset.get_attribute(changeset, :rules_markdown) || ""
    thresholds = Ash.Changeset.get_attribute(changeset, :thresholds) || %{}

    # Fingerprint both rules and thresholds
    content = "#{rules}|#{inspect(thresholds)}"
    hash = :crypto.hash(:sha256, content) |> Base.encode16()

    Ash.Changeset.force_change_attribute(changeset, :hash, hash)
  end
end
