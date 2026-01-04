# OLA ↔ Underwriting Platform Integration

**Last Updated**: January 2, 2026
**Integration Status**: ✅ FULLY INTEGRATED

---

## Overview

The OLA (Online Application) portal is **tightly integrated** with the Underwriting platform. OLA serves as the frontend user experience for merchant onboarding, while the Underwriting platform provides the backend screening, verification, and risk assessment capabilities.

**Integration Model**: Shared resources with clear ownership boundaries

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         OLA Portal (Frontend)                        │
│  User-facing application wizard with Atlas AI guidance              │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             │ Creates Application
                             │ Uploads Documents
                             │ Submits for Screening
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Underwriting Platform (Backend)                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ Application │  │   Client    │  │    Check    │  │  Activity   │ │
│  │  (Ash)      │  │   (Ash)     │  │   (Ash)     │  │   (Ash)     │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
│         │                 │                 │                 │       │
│         └─────────────────┴─────────────────┴─────────────────┘       │
│                             │                                         │
│                             ▼                                         │
│                      ┌─────────────┐                                  │
│                      │   Gateway   │                                  │
│                      │  (Screening)│                                  │
│                      └──────┬──────┘                                  │
│                             │                                         │
│         ┌───────────────────┼───────────────────┐                     │
│         ▼                   ▼                   ▼                     │
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────┐           │
│  │    KYB      │  │      KYC        │  │   Watchlist     │           │
│  │ (Business)  │  │   (Owners)      │  │   Screening     │           │
│  └─────────────┘  └─────────────────┘  └─────────────────┘           │
│         │                   │                   │                     │
│         └───────────────────┴───────────────────┘                     │
│                             │                                         │
│                             ▼                                         │
│                   ┌──────────────────┐                                │
│                   │ Risk Assessment  │                                │
│                   │  (ML-Powered)    │                                │
│                   └────────┬─────────┘                                │
│                            │                                          │
│                            ▼                                          │
│                   ┌──────────────────┐                                │
│                   │ Status Update    │                                │
│                   │ :approved        │                                │
│                   │ :rejected        │                                │
│                   │ :manual_review   │                                │
│                   └────────┬─────────┘                                │
└─────────────────────────────┼────────────────────────────────────────┘
                              │
                              │ PubSub Notification
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       OLA Status Tracker                             │
│  Real-time "Pizza Tracker" style status updates                     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Shared Resources

### 1. Application (Primary Resource)

**Owner**: OLA creates, Underwriting processes

**Ash Resource**: `Mcp.Underwriting.Application`

**Location**: `lib/mcp/underwriting/resources/application.ex`

**OLA Operations**:
```elixir
# Create application on form submission
{:ok, application} = UnderwritingApplication.create(
  %{
    subject_id: merchant.id,
    subject_type: :merchant,
    status: :submitted,
    application_data: form_params
  },
  tenant: tenant_schema
)

# Find existing application for resume
existing_application =
  UnderwritingApplication
  |> Ash.Query.filter(application_data["contact_email"] == ^email)
  |> Ash.read_one(tenant: tenant_schema)
```

**Underwriting Operations**:
```elixir
# Update status after screening
Ash.update!(application, %{
  status: :approved,  # or :rejected, :manual_review
  risk_score: 65
}, tenant: tenant)
```

**Attributes**:
- `id` (UUID) - Primary key
- `subject_id` (UUID) - Merchant ID
- `subject_type` (atom) - `:merchant`, `:individual`, `:business`
- `status` (atom) - `:draft`, `:submitted`, `:in_review`, `:approved`, `:rejected`
- `application_data` (map) - Form data from OLA
- `risk_score` (integer) - 0-100 score from risk assessment

**Lifecycle**:
1. OLA creates with `status: :submitted`
2. Underwriting Gateway updates to `:in_review`
3. Gateway updates to `:approved`, `:rejected`, or `:manual_review`
4. Status Tracker displays current state

### 2. Client (Owner Information)

**Owner**: OLA creates, Underwriting verifies

**Ash Resource**: `Mcp.Underwriting.Client`

**Location**: `lib/mcp/underwriting/resources/client.ex`

**OLA Operations**:
```elixir
# Implicitly created during application submission
# Extracted from application_data["owners"]
```

**Underwriting Operations**:
```elixir
# KYC verification creates client records
{:ok, client} = Client.create(%{
  type: :person,
  email: owner["email"],
  person_details: %{
    first_name: owner["first_name"],
    last_name: owner["last_name"],
    dob: owner["dob"],
    ssn: owner["ssn"]
  }
}, tenant: tenant)
```

