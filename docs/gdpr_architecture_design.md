# GDPR Compliance Architecture Design for User Soft Delete & Retention

## Executive Summary

This document outlines a comprehensive GDPR compliance architecture for implementing user soft deletion and data retention in the MCP platform. The design ensures compliance with GDPR requirements including the "right to be forgotten," data retention policies, and comprehensive audit trails.

## Current System Analysis

### Existing Infrastructure
- **Platform**: Phoenix/Elixir with Ash Framework
- **Database**: PostgreSQL with advanced extensions (TimescaleDB, PostGIS, pgvector)
- **Authentication**: AshAuthentication with JWT tokens
- **Multi-tenancy**: Schema-based isolation with platform/tenant separation
- **Audit System**: Basic audit_logs table exists in platform schema

### Current User Model Structure
- **Users Table**: Primary authentication data in platform.users
- **User Profiles**: Extended profile data in platform.user_profiles
- **Status Fields**: Currently supports `active`, `suspended`, `deleted`
- **Authentication**: Email/password with TOTP, OAuth support
- **Session Tracking**: Last sign-in data, IP tracking, sign-in count

## GDPR Compliance Framework Design

### 1. Data Classification Strategy

#### Personal Data Categories
| Category | Definition | Examples | Retention Period |
|----------|------------|----------|------------------|
| **Core Identity** | Direct identifiers | Email, name, phone | 90 days post-deletion, then anonymize |
| **Authentication Data** | Login credentials | Passwords, TOTP secrets, OAuth tokens | Immediate deletion on account deletion |
| **Activity Data** | User actions | Sign-ins, API calls, audit logs | 90 days post-deletion, then anonymize |
| **Communication Data** | Messages/notifications | Email history, SMS logs | 90 days post-deletion, then delete |
| **Behavioral Data** | Usage patterns | Preferences, settings, analytics | 90 days post-deletion, then anonymize |
| **Derived Data** | Processed information | Generated reports, insights | 90 days post-deletion, then delete |

#### Data Sensitivity Levels
- **Level 1 (High)**: Direct identifiers, authentication secrets
- **Level 2 (Medium)**: Activity logs, communication records
- **Level 3 (Low)**: Aggregated analytics, anonymized data

### 2. Lawful Basis for Processing

#### Primary Legal Bases
1. **Contractual Necessity**: Service provision for active users
2. **Legal Obligation**: Compliance with financial/tax regulations (7 years)
3. **Legitimate Interest**: Security, fraud prevention, service improvement
4. **Consent**: Marketing communications, analytics tracking

#### Consent Management
- Granular consent checkboxes during registration
- Consent revocation capabilities
- Consent audit trail
- Age verification (13+ requirement)

### 3. Data Subject Rights Implementation

#### Access Rights (GDPR Art. 15)
- Self-service data export portal
- Comprehensive data inventory report
- Machine-readable export format (JSON/CSV)

#### Rectification Rights (GDPR Art. 16)
- Direct profile editing capabilities
- Data correction audit trail
- Third-party data source attribution

#### Erasure Rights (GDPR Art. 17) - "Right to be Forgotten"
- Immediate soft deletion on request
- 90-day retention for operational needs
- Complete anonymization after retention period
- Emergency immediate deletion capability

#### Portability Rights (GDPR Art. 20)
- Structured data export (machine-readable)
- Direct data transfer to third parties
- Format standards compliance (JSON Schema)

## Soft Delete Architecture Design

### 1. User Lifecycle States

```
[active] → [deletion_requested] → [deleted] → [retention_period] → [anonymized] → [purged]
    ↑              ↓                   ↓              ↓                 ↓
  restore    cancel_deletion    90-day timer   anonymization    final cleanup
```

#### State Definitions
- **active**: Normal user with full system access
- **deletion_requested**: User initiated deletion, grace period active
- **deleted**: Soft deleted, authentication blocked, retention timer started
- **anonymized**: Personal data replaced with pseudonyms
- **purged**: Complete removal from system (exceptional circumstances)

### 2. Enhanced User Schema Design

