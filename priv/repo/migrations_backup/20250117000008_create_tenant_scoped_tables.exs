defmodule Mcp.Repo.Migrations.CreateTenantScopedTables do
  use Ecto.Migration

  def up do
    # This migration creates a template for tenant-scoped tables
    # These tables will be created in each tenant's schema (acq_{slug})
    # by the tenant onboarding Reactor saga

    # Store SQL templates for tenant tables
    execute """
    CREATE TABLE IF NOT EXISTS platform.tenant_table_templates (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      table_name TEXT NOT NULL UNIQUE,
      create_sql TEXT NOT NULL,
      description TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
    """

    # ========================================
    # MERCHANTS TABLE TEMPLATE
    # ========================================
    execute """
    INSERT INTO platform.tenant_table_templates (table_name, create_sql, description)
    VALUES (
      'merchants',
      $template$
        CREATE TABLE merchants (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

          slug TEXT NOT NULL,
          business_name TEXT NOT NULL,
          dba_name TEXT,

          subdomain TEXT NOT NULL,
          custom_domain TEXT,

          business_type TEXT,
          ein TEXT,
          website_url TEXT,
          description TEXT,

          address_line1 TEXT,
          address_line2 TEXT,
          city TEXT,
          state TEXT,
          postal_code TEXT,
          country TEXT DEFAULT 'US',

          phone TEXT,
          support_email TEXT,

          reseller_id UUID,

          plan TEXT DEFAULT 'starter',
          status TEXT DEFAULT 'active',

          settings JSONB DEFAULT '{}',
          branding JSONB DEFAULT '{}',

          max_stores INTEGER DEFAULT 0,
          max_products INTEGER,
          max_monthly_volume NUMERIC,

          risk_level TEXT DEFAULT 'low',
          kyc_verified_at TIMESTAMP,
          verification_status TEXT DEFAULT 'pending',

          -- Enhanced Fields
          mcc TEXT,
          tax_id_type TEXT, -- EIN, SSN
          kyc_status TEXT DEFAULT 'pending',
          kyc_documents JSONB DEFAULT '{}',

          timezone TEXT DEFAULT 'UTC',
          default_currency TEXT DEFAULT 'USD',
          operating_hours JSONB DEFAULT '{}',

          risk_score INTEGER,
          risk_profile TEXT DEFAULT 'low',
          processing_limits JSONB DEFAULT '{}',

          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

          UNIQUE(slug),
          UNIQUE(subdomain),
          CHECK (business_type IN ('sole_proprietor', 'llc', 'corporation', 'partnership', 'nonprofit')),
          CHECK (plan IN ('starter', 'professional', 'enterprise')),
          CHECK (status IN ('active', 'suspended', 'pending_verification', 'closed')),
          CHECK (risk_level IN ('low', 'medium', 'high')),
          CHECK (verification_status IN ('pending', 'verified', 'rejected'))
        );

        CREATE INDEX idx_merchants_slug ON merchants(slug);
        CREATE INDEX idx_merchants_subdomain ON merchants(subdomain);
        CREATE INDEX idx_merchants_status ON merchants(status);
        CREATE INDEX idx_merchants_reseller_id ON merchants(reseller_id) WHERE reseller_id IS NOT NULL;
        CREATE INDEX idx_merchants_plan ON merchants(plan);
        CREATE INDEX idx_merchants_risk_level ON merchants(risk_level);
      $template$,
      'Merchant accounts table for tenant schema'
    )
    """

    # ========================================
    # MIDS TABLE TEMPLATE
    # ========================================
    execute """
    INSERT INTO platform.tenant_table_templates (table_name, create_sql, description)
    VALUES (
      'mids',
      $template$
        CREATE TABLE mids (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,

          mid_number TEXT NOT NULL,
          gateway_id UUID NOT NULL,

          gateway_credentials JSONB NOT NULL,
          routing_rules JSONB DEFAULT '{}',

          status TEXT DEFAULT 'active',
          is_primary BOOLEAN DEFAULT false,

          -- Enhanced Fields
          processor_name TEXT,
          acquirer_name TEXT,
          batch_time TIME,
          
          supported_card_brands TEXT[],
          currencies TEXT[],
          fraud_settings JSONB DEFAULT '{}',

          daily_limit NUMERIC,
          monthly_limit NUMERIC,

          total_volume NUMERIC DEFAULT 0,
          total_transactions INTEGER DEFAULT 0,

          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

          UNIQUE(merchant_id, gateway_id, mid_number),
          CHECK (status IN ('active', 'suspended', 'testing'))
        );

        CREATE INDEX idx_mids_merchant_id ON mids(merchant_id);
        CREATE INDEX idx_mids_gateway_id ON mids(gateway_id);
        CREATE INDEX idx_mids_status ON mids(status);
        CREATE INDEX idx_mids_is_primary ON mids(merchant_id, is_primary) WHERE is_primary = true;
      $template$,
      'Merchant IDs (payment gateway accounts) table'
    )
    """

    # ========================================
    # STORES TABLE TEMPLATE
    # ========================================
    execute """
    INSERT INTO platform.tenant_table_templates (table_name, create_sql, description)
    VALUES (
      'stores',
      $template$
        CREATE TABLE stores (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,

          slug TEXT NOT NULL,
          name TEXT NOT NULL,

          routing_type TEXT DEFAULT 'path',
          subdomain TEXT,
          custom_domain TEXT,

          -- Enhanced Fields
          geo_location JSONB, -- {lat: ..., lng: ...}
          tax_nexus TEXT[],
          store_type TEXT, -- physical, online, hybrid, pop-up
          
          store_manager_name TEXT,
          store_phone TEXT,
          store_email TEXT,

          settings JSONB DEFAULT '{}',
          branding JSONB DEFAULT '{}',

          primary_mid_id UUID REFERENCES mids(id),
          fallback_mid_ids UUID[],

          status TEXT DEFAULT 'active',

          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

          UNIQUE(merchant_id, slug),
          CHECK (routing_type IN ('path', 'subdomain')),
          CHECK (status IN ('active', 'suspended', 'draft'))
        );

        CREATE INDEX idx_stores_merchant_id ON stores(merchant_id);
        CREATE INDEX idx_stores_slug ON stores(merchant_id, slug);
        CREATE INDEX idx_stores_status ON stores(status);
        CREATE INDEX idx_stores_primary_mid_id ON stores(primary_mid_id) WHERE primary_mid_id IS NOT NULL;
      $template$,
      'Stores (sub-brands) table for merchants'
    )
    """

    # ========================================
    # CUSTOMERS TABLE TEMPLATE
    # ========================================
    execute """
    INSERT INTO platform.tenant_table_templates (table_name, create_sql, description)
    VALUES (
      'customers',
      $template$
        CREATE TABLE customers (
          id UUID DEFAULT gen_random_uuid(),
          merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,

          email CITEXT NOT NULL,
          first_name TEXT,
          last_name TEXT,

          user_id UUID REFERENCES platform.users(id),

          phone TEXT,

          shipping_address JSONB,
          billing_address JSONB,

          saved_payment_methods JSONB DEFAULT '[]',

          total_orders INTEGER DEFAULT 0,
          total_spent NUMERIC DEFAULT 0,

          status TEXT DEFAULT 'active',

          -- Enhanced Fields
          marketing_preferences JSONB DEFAULT '{}',
          loyalty_tier TEXT,
          loyalty_points INTEGER DEFAULT 0,
          
          tags TEXT[],
          last_active_at TIMESTAMP,
          source TEXT,
          
          gdpr_consent BOOLEAN DEFAULT false,
          gdpr_consent_at TIMESTAMP,

          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

          PRIMARY KEY (merchant_id, id),
          UNIQUE(merchant_id, email),
          CHECK (status IN ('active', 'suspended', 'deleted'))
        );

        CREATE INDEX idx_customers_merchant_id ON customers(merchant_id);
        CREATE INDEX idx_customers_email ON customers(merchant_id, email);
        CREATE INDEX idx_customers_status ON customers(status);
        CREATE INDEX idx_customers_user_id ON customers(user_id);

        CREATE TABLE customers_stores (
          customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
          store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
          joined_at TIMESTAMP NOT NULL DEFAULT NOW(),
          PRIMARY KEY (customer_id, store_id)
        );

        CREATE INDEX idx_customers_stores_customer ON customers_stores(customer_id);
        CREATE INDEX idx_customers_stores_store ON customers_stores(store_id);
      $template$,
      'Customers table for merchant schema'
    )
    """

    # ========================================
    # VENDORS TABLE TEMPLATE
    # ========================================
    execute """
    INSERT INTO platform.tenant_table_templates (table_name, create_sql, description)
    VALUES (
      'vendors',
      $template$
        CREATE TABLE vendors (
          id UUID DEFAULT gen_random_uuid(),
          merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,

          name TEXT NOT NULL,
          service_type TEXT,
          
          user_id UUID REFERENCES platform.users(id),

          contact_name TEXT,
          contact_email TEXT,
          contact_phone TEXT,

          address JSONB,
          
          status TEXT DEFAULT 'active',

          -- Enhanced Fields
          tax_form_status TEXT, -- w9_received
          payment_terms TEXT, -- net30, net60
          
          service_category TEXT,
          performance_rating INTEGER,
          active_contracts JSONB DEFAULT '{}',

          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

          PRIMARY KEY (merchant_id, id),
          CHECK (status IN ('active', 'inactive'))
        );

        CREATE INDEX idx_vendors_merchant_id ON vendors(merchant_id);
        CREATE INDEX idx_vendors_status ON vendors(status);
        CREATE INDEX idx_vendors_user_id ON vendors(user_id);

        CREATE TABLE vendors_stores (
          vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
          store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
          assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
          PRIMARY KEY (vendor_id, store_id)
        );

        CREATE INDEX idx_vendors_stores_vendor ON vendors_stores(vendor_id);
        CREATE INDEX idx_vendors_stores_store ON vendors_stores(store_id);
      $template$,
      'Vendors table for merchant schema'
    )
    """

    # ========================================
    # DEVELOPERS TABLE TEMPLATE
    # ========================================


    # ========================================
    # RESELLERS TABLE TEMPLATE
    # ========================================

  end

  def down do
    execute "DROP TABLE IF EXISTS platform.tenant_table_templates CASCADE"
  end
end