**Attributes**:
- `type` (atom) - `:person`, `:company`
- `email` (string)
- `phone` (string)
- `person_details` (map) - Name, DOB, SSN, address
- `company_details` (map) - Business name, EIN, structure

**Relationship**:
- `belongs_to :application`

### 3. Document (File Storage)

**Owner**: OLA uploads, Underwriting validates

**Ash Resource**: `Mcp.Underwriting.Document`

**Location**: `lib/mcp/underwriting/resources/document.ex`

**OLA Operations**:
```elixir
# Upload to S3/MinIO
ExAws.S3.put_object(bucket, s3_path, File.read!(path)) |> ExAws.request!()

# Create document record
Document.create!(%{
  application_id: application.id,
  file_path: s3_path,
  file_name: filename,
  mime_type: mime_type,
  document_type: :government_id  # or :bank_statement, :business_license
}, tenant: tenant_schema)
```

**Underwriting Operations**:
```elixir
# Retrieve for validation
documents = Document.list_by_application(application_id, tenant: tenant)

# Update with validation results
Ash.update!(document, %{
  validation_status: :validated,
  extracted_data: structured_data
}, tenant: tenant)
```

**Attributes**:
- `file_path` (string) - S3 path
- `file_name` (string)
- `mime_type` (string)
- `document_type` (atom) - `:government_id`, `:bank_statement`, `:business_license`, `:other`
- `validation_status` (atom) - `:pending`, `:validated`, `:failed`
- `extracted_data` (map) - OCR results from TheEye

**Relationship**:
- `belongs_to :application`

### 4. Check (Verification Results)

**Owner**: Underwriting creates

**Ash Resource**: `Mcp.Underwriting.Check`

**Location**: `lib/mcp/underwriting/resources/check.ex`

**Underwriting Operations**:
```elixir
# Create check for KYC
{:ok, check} = Check.create(%{
  client_id: client.id,
  type: :identity,
  status: :complete,
  outcome: :clear,  # or :review, :alert, :fail
  external_id: vendor_check_id,
  raw_result: vendor_response
}, tenant: tenant)
```

**OLA Operations**:
```elixir
# Read-only access for displaying results
checks = Check.list_by_client(client_id, tenant: tenant)
```

**Attributes**:
- `type` (atom) - `:identity`, `:document`, `:aml`, `:pep`, `:sanctions`, `:watchlist`
- `status` (atom) - `:pending`, `:complete`, `:failed`
- `outcome` (atom) - `:clear`, `:review`, `:alert`, `:fail`
- `external_id` (string) - Vendor check ID
- `raw_result` (map) - Full vendor response

**Relationship**:
- `belongs_to :client`

### 5. Activity (Audit Log)

**Owner**: Both OLA and Underwriting log activities

**Ash Resource**: `Mcp.Underwriting.Activity`

**Location**: `lib/mcp/underwriting/resources/activity.ex`

**OLA Operations**:
```elixir
# Log application submission
Activity.create!(%{
  application_id: app.id,
  type: :status_change,
  metadata: %{"from" => "draft", "to" => "submitted"},
  actor_id: user_id
}, tenant: tenant)
```

**Underwriting Operations**:
```elixir
# Log KYC completion
Activity.create!(%{
  application_id: app.id,
  type: :kyc_completed,
  metadata: %{"owner_email" => email, "result" => "pass"},
  actor_id: system_user_id
}, tenant: tenant)
```

**Activity Types**:
- `:status_change` - Application status updated
- `:document_upload` - Document added
- `:kyc_initiated` - KYC check started
- `:kyc_completed` - KYC check finished
- `:kyc_success` / `:kyc_failure`
- `:watchlist_hit` / `:watchlist_clear`
- `:risk_calculated`
- `:decision_made`

**Attributes**:
- `type` (atom)
- `metadata` (map)
- `actor_id` (UUID) - User or system ID

**Relationship**:
- `belongs_to :application`

---

## Integration Points

### 1. Application Submission → Gateway Screening

**File**: `lib/mcp_web/live/ola/application_live.ex:198-201`

```elixir
# Async trigger of underwriting screening
Task.start(fn ->
  Gateway.screen_application(application.id, tenant: tenant.company_schema)
end)
```

**Gateway Flow**: `lib/mcp/underwriting/gateway.ex`

