# API Reference: Underwriting Engine

## REST API Endpoints

### Assessments

#### Create Assessment

Triggers a new underwriting assessment execution.

```
POST /api/assessments
```

**Headers**:
```
X-API-Key: {api_key}
Accept: application/vnd.mcp.v1+json
Content-Type: application/json
```

**Request Body**:
```json
{
  "pipeline_id": "550e8400-e29b-41d4-a716-446655440000",
  "subject_id": "550e8400-e29b-41d4-a716-446655440001",
  "subject_type": "individual",
  "context": {
    "annual_income": 75000,
    "debt": 15000,
    "property_value": 350000
  }
}
```

**Response** (201 Created):
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "status": "pending",
    "pipeline_id": "550e8400-e29b-41d4-a716-446655440000",
    "subject_id": "550e8400-e29b-41d4-a716-446655440001",
    "subject_type": "individual",
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

**Error Response** (422 Unprocessable Entity):
```json
{
  "error": {
    "code": "invalid_request",
    "message": "Invalid request parameters",
    "details": [
      {"field": "pipeline_id", "message": "is required"}
    ]
  }
}
```

#### Get Assessment

Retrieves an assessment with its results.

```
GET /api/assessments/{id}
```

**Response** (200 OK):
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "status": "completed",
    "results": {
      "FinancialAnalyst": {
        "decision": "approve",
        "dti": 0.20,
        "confidence": 0.95
      }
    },
    "created_at": "2024-01-15T10:30:00Z",
    "completed_at": "2024-01-15T10:30:05Z"
  }
}
```

### Instruction Sets

#### Create Instruction Set

Creates a new instruction set for an agent blueprint.

```
POST /api/instruction_sets
```

**Request Body**:
```json
{
  "name": "Conservative Mortgage Policy",
  "instructions": "Reject if DTI > 0.43. Require manual review if LTV > 0.80.",
  "blueprint_id": "550e8400-e29b-41d4-a716-446655440003"
}
```

**Response** (201 Created):
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440004",
    "name": "Conservative Mortgage Policy",
    "instructions": "Reject if DTI > 0.43. Require manual review if LTV > 0.80.",
    "blueprint_id": "550e8400-e29b-41d4-a716-446655440003"
  }
}
```

## Ash Resources

### Application

The main underwriting application resource.

```elixir
defmodule Mcp.Underwriting.Application do
  use Ash.Resource

  attributes do
    uuid_primary_key :id

    attribute :subject_id, :uuid, allow_nil?: false
    attribute :subject_type, :atom,
      constraints: [one_of: [:individual, :merchant, :business]]

    attribute :status, :atom,
      constraints: [one_of: [:draft, :submitted, :in_review, :approved, :rejected]]
      default: :draft

    attribute :application_data, :map
    attribute :risk_score, :integer, default: 0

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:subject_id, :subject_type, :application_data, :status]
    end

    update :update do
      accept [:status, :risk_score, :application_data]
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
    end
  end

  code_interface do
    define :create
    define :get_by_id, args: [:id]
  end
end
```

### Client

KYC subject (person or company).

```elixir
defmodule Mcp.Underwriting.Client do
  attributes do
    uuid_primary_key :id

    attribute :type, :atom,
      constraints: [one_of: [:person, :company]]

    attribute :email, :string
    attribute :phone, :string
    attribute :external_id, :string
    attribute :person_details, :map
    attribute :company_details, :map
  end

  actions do
    read :read_by_email do
      argument :email, :string, allow_nil?: false
      get? true
      filter expr(email == ^arg(:email))
    end

    read :list_by_application do
      argument :application_id, :uuid, allow_nil?: false
      filter expr(application_id == ^arg(:application_id))
    end
  end

  code_interface do
    define :get_by_email, args: [:email], action: :read_by_email
    define :list_by_application, args: [:application_id]
  end
end
```

### Check

Verification check results.

```elixir
defmodule Mcp.Underwriting.Check do
  attributes do
    uuid_primary_key :id

    attribute :type, :atom,
      constraints: [one_of: [:identity, :document, :aml, :pep, :sanctions, :watchlist]]

    attribute :status, :atom,
      constraints: [one_of: [:pending, :complete, :failed]]

    attribute :outcome, :atom,
      constraints: [one_of: [:clear, :review, :alert, :fail]]

    attribute :external_id, :string
    attribute :raw_result, :map
  end

  actions do
    read :list_by_client do
      argument :client_id, :uuid, allow_nil?: false
      filter expr(client_id == ^arg(:client_id))
    end

    read :get_latest_by_type do
      argument :client_id, :uuid, allow_nil?: false
      argument :type, :atom, allow_nil?: false
      get? true
      filter expr(client_id == ^arg(:client_id) and type == ^arg(:type))
      prepare build(sort: [inserted_at: :desc], limit: 1)
    end
  end

  code_interface do
    define :list_by_client, args: [:client_id]
    define :get_latest_by_type, args: [:client_id, :type]
  end
end
```

