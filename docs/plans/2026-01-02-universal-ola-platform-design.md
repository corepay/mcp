# Universal OLA Platform Design

**Date**: January 2, 2026
**Status**: Design Complete - Ready for Implementation Planning
**Version**: 1.0

---

## Executive Summary

Transform the existing merchant-focused OLA (Online Application) and Underwriting domains into a **universal, multi-vertical application platform**. The platform will serve:

1. **Core Fintech** - Merchant onboarding for card processing (current use case)
2. **Property Management** - Tenant screening, property manager onboarding
3. **Lending** - Loan origination, borrower underwriting
4. **Underwriting-as-a-Service** - Pure OLA/UW for companies with existing payment rails

Each vertical appears as a focused, purpose-built SaaS product while sharing a unified platform underneath.

---

## Key Design Decisions

| Question | Decision |
|----------|----------|
| Target verticals | All: Lending, B2B onboarding, B2C, Property, Universal |
| Configurability model | Hybrid: Platform templates + Tenant customization + Full builder |
| App Type ↔ Pipeline relationship | Many:many (fully decoupled with routing rules) |
| AI architecture | Layered: Base capabilities + Domain expertise + Tenant customizations |
| Form/wizard UX | Fully dynamic rendering from schema |
| Entity model | Abstract base entities with vertical "skins" |
| Vertical configuration | Vertical controls portals, entities, and features |
| Branding strategy | Start unified (vertical landing pages), evolve to white-labeled products |
| OLA Builder interface | Hybrid: Template start → Visual customize → Schema export |

---

## Architecture Overview

### Multi-Product Facade

```
Marketing/Sales Layer:
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   CardReady     │  │   PropScreen    │  │   LendFlow      │  │   UnderwriteAPI │
│ "Merchant       │  │ "Property       │  │ "Loan           │  │ "Underwriting   │
│  Onboarding"    │  │  Intelligence"  │  │  Origination"   │  │  as a Service"  │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │                    │
         └────────────────────┴────────────────────┴────────────────────┘
                                         │
                                         ▼
                       ┌───────────────────────────────────┐
                       │       Unified MCP Platform         │
                       │  ┌─────────────────────────────┐  │
                       │  │         OLA Engine          │  │
                       │  │  (Builder + Renderer + AI)  │  │
                       │  └──────────────┬──────────────┘  │
                       │                 │                 │
                       │  ┌──────────────┴──────────────┐  │
                       │  │    Underwriting Engine      │  │
                       │  │  (Pipelines + Routing +     │  │
                       │  │   Verification + Risk)      │  │
                       │  └──────────────┬──────────────┘  │
                       │                 │                 │
                       │  ┌──────────────┴──────────────┐  │
                       │  │     Platform Services       │  │
                       │  │  (Entities + Payments +     │  │
                       │  │   Multi-tenancy + Portals)  │  │
                       │  └─────────────────────────────┘  │
                       └───────────────────────────────────┘
```

### Entity Mapping Across Verticals

| Abstract Entity | Fintech | Property Mgmt | Lending | Marketplace |
|-----------------|---------|---------------|---------|-------------|
| Organization | Merchant | Property Manager | Lender | Seller |
| Location | Store | Unit | Branch | Storefront |
| Counterparty | Customer | Tenant | Borrower | Buyer |
| ServiceProvider | Vendor | Contractor | - | Supplier |
| Product | MID | Property | Loan Product | Listing |
| Transaction | Card Payment | Rent Collection | Loan Payment | Purchase |

---

## Domain Model Restructure

### Current State

```
Mcp.Underwriting
├── Application (subject_type: :merchant | :individual | :property)
├── Client, Check, Document, Activity, RiskAssessment
├── Pipeline, InstructionSet, AgentBlueprint
└── Atlas (merchant-focused AI)

Mcp.Platform
├── Tenant → Reseller → Merchant → Store
├── Developer, Customer, Vendor
└── (tightly coupled to fintech)
```

### Proposed Structure