#### Core Users Table Modifications
```sql
-- Additional fields for platform.users
ALTER TABLE platform.users ADD COLUMN gdpr_deletion_requested_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE platform.users ADD COLUMN gdpr_deletion_reason TEXT;
ALTER TABLE platform.users ADD COLUMN gdpr_retention_expires_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE platform.users ADD COLUMN gdpr_anonymized_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE platform.users ADD COLUMN gdpr_data_export_token UUID;
ALTER TABLE platform.users ADD COLUMN gdpr_consent_record JSONB DEFAULT '{}';

-- Update status constraint
ALTER TABLE platform.users DROP CONSTRAINT users_status_check;
ALTER TABLE platform.users
ADD CONSTRAINT users_status_check
CHECK (status IN ('active', 'suspended', 'deletion_requested', 'deleted', 'anonymized', 'purged'));
```

#### Enhanced Audit Trail System
```sql
-- GDPR-specific audit table
CREATE TABLE platform.gdpr_audit_trail (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES platform.users(id),
    action_type TEXT NOT NULL, -- 'access_request', 'export', 'delete_request', 'anonymize'
    actor_type TEXT, -- 'user', 'system', 'admin'
    actor_id UUID,
    ip_address INET,
    user_agent TEXT,
    request_id TEXT,
    data_categories JSONB, -- What data was affected
    legal_basis TEXT, -- Legal basis for action
    details JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Data retention tracking
CREATE TABLE platform.data_retention_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES platform.users(id),
    data_category TEXT NOT NULL,
    retention_days INTEGER NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'scheduled', -- 'scheduled', 'processed', 'failed'
    processing_started_at TIMESTAMP WITH TIME ZONE,
    processing_completed_at TIMESTAMP WITH TIME ZONE,
    error_details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 3. Data Anonymization Strategies

#### Anonymization Techniques by Data Type

##### Core Identity Data
```sql
-- Email anonymization
UPDATE platform.users
SET email = CONCAT('deleted-', SUBSTRING(MD5(id::TEXT), 1, 8), '@deleted.local')
WHERE status = 'anonymized';

-- Name anonymization
UPDATE platform.user_profiles
SET first_name = 'Deleted', last_name = 'User'
WHERE user_id IN (SELECT id FROM platform.users WHERE status = 'anonymized');
```

##### Activity Data Preservation
```sql
-- Preserve essential audit data with user anonymization
UPDATE platform.audit_logs
SET actor_id = NULL,
    actor_type = 'anonymized_user',
    changes = jsonb_set(changes, '{user_id}', to_jsonb(NULL))
WHERE actor_id IN (SELECT id FROM platform.users WHERE status = 'anonymized');
```

##### Communication Data Handling
```sql
-- Email communications - remove content, keep metadata
UPDATE communication_logs
SET content = '[Content removed due to GDPR deletion]',
     attachments = '{}'
WHERE user_id IN (SELECT id FROM platform.users WHERE status = 'anonymized');
```

## Implementation Architecture

### 1. Module Structure

```
lib/mcp/
├── gdpr/
│   ├── application.ex              # GDPR supervisor
│   ├── consent_manager.ex          # Consent tracking
│   ├── data_subject_requests.ex    # DSAR processing
│   ├── retention_scheduler.ex      # Background jobs
│   ├── anonymization_engine.ex     # Data anonymization
│   ├── export_generator.ex         # Data export functionality
│   └── compliance_reporter.ex      # Compliance reporting
├── accounts/
│   ├── gdpr_user_actions.ex        # GDPR-specific user actions
│   └── deletion_workflow.ex        # Soft delete implementation
└── audit/
    └── gdpr_audit_logger.ex        # GDPR-specific audit logging
```

### 2. Key Processes

#### Deletion Request Workflow
```elixir
defmodule Mcp.Gdpr.DeletionWorkflow do
  def initiate_deletion(user_id, reason \\ "user_request") do
    Multi.new()
    |> Multi.update(:user, User.deletion_request_changeset(user_id))
    |> Multi.insert(:audit, gdpr_audit_changeset(user_id, "delete_request"))
    |> Multi.insert(:retention, retention_schedule_changeset(user_id))
    |> Multi.run(:revoke_tokens, &revoke_all_tokens/2)
    |> Multi.run(:send_confirmation, &send_deletion_confirmation/2)
    |> Repo.transaction()
  end

  def finalize_deletion(user_id) do
    # 90 days after request
    Multi.new()
    |> Multi.update(:user, User.anonymize_changeset(user_id))
    |> Multi.run(:anonymize_data, &AnonymizationEngine.anonymize_user_data/2)
    |> Multi.insert(:audit, gdpr_audit_changeset(user_id, "anonymization_complete"))
    |> Repo.transaction()
  end
