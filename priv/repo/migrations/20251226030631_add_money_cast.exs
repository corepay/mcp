defmodule Mcp.Repo.Migrations.AddMoneyCast do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION jsonb_to_money_with_currency(data jsonb)
    RETURNS money_with_currency
    LANGUAGE sql
    IMMUTABLE
    AS $$
      SELECT jsonb_populate_record(null::money_with_currency, data);
    $$;
    """

    execute """
    CREATE CAST (jsonb AS money_with_currency)
    WITH FUNCTION jsonb_to_money_with_currency(jsonb)
    AS IMPLICIT;
    """
  end

  def down do
    execute "DROP CAST IF EXISTS (jsonb AS money_with_currency);"
    execute "DROP FUNCTION IF EXISTS jsonb_to_money_with_currency(jsonb);"
  end
end