```
Mcp.Platform.Verticals (NEW)
├── Vertical
│   │   Schema defining entity labels, features, portals per vertical
│   ├── :fintech (Merchant, MID, Store, Customer, Vendor)
│   ├── :property (PropertyManager, Property, Unit, Tenant, Contractor)
│   ├── :lending (Lender, LoanProduct, Borrower)
│   └── :underwriting_only (Organization, Applicant)
│
└── VerticalConfig
        Tenant-level overrides: labels, features, branding

Mcp.Platform (REFACTORED)
├── Tenant (has_one :vertical_config)
├── Organization (abstract base - replaces Merchant for non-fintech)
├── Location (abstract base - replaces Store for non-fintech)
├── Counterparty (abstract base - replaces Customer for non-fintech)
└── Fintech-specific: Merchant, MID, Store, Customer, Vendor (UNCHANGED)

Mcp.Ola (NEW DOMAIN - extracted from Underwriting)
├── ApplicationType
│       Schema-driven application definition
├── ApplicationInstance
│       Runtime: user's in-progress/submitted application
├── FormSchema
│       Steps, fields, validations, conditionals
├── Builder
│       CRUD for ApplicationType (visual + schema modes)
└── Renderer
        Dynamic UI generation from FormSchema

Mcp.Underwriting (REFACTORED)
├── Pipeline, Execution, Stage (unchanged)
├── Check, RiskAssessment, Activity (unchanged)
├── RoutingRules (NEW - connects ApplicationType → Pipeline(s))
└── AI layer → extracted to Mcp.Ai (shared)

Mcp.Ai (NEW DOMAIN - shared AI capabilities)
├── Assistant
│       Layered AI: base + domain + tenant
├── KnowledgeSource
│       RAG integration points
├── Persona
│       Configurable AI personalities
└── ConversationContext
        Moved from Atlas
```

---

## ApplicationType Schema

The `ApplicationType` is the heart of the OLA Builder - a declarative definition driving UI, validations, documents, routing, and AI.

### Core Schema

```elixir
defmodule Mcp.Ola.ApplicationType do
  use Ash.Resource,
    domain: Mcp.Ola,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Identity
    attribute :name, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :description, :string
    attribute :version, :string, default: "1.0"
    attribute :status, :atom, constraints: [one_of: [:draft, :published, :archived]]

    # Vertical association
    attribute :vertical, :atom, constraints: [
      one_of: [:fintech, :property, :lending, :underwriting_only]
    ]

    # Schema (JSONB)
    attribute :form_schema, :map, allow_nil?: false
    attribute :document_requirements, {:array, :map}, default: []
    attribute :routing_rules, {:array, :map}, default: []
    attribute :ai_config, :map, default: %{}
    attribute :branding, :map, default: %{}

    # Metadata
    attribute :is_template, :boolean, default: false
    attribute :parent_template_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant, allow_nil?: true  # nil = platform template
  end
end
```

### FormSchema Structure

```elixir
%{
  ux_mode: :wizard | :single_page | :conversational | :hybrid,

  steps: [
    %{
      id: "business_info",
      label: "Business Information",
      description: "Tell us about your business",
      icon: "building",
      conditions: %{show_when: nil},  # always show, or expression
      fields: [...]
    },
    %{
      id: "owners",
      label: "Ownership",
      repeatable: true,
      min: 1,
      max: 10,
      item_label: "Owner {{index}}",
      fields: [...]
    }
  ],

  settings: %{
    save_resume: true,
    save_interval_seconds: 30,
    show_progress: true,
    progress_style: :steps | :percentage | :checklist,
    allow_step_navigation: true,
    require_sequential: false
  }
}
```

### Field Definition

```elixir
%{
  id: "business_name",
  type: :text,
  label: "Legal Business Name",
  placeholder: "Acme Corporation LLC",
  required: true,
  help_text: "Enter the name exactly as it appears on your registration",
  ai_hint: "This is the legal entity name, not a DBA",

  validations: [
    %{type: :min_length, value: 2, message: "Name must be at least 2 characters"},
    %{type: :max_length, value: 100},
    %{type: :pattern, value: "^[a-zA-Z0-9\\s\\.\\,\\-]+$", message: "Invalid characters"}
  ],

  conditions: %{
    show_when: nil,  # always show
    require_when: "business_type != 'sole_proprietor'"
  },

  layout: %{
    width: :full | :half | :third,
    row_group: "business_details"
  }
}
```