```elixir
def screen_application(application_id, opts \\ []) do
  tenant = Keyword.get(opts, :tenant)

  with {:ok, application} <- fetch_application(application_id, tenant),
       {:ok, _kyb} <- run_kyb_check(application, tenant),
       {:ok, _kyc_results} <- process_owner_kyc(application, tenant),
       {:ok, score} <- calculate_risk_score(application, tenant),
       {:ok, _} <- update_application_status(application, score, tenant) do
    {:ok, score}
  end
end
```

**What Happens**:
1. Fetch application from database
2. Run KYB check on business (EIN verification, business registration)
3. Run KYC checks on all owners (identity, address, SSN)
4. Screen against watchlists (AML, PEP, sanctions)
5. Calculate risk score using ML model
6. Update application status based on risk score

**Risk Score → Status Mapping**:
```elixir
defp update_application_status(application, score, tenant) do
  new_status = cond do
    score < 30 -> :approved        # Low risk
    score < 60 -> :manual_review   # Medium risk
    score >= 60 -> :rejected       # High risk
  end

  Ash.update!(application, %{status: new_status, risk_score: score}, tenant: tenant)
end
```

### 2. Document Upload → Validation

**OLA**: Uploads to S3, creates Document record

**File**: `lib/mcp_web/live/ola/application_live.ex:459-479`

```elixir
defp handle_upload_entry(%{path: path}, entry, application, tenant, bucket) do
  s3_path = "applications/#{application.id}/#{entry.client_name}"

  # Upload to S3
  ExAws.S3.put_object(bucket, s3_path, File.read!(path)) |> ExAws.request!()

  # Create document record
  Document.create!(%{
    application_id: application.id,
    file_path: s3_path,
    file_name: entry.client_name,
    mime_type: entry.client_type,
    document_type: :other
  }, tenant: tenant.company_schema)
end
```

**Underwriting**: Validates via TheEye

**File**: `lib/mcp/underwriting/services/document_validator.ex`

```elixir
def validate(file_content, filename, document_type) do
  case TheEye.analyze_document(file_content, filename) do
    {:ok, %{status: "success", markdown_content: content, structured_data: data}} ->
      validation = validate_extracted_content(content, document_type)
      add_extracted_data(validation, data)

    {:error, :service_unavailable} ->
      # Graceful degradation
      {:ok, %__MODULE__{valid?: true, quality_score: 50}}
  end
end
```

### 3. Status Updates → Real-Time Display

**PubSub Pattern**: Underwriting broadcasts, OLA subscribes

**Underwriting**: Broadcasts status changes

```elixir
# After updating application status
Phoenix.PubSub.broadcast(
  Mcp.PubSub,
  "application:#{application.id}",
  {:application_updated, application}
)
```

**OLA Status Tracker**: Subscribes to updates

**File**: `lib/mcp_web/live/ola/status_live.ex:19-20`

```elixir
if connected?(socket) do
  Phoenix.PubSub.subscribe(Mcp.PubSub, "application:#{app_id}")
end
```

**Handle Updates**:

```elixir
def handle_info({:application_updated, application}, socket) do
  {:noreply, assign(socket, :application, application)}
end
```

---

## Data Flow Examples

### Example 1: New Merchant Application

```
1. OLA: User fills out form
   └─> application_data = %{
         "business_name" => "Acme Corp",
         "ein" => "12-3456789",
         "owners" => [%{"email" => "john@acme.com", "ssn" => "123-45-6789"}]
       }

2. OLA: Creates Application
   └─> Application.create(%{
         subject_id: merchant.id,
         subject_type: :merchant,
         status: :submitted,
         application_data: application_data
       })
   └─> Application ID: "app-uuid-123"

3. OLA: Triggers Gateway
   └─> Task.start(fn -> Gateway.screen_application("app-uuid-123") end)

4. Underwriting Gateway: Processes
   ├─> Run KYB on "Acme Corp" with EIN "12-3456789"
   │   └─> Vendor: ComplyCube
   │   └─> Result: {:ok, %{status: "verified", risk: "low"}}
   │
   ├─> Run KYC on owner "john@acme.com"
   │   └─> Vendor: ComplyCube
   │   └─> Result: {:ok, %{status: "verified", risk: "low"}}
   │
   ├─> Run Watchlist screening
   │   └─> Result: {:ok, %{matches: []}}
   │
   └─> Calculate Risk Score
       └─> Score: 25 (low risk)

5. Underwriting: Updates Application
   └─> Application.update(%{status: :approved, risk_score: 25})

6. Underwriting: Broadcasts Update
   └─> PubSub.broadcast("application:app-uuid-123", {:application_updated, app})

7. OLA Status Tracker: Receives Update
   └─> Displays "Approved" status to user
```

