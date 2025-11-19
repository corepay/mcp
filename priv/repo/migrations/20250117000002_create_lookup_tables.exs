defmodule Mcp.Repo.Migrations.CreateLookupTables do
  use Ecto.Migration

  def up do
    # Entity Types - MUST be created first (referenced by all polymorphic tables)
    create table(:entity_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :description, :text
      add :category, :text
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime, default: fragment("NOW()"))
    end

    create index(:entity_types, [:category], prefix: "platform")
    create index(:entity_types, [:is_active], where: "is_active = true", prefix: "platform")

    # Seed entity types
    execute """
    INSERT INTO platform.entity_types (value, label, description, category, sort_order) VALUES
      -- Core entities
      ('user', 'User', 'Global platform user', 'core', 1),
      ('user_profile', 'User Profile', 'Entity-scoped user profile', 'core', 2),
      ('tenant', 'Tenant', 'Top-level tenant entity', 'core', 3),
      ('developer', 'Developer', 'External API developer', 'core', 4),
      ('reseller', 'Reseller', 'Partner reseller', 'core', 5),
      ('merchant', 'Merchant', 'Merchant account', 'core', 6),
      ('store', 'Store', 'Store entity', 'core', 7),
      ('customer', 'Customer', 'End customer', 'core', 8),
      ('vendor', 'Vendor', 'Vendor/supplier', 'core', 9),

      -- Commerce entities
      ('product', 'Product', 'Product entity', 'commerce', 10),
      ('product_variant', 'Product Variant', 'Product SKU variant', 'commerce', 11),
      ('category', 'Category', 'Product category', 'commerce', 12),
      ('collection', 'Collection', 'Product collection', 'commerce', 13),
      ('order', 'Order', 'Customer order', 'commerce', 14),
      ('order_item', 'Order Item', 'Line item in order', 'commerce', 15),
      ('cart', 'Shopping Cart', 'Customer cart', 'commerce', 16),
      ('cart_item', 'Cart Item', 'Item in cart', 'commerce', 17),

      -- Payment entities
      ('transaction', 'Transaction', 'Payment transaction', 'payments', 20),
      ('payment_method', 'Payment Method', 'Saved payment method', 'payments', 21),
      ('refund', 'Refund', 'Payment refund', 'payments', 22),
      ('chargeback', 'Chargeback', 'Payment chargeback', 'payments', 23),
      ('payout', 'Payout', 'Merchant payout', 'payments', 24),
      ('mid', 'MID', 'Merchant ID account', 'payments', 25),

      -- Shipping entities
      ('shipment', 'Shipment', 'Order shipment', 'shipping', 30),
      ('shipment_item', 'Shipment Item', 'Item in shipment', 'shipping', 31),
      ('tracking_event', 'Tracking Event', 'Shipment tracking update', 'shipping', 32),

      -- Content entities
      ('page', 'Page', 'CMS page', 'content', 40),
      ('blog_post', 'Blog Post', 'Blog article', 'content', 41),
      ('media', 'Media', 'Media asset', 'content', 42),

      -- Marketing entities
      ('campaign', 'Campaign', 'Marketing campaign', 'marketing', 50),
      ('discount', 'Discount', 'Discount rule', 'marketing', 51),
      ('coupon', 'Coupon', 'Coupon code', 'marketing', 52),
      ('loyalty_program', 'Loyalty Program', 'Customer loyalty program', 'marketing', 53),

      -- Support entities
      ('ticket', 'Support Ticket', 'Customer support ticket', 'support', 60),
      ('message', 'Message', 'Support message', 'support', 61),
      ('kb_article', 'Knowledge Base Article', 'Help article', 'support', 62)
    """

    # Address Types
    create table(:address_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :description, :text
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
    INSERT INTO platform.address_types (value, label, description, sort_order) VALUES
      ('home', 'Home Address', 'Personal home address', 1),
      ('business', 'Business Address', 'Business/office address', 2),
      ('shipping', 'Shipping Address', 'Shipping/delivery address', 3),
      ('billing', 'Billing Address', 'Billing address for invoices', 4),
      ('legal', 'Legal Address', 'Legal/registered address', 5),
      ('warehouse', 'Warehouse', 'Warehouse/fulfillment center', 6),
      ('pickup', 'Pickup Location', 'Customer pickup location', 7)
    """

    # Email Types
    create table(:email_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
    INSERT INTO platform.email_types (value, label, sort_order) VALUES
      ('personal', 'Personal', 1),
      ('work', 'Work', 2),
      ('support', 'Support', 3),
      ('billing', 'Billing', 4),
      ('noreply', 'No Reply', 5),
      ('sales', 'Sales', 6),
      ('marketing', 'Marketing', 7)
    """

    # Phone Types
    create table(:phone_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :is_active, :boolean, default: true
      add :supports_sms, :boolean, default: false
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
    INSERT INTO platform.phone_types (value, label, supports_sms, sort_order) VALUES
      ('mobile', 'Mobile', true, 1),
      ('home', 'Home', false, 2),
      ('work', 'Work', false, 3),
      ('fax', 'Fax', false, 4),
      ('support', 'Support', true, 5),
      ('toll_free', 'Toll Free', false, 6)
    """

    # Social Platforms
    create table(:social_platforms, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :icon, :text
      add :url_pattern, :text
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
    INSERT INTO platform.social_platforms (value, label, icon, url_pattern, sort_order) VALUES
      ('twitter', 'Twitter/X', 'twitter', 'https://twitter.com/{username}', 1),
      ('facebook', 'Facebook', 'facebook', 'https://facebook.com/{username}', 2),
      ('instagram', 'Instagram', 'instagram', 'https://instagram.com/{username}', 3),
      ('linkedin', 'LinkedIn', 'linkedin', 'https://linkedin.com/in/{username}', 4),
      ('tiktok', 'TikTok', 'tiktok', 'https://tiktok.com/@{username}', 5),
      ('youtube', 'YouTube', 'youtube', 'https://youtube.com/@{username}', 6),
      ('github', 'GitHub', 'github', 'https://github.com/{username}', 7),
      ('pinterest', 'Pinterest', 'pinterest', 'https://pinterest.com/{username}', 8),
      ('snapchat', 'Snapchat', 'snapchat', 'https://snapchat.com/add/{username}', 9)
    """

    # Image Types
    create table(:image_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :max_file_size, :integer
      add :allowed_mime_types, {:array, :text}
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
    INSERT INTO platform.image_types (value, label, max_file_size, allowed_mime_types, sort_order) VALUES
      ('avatar', 'Avatar', 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'], 1),
      ('logo', 'Logo', 2097152, ARRAY['image/png', 'image/svg+xml'], 2),
      ('banner', 'Banner', 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'], 3),
      ('product', 'Product Image', 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'], 4),
      ('gallery', 'Gallery Image', 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'], 5),
      ('document_scan', 'Document Scan', 20971520, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 6),
      ('thumbnail', 'Thumbnail', 1048576, ARRAY['image/jpeg', 'image/png', 'image/webp'], 7)
    """

    # Document Types
    create table(:document_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :description, :text
      add :is_sensitive, :boolean, default: true
      add :requires_encryption, :boolean, default: true
      add :retention_years, :integer
      add :allowed_mime_types, {:array, :text}
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
    INSERT INTO platform.document_types (value, label, description, is_sensitive, requires_encryption, retention_years, allowed_mime_types, sort_order) VALUES
      ('kyc_id', 'KYC ID Document', 'Government-issued ID', true, true, 7, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 1),
      ('kyc_address_proof', 'KYC Address Proof', 'Proof of address', true, true, 7, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 2),
      ('contract', 'Contract', 'Legal contract', true, true, 10, ARRAY['application/pdf'], 3),
      ('invoice', 'Invoice', 'Invoice document', false, false, 7, ARRAY['application/pdf'], 4),
      ('receipt', 'Receipt', 'Payment receipt', false, false, 7, ARRAY['application/pdf'], 5),
      ('tax_form', 'Tax Form', 'Tax document', true, true, 7, ARRAY['application/pdf'], 6),
      ('legal', 'Legal Document', 'Legal filing', true, true, NULL, ARRAY['application/pdf'], 7),
      ('bank_statement', 'Bank Statement', 'Bank account statement', true, true, 7, ARRAY['application/pdf'], 8),
      ('business_license', 'Business License', 'Business registration', true, true, 10, ARRAY['image/jpeg', 'image/png', 'application/pdf'], 9)
    """

    # Status Types
    create table(:status_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :category, :text
      add :color, :text
      add :is_final, :boolean, default: false
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      add :created_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute """
    INSERT INTO platform.status_types (value, label, category, color, is_final, sort_order) VALUES
      -- Entity statuses
      ('active', 'Active', 'entity', '#22c55e', false, 1),
      ('suspended', 'Suspended', 'entity', '#f59e0b', false, 2),
      ('pending', 'Pending', 'entity', '#3b82f6', false, 3),
      ('trial', 'Trial', 'entity', '#8b5cf6', false, 4),
      ('canceled', 'Canceled', 'entity', '#ef4444', true, 5),
      ('closed', 'Closed', 'entity', '#6b7280', true, 6),

      -- Transaction statuses
      ('pending_payment', 'Pending Payment', 'transaction', '#f59e0b', false, 10),
      ('processing', 'Processing', 'transaction', '#3b82f6', false, 11),
      ('succeeded', 'Succeeded', 'transaction', '#22c55e', true, 12),
      ('failed', 'Failed', 'transaction', '#ef4444', true, 13),
      ('refunded', 'Refunded', 'transaction', '#6b7280', true, 14),
      ('partially_refunded', 'Partially Refunded', 'transaction', '#f59e0b', false, 15),

      -- Order statuses
      ('draft', 'Draft', 'order', '#6b7280', false, 20),
      ('pending_fulfillment', 'Pending Fulfillment', 'order', '#f59e0b', false, 21),
      ('fulfilled', 'Fulfilled', 'order', '#22c55e', false, 22),
      ('shipped', 'Shipped', 'order', '#3b82f6', false, 23),
      ('delivered', 'Delivered', 'order', '#22c55e', true, 24),
      ('returned', 'Returned', 'order', '#ef4444', true, 25)
    """

    # Plan Types
    create table(:plan_types, primary_key: false, prefix: "platform") do
      add :value, :text, primary_key: true
      add :label, :text, null: false
      add :description, :text
      add :features, :jsonb, default: "{}"
      add :pricing, :jsonb, default: "{}"
      add :limits, :jsonb, default: "{}"
      add :is_active, :boolean, default: true
      add :sort_order, :integer, default: 0

      timestamps(type: :utc_datetime, default: fragment("NOW()"))
    end

    execute """
    INSERT INTO platform.plan_types (value, label, description, pricing, limits, sort_order) VALUES
      ('starter', 'Starter', 'For small businesses getting started', '{"monthly": 0}'::jsonb, '{"max_users": 2, "max_api_calls": 1000}'::jsonb, 1),
      ('professional', 'Professional', 'For growing businesses', '{"monthly": 49, "annual": 490}'::jsonb, '{"max_users": 10, "max_api_calls": 10000}'::jsonb, 2),
      ('enterprise', 'Enterprise', 'For large organizations', '{"monthly": 149, "annual": 1490}'::jsonb, '{"max_users": -1, "max_api_calls": -1}'::jsonb, 3)
    """
  end

  def down do
    drop table(:plan_types, prefix: "platform")
    drop table(:status_types, prefix: "platform")
    drop table(:document_types, prefix: "platform")
    drop table(:image_types, prefix: "platform")
    drop table(:social_platforms, prefix: "platform")
    drop table(:phone_types, prefix: "platform")
    drop table(:email_types, prefix: "platform")
    drop table(:address_types, prefix: "platform")
    drop table(:entity_types, prefix: "platform")
  end
end
