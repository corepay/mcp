-- Manually create missing auth tables to unblock migrations

CREATE SCHEMA IF NOT EXISTS platform;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS platform.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email citext NOT NULL,
  hashed_password text NOT NULL,
  totp_secret text,
  backup_codes text[],
  confirmed_at timestamp(0) without time zone,
  oauth_tokens jsonb DEFAULT '{}',
  last_sign_in_at timestamp(0) without time zone,
  last_sign_in_ip inet,
  sign_in_count integer DEFAULT 0,
  status text NOT NULL DEFAULT 'active',
  inserted_at timestamp(0) without time zone NOT NULL DEFAULT NOW(),
  updated_at timestamp(0) without time zone NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_index ON platform.users (email);

CREATE TABLE IF NOT EXISTS platform.auth_tokens (
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

CREATE UNIQUE INDEX IF NOT EXISTS auth_tokens_token_index ON platform.auth_tokens (token);