### Example 2: Document Upload with Validation

```
1. OLA: User uploads driver's license
   └─> File: "drivers_license.jpg"

2. OLA: Uploads to S3
   └─> S3 Path: "applications/app-uuid-123/drivers_license.jpg"

3. OLA: Creates Document record
   └─> Document.create(%{
         application_id: "app-uuid-123",
         file_path: "applications/app-uuid-123/drivers_license.jpg",
         document_type: :government_id
       })

4. OLA: Triggers validation (optional, async)
   └─> DocumentValidator.validate(file_content, "drivers_license.jpg", :government_id)

5. Underwriting: TheEye OCR
   ├─> Extract: name, DOB, expiration
   └─> Result: %{
         "name" => "John Doe",
         "dob" => "1990-01-15",
         "expiration" => "2028-01-15"
       }

6. Underwriting: Validates content
   ├─> Check name present: ✓
   ├─> Check DOB present: ✓
   ├─> Check expiration present: ✓
   └─> Result: {:ok, %{valid?: true, quality_score: 100}}

7. OLA: Displays validation result
   └─> Green checkmark, "Document validated"
```

### Example 3: Save & Resume

```
1. OLA: User saves progress
   └─> Application status: :draft
   └─> Application data: Partially filled

2. OLA: Generates magic link
   └─> MagicLink.generate(app.id, user.email)
   └─> Token: "abc123xyz"
   └─> URL: "/online-application/resume/abc123xyz"

3. OLA: Sends email with resume link
   └─> User clicks link

4. OLA: Verifies token
   └─> MagicLink.verify("abc123xyz")
   └─> {:ok, %{application_id: "app-uuid-123", email: "user@example.com"}}

5. OLA: Fetches application
   └─> Application.get_by_id("app-uuid-123")
   └─> Loads application_data into form

6. OLA: User completes and submits
   └─> Status changes: :draft → :submitted
   └─> Triggers Gateway screening
```

---

## Multi-Tenancy

**All operations are tenant-scoped**:

```elixir
# OLA always passes tenant
tenant = Tenant.get_by_id!(tenant_id)
tenant_schema = tenant.company_schema  # e.g., "acq_uuid"

# Every Ash operation includes tenant
Application.create(params, tenant: tenant_schema)
Application.read!(tenant: tenant_schema)
Gateway.screen_application(app_id, tenant: tenant_schema)
```

**Schema Isolation**:
- Each tenant has its own PostgreSQL schema
- Data is fully isolated at the database level
- No cross-tenant queries possible

**Example**:
```sql
-- Tenant A: acq_abc123
SET search_path = acq_abc123;
SELECT * FROM applications;  -- Only sees Tenant A data

-- Tenant B: acq_xyz789
SET search_path = acq_xyz789;
SELECT * FROM applications;  -- Only sees Tenant B data
```

---

## Error Handling

### Gateway Errors

**Vendor Failures**:
```elixir
# Gateway automatically fails over to secondary vendor
case VendorRouter.select_adapter() do
  ComplyCube ->
    case ComplyCube.verify_identity(person, context) do
      {:error, _} ->
        # Circuit breaker opens, fallback to Idenfy
        Idenfy.verify_identity(person, context)
    end
end
```

**Rate Limiting**:
```elixir
case RateLimiter.check_limit("tenant:#{tenant_id}", 100) do
  :ok -> execute_screening()
  {:error, :rate_limit_exceeded} ->
    {:error, "Too many requests, try again in 1 minute"}
end
```

### OLA Errors

**Document Upload Failures**:
```elixir
# OLA shows user-friendly error
case ExAws.S3.put_object(bucket, path, content) |> ExAws.request() do
  {:ok, _} -> :ok
  {:error, _} ->
    put_flash(socket, :error, "Upload failed. Please try again.")
end
```

**Gateway Timeout**:
```elixir
# Gateway runs async, doesn't block submission
Task.start(fn ->
  case Gateway.screen_application(app_id, tenant: tenant) do
    {:ok, _} -> :ok
    {:error, reason} ->
      # Log error, set status to :manual_review
      Logger.error("Screening failed: #{inspect(reason)}")
      Application.update!(app, %{status: :manual_review}, tenant: tenant)
  end
end)
```

---

## Testing Integration

### Unit Tests

**OLA Tests**:
```elixir
test "creates application with form data", %{tenant: tenant} do
  params = %{
    subject_id: merchant.id,
    subject_type: :merchant,
    application_data: %{"business_name" => "Test Corp"}
  }

  {:ok, app} = Application.create(params, tenant: tenant)
  assert app.status == :submitted
end
```

