-- Force create auth_tokens table
DROP TABLE IF EXISTS platform.auth_tokens CASCADE;

CREATE TABLE platform.auth_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES platform.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  type text NOT NULL,
  expires_at timestamp(6) without time zone NOT NULL,
  revoked_at timestamp(6) without time zone,
  used_at timestamp(6) without time zone,
  context jsonb DEFAULT '{}',
  device_info jsonb DEFAULT '{}',
  inserted_at timestamp(6) without time zone NOT NULL DEFAULT NOW(),
  updated_at timestamp(6) without time zone NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX auth_tokens_token_index ON platform.auth_tokens (token);
CREATE INDEX auth_tokens_user_id_index ON platform.auth_tokens (user_id);
CREATE INDEX auth_tokens_type_index ON platform.auth_tokens (type);