### Supported Field Types

| Type | Description | Built-in Behavior |
|------|-------------|-------------------|
| `:text` | Single-line text | Standard validation |
| `:textarea` | Multi-line text | Character count |
| `:email` | Email address | Format validation |
| `:phone` | Phone number | Format + country code |
| `:date` | Date picker | Range validation |
| `:currency` | Money amount | Formatting, min/max |
| `:percentage` | Percentage value | 0-100 validation |
| `:select` | Dropdown | Options list |
| `:radio` | Radio buttons | Options list |
| `:checkbox` | Single checkbox | Boolean |
| `:checkboxes` | Multiple checkboxes | Multi-select |
| `:address` | Full address | Geocoding, validation |
| `:ssn` | Social Security Number | Masking, format validation |
| `:ein` | Employer ID Number | Masking, format validation |
| `:document` | File upload | Type restrictions, size limits |
| `:signature` | E-signature capture | Consent tracking |
| `:repeater` | Nested field group | Min/max items, item schema |
| `:calculated` | Computed value | Formula expression |
| `:hidden` | Hidden field | Passed through, not displayed |

### Document Requirements

```elixir
%{
  document_requirements: [
    %{
      id: "gov_id",
      type: :government_id,
      label: "Government-Issued ID",
      required: true,
      per: :owner,  # one per owner, or :application for one total
      accepted_types: [:passport, :drivers_license, :national_id],
      validations: [:not_expired, :photo_quality]
    },
    %{
      id: "bank_statements",
      type: :bank_statement,
      label: "Bank Statements",
      required: true,
      count: 3,
      period: :consecutive_months,
      validations: [:statement_complete, :matches_business_name]
    },
    %{
      id: "business_license",
      type: :business_license,
      label: "Business License",
      required: false,
      conditions: %{require_when: "requires_license == true"}
    }
  ]
}
```

### Routing Rules

```elixir
%{
  routing_rules: [
    %{
      id: "high_risk",
      priority: 1,
      condition: "risk_indicators.high_risk_industry == true",
      pipeline_id: "enhanced_due_diligence",
      reason: "High-risk industry requires enhanced review"
    },
    %{
      id: "high_value",
      priority: 2,
      condition: "annual_revenue > 1_000_000",
      pipeline_id: "high_value_merchant",
      reason: "High-value merchants get priority processing"
    },
    %{
      id: "expedited",
      priority: 3,
      condition: "expedited_requested == true && risk_score < 30",
      pipeline_id: "fast_track",
      reason: "Low-risk expedited applications"
    },
    %{
      id: "default",
      priority: 100,
      condition: :always,
      pipeline_id: "standard",
      reason: "Standard processing"
    }
  ]
}
```

### AI Configuration

```elixir
%{
  ai_config: %{
    # Persona
    persona: %{
      name: "Atlas",
      avatar: "/images/atlas-avatar.png",
      greeting: "Hi! I'm Atlas, your application assistant.",
      tone: :professional_friendly  # or :formal, :casual, :concise
    },

    # Knowledge sources (for RAG)
    knowledge_sources: [
      "merchant_faq",
      "compliance_requirements",
      "document_guidelines"
    ],

    # Behavior
    proactive_help: true,
    proactive_delay_seconds: 30,
    field_level_help: true,
    document_guidance: true,

    # Tenant additions (merged at runtime)
    tenant_knowledge_sources: [],  # populated from VerticalConfig
    custom_responses: %{}  # override specific intents
  }
}
```

### Branding Overrides

```elixir
%{
  branding: %{
    # Visual (nil = inherit from tenant)
    logo_url: nil,
    primary_color: nil,
    accent_color: nil,

    # Copy
    welcome_title: "Let's Get Started",
    welcome_message: "Complete your application in just a few minutes.",
    submit_button_text: "Submit Application",
    success_title: "Application Submitted!",
    success_message: "We'll review your application and get back to you within 24 hours.",

    # Legal
    terms_url: nil,
    privacy_url: nil,
    consent_text: "I agree to the Terms of Service and Privacy Policy"
  }
}
```