end
```

#### Data Export Process
```elixir
defmodule Mcp.Gdpr.ExportGenerator do
  def generate_user_export(user_id, format \\ "json") do
    user_data = collect_all_user_data(user_id)

    case format do
      "json" -> generate_json_export(user_data)
      "csv" -> generate_csv_export(user_data)
      "pdf" -> generate_pdf_report(user_data)
    end
  end

  defp collect_all_user_data(user_id) do
    %{
      user_identity: get_user_identity(user_id),
      authentication_data: get_auth_data(user_id),
      activity_logs: get_activity_logs(user_id),
      communication_history: get_communications(user_id),
      preferences: get_user_preferences(user_id),
      consents: get_consent_record(user_id)
    }
  end
end
```

### 3. Background Job Scheduling

#### Retention Processing Jobs
```elixir
defmodule Mcp.Gdpr.RetentionScheduler do
  use Oban.Worker, queue: :gdpr_retention

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    case should_anonymize_user?(user_id) do
      true ->
        DeletionWorkflow.finalize_deletion(user_id)
        :ok
      false ->
        schedule_next_check(user_id)
        :ok
    end
  end

  defp should_anonymize_user?(user_id) do
    user = Repo.get(User, user_id)
    user.status == "deleted" &&
      DateTime.compare(user.gdpr_retention_expires_at, DateTime.utc_now()) == :lt
  end
end
```

## Integration Points

### 1. Authentication System Integration

#### JWT Token Management
```elixir
# Immediate token revocation on deletion request
defmodule Mcp.Accounts.TokenManager do
  def revoke_user_tokens(user_id) do
    from(t in Token, where: t.user_id == ^user_id)
    |> Repo.update_all(set: [revoked_at: DateTime.utc_now()])
  end

  def validate_token_for_deleted_user(token) do
    case Repo.get_by(Token, token: token) do
      %{user: %{status: status}} when status in ["deleted", "anonymized"] ->
        {:error, :account_deleted}
      token ->
        {:ok, token}
    end
  end
end
```

#### OAuth Provider Integration
```elixir
defmodule Mcp.Accounts.OAuthManager do
  def disconnect_oauth_providers(user_id) do
    user = Repo.get(User, user_id)

    Enum.each(user.oauth_tokens, fn {provider, _token_data} ->
      case provider do
        "google" -> Google.revoke_access(user_id)
        "github" -> GitHub.revoke_access(user_id)
        "microsoft" -> Microsoft.revoke_access(user_id)
      end
    end)

    User.changeset(user)
    |> Ecto.Changeset.put_change(:oauth_tokens, %{})
    |> Repo.update()
  end
end
```

### 2. Communication System Integration

#### Email/Notification Suppression
```elixir
defmodule Mcp.Communication.GdprFilter do
  def should_send_communication?(user_id, communication_type) do
    user = Repo.get(User, user_id)

    cond do
      user.status in ["deleted", "anonymized"] -> false
      user.status == "deletion_requested" and communication_type != "legal" -> false
      true -> true
    end
  end
end
```

### 3. API Layer Integration

#### GDPR-Specific Endpoints
```elixir
defmodule McpWeb.GdprController do
  use McpWeb, :controller

  def request_data_export(conn, _params) do
    user_id = conn.assigns.current_user.id

    case DataSubjectRequests.create_export_request(user_id) do
      {:ok, request} ->
        render(conn, :export_requested, request: request)
      {:error, reason} ->
        render(conn, :error, error: reason)
    end
  end

  def request_account_deletion(conn, %{"reason" => reason}) do
    user_id = conn.assigns.current_user.id

    case DeletionWorkflow.initiate_deletion(user_id, reason) do
      {:ok, result} ->
        render(conn, :deletion_initiated, result: result)
      {:error, reason} ->
        render(conn, :error, error: reason)
    end
  end

  def cancel_deletion_request(conn, _params) do
    user_id = conn.assigns.current_user.id

    case DeletionWorkflow.cancel_deletion(user_id) do
      {:ok, user} ->
        render(conn, :deletion_cancelled, user: user)
      {:error, reason} ->
        render(conn, :error, error: reason)
    end
  end
