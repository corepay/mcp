defmodule Mcp.Repo.Migrations.AddDocumentResource do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create table(:documents, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :content, :text, null: false
      add :metadata, :map, null: false, default: %{}
      add :embedding, :vector, size: 1536
      
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:documents, ["embedding vector_cosine_ops"], name: "documents_embedding_index", using: "hnsw")
  end

  def down do
    drop table(:documents)
    # We don't drop the extension as other things might use it, or it's safer to keep.
  end
end