---

## OLA Builder Interface

### Three Modes

1. **Template Browser** (starting point)
   - Browse platform and tenant templates by vertical
   - Preview template before selecting
   - "Use this template" → creates copy for customization

2. **Visual Editor** (primary interface)
   - Drag-and-drop step reordering
   - Field palette with all field types
   - Click to configure: labels, validations, conditions
   - Live preview panel (desktop/mobile toggle)
   - Document requirements editor
   - AI persona configuration

3. **Schema Editor** (power user)
   - Full YAML/JSON schema view
   - Syntax highlighting and validation
   - Import/export for version control
   - Diff view for comparing versions

### Builder Components

```
┌─────────────────────────────────────────────────────────────────────┐
│  OLA Builder: Merchant Onboarding v2.1 [Draft]          [Publish ▾] │
├─────────────────────────────────────────────────────────────────────┤
│  [Structure] [Fields] [Documents] [Routing] [AI] [Branding]         │
├─────────┬───────────────────────────────────────┬───────────────────┤
│         │                                       │                   │
│  STEPS  │         STEP EDITOR                   │    PREVIEW        │
│         │                                       │                   │
│  ☰ Biz  │  Step: Business Information           │  ┌─────────────┐  │
│  ☰ Own  │                                       │  │  Welcome!   │  │
│  ☰ Doc  │  Fields:                              │  │             │  │
│  ☰ Rev  │  ┌─────────────────────────────────┐  │  │  Business   │  │
│         │  │ ⋮⋮ Legal Business Name    [text]│  │  │  Name: ___  │  │
│  + Add  │  │ ⋮⋮ DBA/Trade Name        [text]│  │  │             │  │
│         │  │ ⋮⋮ Business Type       [select]│  │  │  Type: ___  │  │
│         │  │ ⋮⋮ EIN                    [ein]│  │  │             │  │
│         │  │ + Add Field                     │  │  │  [Continue] │  │
│         │  └─────────────────────────────────┘  │  └─────────────┘  │
│         │                                       │  [Desktop][Mobile]│
└─────────┴───────────────────────────────────────┴───────────────────┘
```

---

## Vertical Configuration

### Vertical Resource

```elixir
defmodule Mcp.Platform.Vertical do
  @moduledoc """
  Platform-level vertical definitions.
  Defines entity labels, available features, and portal access.
  """

  @verticals %{
    fintech: %{
      name: "Fintech / Payments",
      description: "Merchant services, card processing, payment facilitation",
      entities: %{
        organization: "Merchant",
        location: "Store",
        counterparty: "Customer",
        service_provider: "Vendor",
        product: "MID"
      },
      portals: [:platform, :tenant, :reseller, :merchant, :developer, :customer],
      features: [
        :merchant_onboarding,
        :card_processing,
        :settlements,
        :disputes,
        :reporting,
        :developer_api
      ],
      default_application_types: ["merchant_onboarding", "developer_registration"]
    },

    property: %{
      name: "Property Management",
      description: "Tenant screening, rent collection, property management",
      entities: %{
        organization: "Property Manager",
        location: "Unit",
        counterparty: "Tenant",
        service_provider: "Contractor",
        product: "Property"
      },
      portals: [:platform, :tenant, :manager, :tenant_resident, :vendor],
      features: [
        :tenant_screening,
        :rent_collection,
        :maintenance_requests,
        :lease_management,
        :contractor_payments
      ],
      default_application_types: ["tenant_application", "manager_onboarding"]
    },

    lending: %{
      name: "Lending / Credit",
      description: "Loan origination, borrower underwriting, payment collection",
      entities: %{
        organization: "Lender",
        location: "Branch",
        counterparty: "Borrower",
        service_provider: nil,
        product: "Loan Product"
      },
      portals: [:platform, :tenant, :lender, :borrower],
      features: [
        :loan_origination,
        :credit_decisioning,
        :payment_scheduling,
        :collections,
        :reporting
      ],
      default_application_types: ["personal_loan", "business_loan", "mortgage"]
    },

    underwriting_only: %{
      name: "Underwriting Platform",
      description: "Pure underwriting/verification without payment features",
      entities: %{
        organization: "Organization",
        location: "Location",
        counterparty: "Applicant",
        service_provider: "Provider",
        product: "Account"
      },
      portals: [:platform, :tenant, :applicant],
      features: [
        :application_builder,
        :underwriting_pipelines,
        :document_verification,
        :risk_assessment,
        :api_access
      ],
      default_application_types: ["generic_application"]
    }
  }
end
```