end
```

## Compliance and Monitoring

### 1. Compliance Metrics

#### Key Performance Indicators
- **Deletion Request Processing Time**: < 24 hours
- **Data Export Generation Time**: < 48 hours
- **Anonymization Completion Rate**: 100% within 90 days
- **Audit Trail Completeness**: 100% coverage
- **Consent Record Accuracy**: 100% traceability

### 2. Monitoring and Alerting

#### Critical Alerts
```elixir
defmodule Mcp.Gdpr.ComplianceMonitor do
  def check_retention_compliance do
    overdue_users =
      from(u in User,
        where: u.status == "deleted" and
               u.gdpr_retention_expires_at < ^DateTime.utc_now())
      |> Repo.all()

    if length(overdue_users) > 0 do
      AlertManager.send_critical_alert(
        "GDPR Retention Compliance: #{length(overdue_users)} users overdue for anonymization"
      )
    end
  end

  def check_audit_integrity do
    # Verify no gaps in audit trail
    # Check for missing consent records
    # Validate data export logs
  end
end
```

### 3. Reporting Dashboard

#### Compliance Reports
- Monthly deletion request summary
- Data export activity report
- Retention processing status
- Consent management overview
- Audit trail integrity report

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [ ] Database schema updates (GDPR fields, audit tables)
- [ ] Basic consent management system
- [ ] Soft delete status implementation
- [ ] Core GDPR module structure

### Phase 2: Core Functionality (Weeks 3-4)
- [ ] Data export functionality
- [ ] Anonymization engine
- [ ] Retention scheduling system
- [ ] API endpoints for DSARs

### Phase 3: Integration (Weeks 5-6)
- [ ] Authentication system integration
- [ ] Communication system integration
- [ ] OAuth provider disconnection
- [ ] Email/notification suppression

### Phase 4: Compliance (Weeks 7-8)
- [ ] Audit trail enhancement
- [ ] Compliance monitoring
- [ ] Reporting dashboard
- [ ] Security testing and validation

### Phase 5: Testing & Rollout (Weeks 9-10)
- [ ] Comprehensive GDPR compliance testing
- [ ] Load testing for bulk operations
- [ ] Documentation completion
- [ ] User-facing GDPR portal
- [ ] Production rollout

## Security Considerations

### 1. Data Encryption
- All sensitive data encrypted at rest (AES-256)
- Data exports encrypted with user-specific keys
- Secure key management via Vault integration

### 2. Access Controls
- Role-based access to GDPR functions
- Audit trail for all admin actions
- Multi-factor authentication for GDPR operations

### 3. Data Integrity
- Cryptographic hashing of sensitive audit data
- Tamper-evident logging
- Regular backup verification

## Legal and Compliance Notes

### 1. Documentation Requirements
- Data Processing Impact Assessment (DPIA)
- Records of Processing Activities (ROPA)
- Data Protection Impact Assessment documentation
- Privacy Policy updates

### 2. Third-Party Considerations
- Data processor agreements review
- Sub-processor documentation
- International data transfer mechanisms
- Standard Contractual Clauses (SCCs)

### 3. Regulatory Compliance
- GDPR Article 30 documentation
- Data breach notification procedures
- Supervisory authority reporting requirements
- Data Protection Officer (DPO) consultation

## Conclusion

This comprehensive GDPR compliance architecture provides the MCP platform with a robust foundation for implementing user soft deletion and data retention requirements. The design ensures full compliance with GDPR while maintaining system performance and operational efficiency.

The modular approach allows for incremental implementation and testing, reducing risk while ensuring all compliance requirements are met. The architecture also provides scalability for future regulatory requirements and business needs.

**Next Steps**:
1. Review and approval of this architecture design
2. Resource allocation and timeline confirmation
3. Detailed technical specifications for Agent 2 implementation
4. Integration planning for Agent 3 workflows