defmodule Mcp.Repo.TenantMigrations.AddReviewerIdToReviews do
  @moduledoc """
  Adds reviewer_id to underwriting_reviews table for audit compliance.

  This links each review to the user who performed it, which is required
  for regulatory audit trails.

  NOTE: reviewer_id references the users table in the platform schema,
  not the tenant schema, since users are centralized.
  """
  use Ecto.Migration

  def up do
    alter table(:underwriting_reviews, prefix: prefix()) do
      add_if_not_exists :reviewer_id,
          references(:users,
            column: :id,
            name: "underwriting_reviews_reviewer_id_fkey",
            type: :uuid,
            prefix: "platform"
          ),
          null: false
    end

    create_if_not_exists index(:underwriting_reviews, [:reviewer_id], prefix: prefix())
  end

  def down do
    drop_if_exists index(:underwriting_reviews, [:reviewer_id], prefix: prefix())

    alter table(:underwriting_reviews, prefix: prefix()) do
      remove_if_exists :reviewer_id, :uuid
    end
  end
end