### VerticalConfig Resource

```elixir
defmodule Mcp.Platform.VerticalConfig do
  @moduledoc """
  Tenant-level vertical configuration and overrides.
  """

  use Ash.Resource,
    domain: Mcp.Platform,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :vertical, :atom, allow_nil?: false

    # Label overrides (nil = use vertical defaults)
    attribute :entity_labels, :map, default: %{}

    # Feature toggles (subset of vertical's features)
    attribute :enabled_features, {:array, :atom}, default: []

    # Branding
    attribute :product_name, :string  # "PropScreen by Acme"
    attribute :branding, :map, default: %{}

    # AI customization
    attribute :ai_persona_overrides, :map, default: %{}
    attribute :knowledge_source_ids, {:array, :uuid}, default: []

    timestamps()
  end

  relationships do
    belongs_to :tenant, Mcp.Platform.Tenant, allow_nil?: false
  end
end
```

---

## Layered AI Architecture

### Layer Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI Response Generation                        │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ merge
┌─────────────────────────────────────────────────────────────────┐
│  TENANT LAYER (highest priority)                                 │
│  - Custom FAQs and responses                                     │
│  - Tenant-specific policies                                      │
│  - Brand voice overrides                                         │
│  - Tenant knowledge sources (RAG)                                │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ merge
┌─────────────────────────────────────────────────────────────────┐
│  APPLICATION TYPE LAYER                                          │
│  - Field-specific help text                                      │
│  - Document requirement explanations                             │
│  - Domain terminology (mortgage vs merchant)                     │
│  - Application type knowledge sources                            │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ merge
┌─────────────────────────────────────────────────────────────────┐
│  VERTICAL LAYER                                                  │
│  - Industry-specific knowledge                                   │
│  - Regulatory requirements (TILA for lending, PCI for fintech)  │
│  - Common questions per vertical                                 │
│  - Vertical knowledge sources                                    │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ merge
┌─────────────────────────────────────────────────────────────────┐
│  BASE LAYER (lowest priority)                                    │
│  - Universal form assistance                                     │
│  - Generic document upload help                                  │
│  - Common validation error explanations                          │
│  - Platform-wide knowledge sources                               │
└─────────────────────────────────────────────────────────────────┘
```

### AI Context Assembly

```elixir
defmodule Mcp.Ai.ContextBuilder do
  @moduledoc """
  Assembles layered AI context for a given application instance.
  """

  def build_context(application_instance) do
    app_type = application_instance.application_type
    tenant = application_instance.tenant
    vertical = app_type.vertical

    %{
      # Persona (cascading)
      persona: merge_personas([
        base_persona(),
        vertical_persona(vertical),
        app_type.ai_config[:persona],
        tenant.vertical_config.ai_persona_overrides
      ]),

      # Knowledge sources (accumulated)
      knowledge_sources: [
        platform_knowledge_sources(),
        vertical_knowledge_sources(vertical),
        app_type.ai_config[:knowledge_sources],
        tenant.vertical_config.knowledge_source_ids
      ] |> List.flatten() |> Enum.uniq(),

      # Current state
      current_step: application_instance.current_step,
      form_data: application_instance.data,
      validation_errors: application_instance.errors,

      # Privacy
      redacted_fields: [:ssn, :ein, :account_number, :routing_number]
    }
  end
end
```

---

## Dynamic UI Rendering

### Renderer Architecture

```
ApplicationType.form_schema
         │
         ▼