**Underwriting Tests**:
```elixir
test "screens application successfully", %{tenant: tenant} do
  app = create_application(tenant)
  assert {:ok, score} = Gateway.screen_application(app.id, tenant: tenant)
  assert score >= 0 and score <= 100
end
```

### Integration Tests

**End-to-End Flow**:
```elixir
test "complete application flow", %{conn: conn, tenant: tenant} do
  # 1. Submit application via OLA
  {:ok, view, _html} = live(conn, "/online-application/application")

  view
  |> form("#application-form", application: @valid_attrs)
  |> render_submit()

  # 2. Verify application created
  app = Application |> Ash.Query.sort(inserted_at: :desc) |> Ash.read_one!(tenant: tenant)
  assert app.status == :submitted

  # 3. Wait for Gateway screening
  :timer.sleep(1000)

  # 4. Verify status updated
  app = Application.get_by_id!(app.id, tenant: tenant)
  assert app.status in [:approved, :rejected, :manual_review]
end
```

---

## Monitoring & Observability

### Key Metrics

**OLA Metrics**:
- Application submission rate
- Document upload success rate
- Atlas interaction rate
- Form abandonment rate

**Underwriting Metrics**:
- Gateway screening duration
- Vendor API success rate
- Risk score distribution
- Auto-approval rate

### Telemetry Events

**OLA Events**:
```elixir
:telemetry.execute(
  [:ola, :application, :submitted],
  %{count: 1},
  %{tenant_id: tenant_id, merchant_id: merchant_id}
)
```

**Underwriting Events**:
```elixir
:telemetry.execute(
  [:underwriting, :screening, :complete],
  %{duration: duration_ms, risk_score: score},
  %{application_id: app_id, vendor: :complycube}
)
```

---

## Deployment Considerations

### Database Migrations

**Shared Schema Changes**: Require coordination

Example: Adding a new field to `Application`
1. Underwriting adds migration
2. OLA updates to use new field
3. Deploy in order: Underwriting → OLA

### Feature Flags

**Gradual Rollout**:
```elixir
if FeatureFlag.enabled?(:live_atlas, tenant_id) do
  Atlas.Agent.live_generate_response(message, context)
else
  Atlas.Agent.mock_generate_response(message, context)
end
```

### Configuration

**Environment Variables**:
- Both OLA and Underwriting read same vendor API keys
- Both use same S3 bucket for documents
- Both use same PubSub for real-time updates

---

## Security & Compliance

### Data Access

**OLA**:
- Creates applications, documents
- Reads application status
- **Cannot** modify verification results or risk scores

**Underwriting**:
- Creates checks, activities
- Updates application status and risk scores
- Reads documents for validation

### Audit Trail

**Complete Traceability**:
```elixir
# Every action logged in Activity
activities = Activity
  |> Ash.Query.filter(application_id == ^app_id)
  |> Ash.Query.sort(inserted_at: :desc)
  |> Ash.read!(tenant: tenant)

# Example output
[
  %{type: :decision_made, metadata: %{"decision" => "approved"}, inserted_at: ~U[2026-01-02 10:05:00Z]},
  %{type: :risk_calculated, metadata: %{"score" => 25}, inserted_at: ~U[2026-01-02 10:04:58Z]},
  %{type: :kyc_completed, metadata: %{"owner_email" => "john@acme.com"}, inserted_at: ~U[2026-01-02 10:04:50Z]},
  %{type: :status_change, metadata: %{"from" => "submitted", "to" => "in_review"}, inserted_at: ~U[2026-01-02 10:04:45Z]},
  %{type: :document_upload, metadata: %{"file_name" => "license.jpg"}, inserted_at: ~U[2026-01-02 10:03:30Z]}
]
```

---

## Conclusion

The OLA and Underwriting platforms are **fully integrated** with clear ownership boundaries:

- **OLA**: User experience, data collection, status display
- **Underwriting**: Verification, risk assessment, decisioning

**Integration is**:
- ✅ Bidirectional (OLA creates, Underwriting processes, OLA displays)
- ✅ Real-time (PubSub for status updates)
- ✅ Asynchronous (screening doesn't block submission)
- ✅ Multi-tenant (all operations tenant-scoped)
- ✅ Auditable (complete activity trail)
- ✅ Resilient (circuit breakers, graceful degradation)

**Next Steps**:
1. Review integration points for optimization opportunities
2. Add more comprehensive integration tests
3. Implement monitoring dashboards
4. Document vendor-specific integration details
