defmodule Mcp.Repo.Migrations.AddRlsHelperFunction do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION platform.can_access_owner(
      user_id uuid,
      owner_type text,
      owner_id uuid
    ) RETURNS boolean AS $$
    BEGIN
      IF owner_type = 'user' THEN
        RETURN user_id = owner_id;
      ELSIF owner_type = 'tenant' THEN
        RETURN EXISTS (
          SELECT 1 FROM platform.team_members tm
          JOIN platform.teams t ON tm.team_id = t.id
          WHERE tm.user_id = user_id AND t.tenant_id = owner_id
        );
      ELSE
        RETURN false;
      END IF;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION platform.can_access_owner(uuid, text, uuid)"
  end
end