┌─────────────────────┐
│   SchemaParser      │  Parse and validate schema
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  ConditionEvaluator │  Evaluate show_when/require_when
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   ComponentMapper   │  Map field types to LiveView components
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   LayoutEngine      │  Arrange fields in rows/columns
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   LiveView Render   │  Generate dynamic HEEX
└─────────────────────┘
```

### Component Registry

```elixir
defmodule Mcp.Ola.Renderer.ComponentRegistry do
  @components %{
    text: McpWeb.Ola.Fields.TextField,
    textarea: McpWeb.Ola.Fields.TextareaField,
    email: McpWeb.Ola.Fields.EmailField,
    phone: McpWeb.Ola.Fields.PhoneField,
    date: McpWeb.Ola.Fields.DateField,
    currency: McpWeb.Ola.Fields.CurrencyField,
    percentage: McpWeb.Ola.Fields.PercentageField,
    select: McpWeb.Ola.Fields.SelectField,
    radio: McpWeb.Ola.Fields.RadioField,
    checkbox: McpWeb.Ola.Fields.CheckboxField,
    checkboxes: McpWeb.Ola.Fields.CheckboxesField,
    address: McpWeb.Ola.Fields.AddressField,
    ssn: McpWeb.Ola.Fields.SsnField,
    ein: McpWeb.Ola.Fields.EinField,
    document: McpWeb.Ola.Fields.DocumentField,
    signature: McpWeb.Ola.Fields.SignatureField,
    repeater: McpWeb.Ola.Fields.RepeaterField
  }

  def get_component(field_type), do: Map.get(@components, field_type)
end
```

---

## OLA ↔ Underwriting Integration

### Routing Flow

```
ApplicationInstance (submitted)
         │
         ▼
┌─────────────────────────┐
│   RoutingEngine         │
│   - Load routing_rules  │
│   - Evaluate conditions │
│   - Select pipeline(s)  │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│   Mcp.Underwriting      │
│   - Create Execution    │
│   - Run Pipeline stages │
│   - Vendor checks       │
│   - Risk assessment     │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│   Status Update         │
│   - PubSub broadcast    │
│   - Activity logging    │
│   - Webhook triggers    │
└─────────────────────────┘
```

### RoutingRule Resource

```elixir
defmodule Mcp.Ola.RoutingRule do
  use Ash.Resource,
    domain: Mcp.Ola,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :priority, :integer, allow_nil?: false
    attribute :condition, :string, allow_nil?: false  # Expression or :always
    attribute :reason, :string

    timestamps()
  end

  relationships do
    belongs_to :application_type, Mcp.Ola.ApplicationType, allow_nil?: false
    belongs_to :pipeline, Mcp.Underwriting.Pipeline, allow_nil?: false
  end
end
```

---

## Implementation Phases

### Phase 1: Foundation (Core Fintech)
**Focus**: Extract OLA domain, build schema-driven renderer, maintain current functionality

1. Create `Mcp.Ola` domain with `ApplicationType`, `ApplicationInstance`
2. Define `FormSchema` structure for current merchant application
3. Build dynamic renderer that generates current wizard from schema
4. Extract AI to `Mcp.Ai` with layered architecture (base only)
5. Migrate existing `/online-application` to use new renderer
6. **Validation**: Existing merchant onboarding works identically

### Phase 2: Builder MVP
**Focus**: Enable tenant customization of merchant application

1. Build OLA Builder UI (visual editor)
2. Template system (clone, modify, save)
3. Field configuration (labels, validations, conditions)
4. Document requirements editor
5. Preview mode (desktop/mobile)
6. **Validation**: Tenant can customize merchant application fields

### Phase 3: Multi-Pipeline Routing
**Focus**: Connect application types to multiple pipelines

1. Implement `RoutingRule` resource
2. Build routing rules editor in Builder
3. Condition expression evaluator
4. Multi-pipeline execution (parallel/sequential)
5. **Validation**: High-value merchants route to different pipeline

### Phase 4: Vertical Framework
**Focus**: Abstract entities, add property/lending verticals

1. Create `Vertical` and `VerticalConfig` resources
2. Implement entity label skinning
3. Portal access control per vertical
4. Feature toggle system
5. Create property vertical template
6. Create lending vertical template
7. **Validation**: New tenant can onboard as property management vertical

### Phase 5: Full Builder
**Focus**: Complete builder with schema export, versioning

1. Schema editor view (YAML/JSON)
2. Import/export functionality
3. Version history and rollback
4. Template marketplace (share between tenants)
5. API for programmatic application type management
6. **Validation**: Power user can build custom application from scratch

### Phase 6: AI Enhancement
**Focus**: Full layered AI with RAG

1. Vertical-specific knowledge sources
2. Tenant knowledge source management
3. Persona customization UI
4. RAG integration for dynamic responses
5. Proactive assistance tuning
6. **Validation**: Property AI knows rental regulations, fintech AI knows PCI

---

## File Structure (Proposed)

```
lib/mcp/
├── ola/                              # NEW DOMAIN
│   ├── application_type.ex
│   ├── application_instance.ex
│   ├── form_schema.ex
│   ├── routing_rule.ex
│   ├── builder/
│   │   ├── template_manager.ex
│   │   └── schema_validator.ex
│   └── renderer/
│       ├── component_registry.ex
│       ├── condition_evaluator.ex
│       └── layout_engine.ex
│
├── ai/                               # NEW DOMAIN (extracted)
│   ├── assistant.ex
│   ├── persona.ex
│   ├── knowledge_source.ex
│   ├── context_builder.ex
│   └── layers/
│       ├── base_layer.ex
│       ├── vertical_layer.ex
│       ├── application_type_layer.ex
│       └── tenant_layer.ex
│
├── platform/
│   ├── vertical.ex                   # NEW
│   ├── vertical_config.ex            # NEW
│   ├── tenant.ex                     # MODIFIED (add vertical_config)
│   └── ... (existing files)
│
└── underwriting/
    ├── ... (existing files)
    └── routing_engine.ex             # NEW