### RiskAssessment

Risk scoring results.

```elixir
defmodule Mcp.Underwriting.RiskAssessment do
  attributes do
    uuid_primary_key :id

    attribute :score, :integer
    attribute :factors, :map
    attribute :recommendation, :atom,
      constraints: [one_of: [:approve, :reject, :manual_review]]
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application
  end
end
```

### Activity

Audit trail for compliance.

```elixir
defmodule Mcp.Underwriting.Activity do
  attributes do
    uuid_primary_key :id

    attribute :type, :atom,
      constraints: [one_of: [
        :status_change,
        :document_upload,
        :kyc_initiated,
        :kyc_completed,
        :kyc_success,
        :kyc_failure,
        :watchlist_hit,
        :watchlist_clear,
        :risk_calculated,
        :review_requested,
        :decision_made
      ]]

    attribute :metadata, :map
    attribute :actor_id, :uuid
  end

  relationships do
    belongs_to :application, Mcp.Underwriting.Application
  end
end
```

## Gateway Functions

### screen_application/2

Performs full KYC/KYB screening on an application.

```elixir
@spec screen_application(Ecto.UUID.t(), keyword()) ::
  {:ok, integer()} | {:error, term()}

Gateway.screen_application(application_id, tenant: tenant_schema)
```

**Options**:
- `:tenant` - Required. The tenant schema name.

**Returns**:
- `{:ok, risk_score}` - Success with calculated risk score (0-100)
- `{:error, {:kyc_failed, email, reason}}` - KYC verification failed
- `{:error, {:kyb_failed, reason}}` - KYB verification failed
- `{:error, :not_found}` - Application not found

### calculate_risk_score/2

Calculates risk score based on verification results.

```elixir
@spec calculate_risk_score(Application.t(), String.t()) ::
  {:ok, integer()} | {:error, term()}

Gateway.calculate_risk_score(application, tenant)
```

## Adapter Interface

All vendor adapters implement the `Mcp.Underwriting.Adapter` behaviour:

```elixir
@callback verify_identity(person :: map(), context :: map()) ::
  {:ok, result :: map()} | {:error, reason :: term()}

@callback verify_business(business :: map(), context :: map()) ::
  {:ok, result :: map()} | {:error, reason :: term()}

@callback check_watchlist(name :: String.t(), context :: map()) ::
  {:ok, result :: map()} | {:error, reason :: term()}
```

### verify_identity/2

Performs KYC identity verification.

**Input**:
```elixir
%{
  "first_name" => "John",
  "last_name" => "Doe",
  "email" => "john@example.com",
  "date_of_birth" => "1990-01-15",
  "address" => %{
    "line1" => "123 Main St",
    "city" => "New York",
    "state" => "NY",
    "postal_code" => "10001",
    "country" => "US"
  }
}
```

**Output**:
```elixir
{:ok, %{
  "provider" => "comply_cube",
  "check_id" => "chk_xxx",
  "status" => "complete",
  "outcome" => "clear",
  "score" => 95
}}
```

### verify_business/2

Performs KYB business verification.

**Input**:
```elixir
%{
  "legal_name" => "Acme Corporation",
  "business_type" => "llc",
  "ein" => "12-3456789",
  "address" => %{...}
}
```

### check_watchlist/2

Screens against AML/PEP/Sanctions watchlists.

**Input**:
```elixir
check_watchlist("John Doe", %{client_id: client_id})
```

**Output**:
```elixir
{:ok, %{
  "provider" => "comply_cube",
  "status" => "clear",
  "matches" => [],
  "risk_level" => "low"
}}
```

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `invalid_request` | 422 | Invalid request parameters |
| `not_found` | 404 | Resource not found |
| `tenant_required` | 400 | Tenant context not provided |
| `kyc_failed` | 422 | KYC verification failed |
| `kyb_failed` | 422 | KYB verification failed |
| `rate_limit_exceeded` | 429 | Too many requests |
| `circuit_open` | 503 | Vendor service unavailable |
| `internal_server_error` | 500 | Unexpected error |

## Authentication

All API endpoints require authentication via API key:

```
X-API-Key: {api_key}
```

The API key must have the appropriate scopes:
- `assessments:write` - Create assessments
- `assessments:read` - Read assessments
- `instruction_sets:write` - Create instruction sets

API keys are tenant-scoped; operations are automatically isolated to the
owning tenant.
