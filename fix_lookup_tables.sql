-- Manually create missing lookup tables to unblock migrations

CREATE SCHEMA IF NOT EXISTS platform;

CREATE TABLE IF NOT EXISTS platform.entity_types (
  value text PRIMARY KEY,
  label text NOT NULL,
  description text,
  category text,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  metadata jsonb DEFAULT '{}',
  created_at timestamp(0) without time zone NOT NULL DEFAULT NOW(),
  updated_at timestamp(0) without time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS platform.address_types (
  value text PRIMARY KEY,
  label text NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamp(0) without time zone NOT NULL DEFAULT NOW()
);

INSERT INTO platform.address_types (value, label, description, sort_order) VALUES
  ('home', 'Home Address', 'Personal home address', 1),
  ('business', 'Business Address', 'Business/office address', 2),
  ('shipping', 'Shipping Address', 'Shipping/delivery address', 3),
  ('billing', 'Billing Address', 'Billing address for invoices', 4),
  ('legal', 'Legal Address', 'Legal/registered address', 5),
  ('warehouse', 'Warehouse', 'Warehouse/fulfillment center', 6),
  ('pickup', 'Pickup Location', 'Customer pickup location', 7)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS platform.email_types (
  value text PRIMARY KEY,
  label text NOT NULL,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamp(0) without time zone NOT NULL DEFAULT NOW()
);

INSERT INTO platform.email_types (value, label, sort_order) VALUES
  ('personal', 'Personal', 1),
  ('work', 'Work', 2),
  ('support', 'Support', 3),
  ('billing', 'Billing', 4),
  ('noreply', 'No Reply', 5),
  ('sales', 'Sales', 6),
  ('marketing', 'Marketing', 7)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS platform.phone_types (
  value text PRIMARY KEY,
  label text NOT NULL,
  is_active boolean DEFAULT true,
  supports_sms boolean DEFAULT false,
  sort_order integer DEFAULT 0,
  created_at timestamp(0) without time zone NOT NULL DEFAULT NOW()
);

INSERT INTO platform.phone_types (value, label, supports_sms, sort_order) VALUES
  ('mobile', 'Mobile', true, 1),
  ('home', 'Home', false, 2),
  ('work', 'Work', false, 3),
  ('fax', 'Fax', false, 4),
  ('support', 'Support', true, 5),
  ('toll_free', 'Toll Free', false, 6)
ON CONFLICT DO NOTHING;