lib/mcp_web/
├── live/ola/
│   ├── application_live.ex           # REFACTORED (use renderer)
│   ├── builder_live.ex               # NEW
│   └── components/
│       ├── atlas_chat.ex             # MOVED to use Mcp.Ai
│       └── fields/                   # NEW (dynamic field components)
│           ├── text_field.ex
│           ├── ssn_field.ex
│           └── ...
```

---

## Migration Strategy

### Database Migrations

1. Create `application_types` table
2. Create `application_instances` table
3. Create `routing_rules` table
4. Create `verticals` table (or use embedded schema)
5. Create `vertical_configs` table
6. Add `vertical_config_id` to `tenants`
7. Migrate existing OLA data:
   - Create "Merchant Onboarding" ApplicationType from current hardcoded schema
   - Link existing Applications → ApplicationInstances

### Code Migration

1. Extract without breaking: new code paths with feature flags
2. Dual-write during transition
3. Gradually shift traffic to new renderer
4. Deprecate old paths once stable

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Tenant time to customize application | < 30 minutes |
| New vertical deployment | < 1 week (with templates) |
| Application completion rate | Maintain 85%+ |
| Builder usability score | > 4/5 |
| Schema-driven render parity | 100% feature match with current |

---

## Open Questions

1. **Expression language for conditions**: Use simple DSL, or existing solution like `filtrex`?
2. **Schema versioning**: How to handle in-flight applications when schema changes?
3. **Multi-language support**: Store translations in schema or separate i18n system?
4. **Offline/PWA**: Should mobile camera upload work offline?
5. **Audit trail**: How detailed should builder change tracking be?

---

## Next Steps

1. **Review this design** with stakeholders
2. **Create implementation plan** with detailed stories
3. **Prototype renderer** with current merchant schema
4. **Build field components** (start with existing types)
5. **Extract AI layer** to shared domain

---

## Appendix: Condition Expression Examples

```elixir
# Simple field check
"business_type == 'llc'"

# Numeric comparison
"annual_revenue > 1000000"

# Compound conditions
"business_type == 'llc' && state == 'CA'"

# Array membership
"industry in ['gambling', 'adult', 'crypto']"

# Nested field access
"owners[0].ownership_percentage >= 25"

# Function calls
"sum(owners.ownership_percentage) == 100"
"count(owners) >= 1"
"any(owners, ownership_percentage >= 25)"

# Risk score (calculated field)
"risk_score > 70"
```

---

**Document Author**: Claude (AI Assistant)
**Reviewed By**: [Pending]
**Approved By**: [Pending]
