# GDPR Compliance API Reference

## Overview

The GDPR Compliance API provides comprehensive endpoints for consent management, data subject rights fulfillment, retention policy enforcement, and compliance monitoring. All requests require authentication and appropriate GDPR administration permissions.

## Authentication

Include your API key in the Authorization header:
```http
Authorization: Bearer your-api-key
Content-Type: application/json
```

## Base URL
```
https://your-mcp-platform.com/gdpr
```

## Consent Management

### Record Consent

**POST** `/gdpr/consent`

Record user consent for data processing activities.

**Request:**
```json
{
  "consent": {
    "user_id": "user-uuid",
    "consent_type": "data_processing",
    "purposes": [
      {
        "id": "analytics",
        "description": "Usage analytics and service improvement",
        "granted": true,
        "required": false
      },
      {
        "id": "marketing",
        "description": "Marketing communications and offers",
        "granted": false,
        "required": false
      },
      {
        "id": "personalization",
        "description": "Personalized content recommendations",
        "granted": true,
        "required": false
      }
    ],
    "data_categories": ["email", "usage_patterns", "preferences"],
    "retention_period": "until_withdrawn",
    "version": "1.0",
    "language": "en-US",
    "ip_address": "192.168.1.100",
    "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "consent_id": "consent_1234567890abcdef",
    "user_id": "user-uuid",
    "consent_type": "data_processing",
    "recorded_at": "2025-11-24T10:00:00Z",
    "version": "1.0",
    "language": "en-US",
    "legal_basis": "explicit_consent",
    "purposes": [
      {
        "id": "analytics",
        "granted": true,
        "granted_at": "2025-11-24T10:00:00Z",
        "expires_at": null
      },
      {
        "id": "marketing",
        "granted": false,
        "expires_at": null
      },
      {
        "id": "personalization",
        "granted": true,
        "granted_at": "2025-11-24T10:00:00Z",
        "expires_at": null
      }
    ],
    "data_categories": ["email", "usage_patterns", "preferences"],
    "ip_address": "192.168.1.100"
  }
}
```

### Get User Consent Status

**GET** `/gdpr/consent/{user_id}`

Retrieve current consent status for a user.

**Query Parameters:**
- `consent_type` (string, optional): Filter by specific consent type
- `purpose_id` (string, optional): Filter by specific purpose
- `include_history` (boolean, optional): Include consent history (default: false)
- `active_only` (boolean, optional): Return only active consents (default: true)

**Response:**
```json
{
  "status": "success",
  "data": {
    "user_id": "user-uuid",
    "consent_status": {
      "overall_consent": "partial",
      "last_updated": "2025-11-24T10:00:00Z",
      "purposes": [
        {
          "id": "analytics",
          "consent_type": "data_processing",
          "granted": true,
          "granted_at": "2025-11-24T10:00:00Z",
          "withdrawn_at": null,
          "expires_at": null,
          "version": "1.0",
          "status": "active"
        },
        {
          "id": "marketing",
          "consent_type": "data_processing",
          "granted": false,
          "granted_at": "2025-11-01T10:00:00Z",
          "withdrawn_at": "2025-11-15T14:30:00Z",
          "expires_at": null,
          "version": "1.0",
          "status": "withdrawn"
        }
      ]
    },
    "consent_history": [
      {
        "consent_id": "consent_1234567890abcdef",
        "action": "granted",
        "purpose_id": "analytics",
        "timestamp": "2025-11-24T10:00:00Z",
        "ip_address": "192.168.1.100"
      }
    ]
  }
}
```

### Withdraw Consent

**DELETE** `/gdpr/consent`

Withdraw user consent for specific purposes or entire consent type.

**Request:**
```json
{
  "withdrawal": {
    "user_id": "user-uuid",
    "consent_type": "data_processing",
    "purpose_id": "marketing",
    "reason": "user_withdrawal",
    "effective_immediately": true,
    "ip_address": "192.168.1.100",
    "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "withdrawal_id": "withdraw_1234567890abcdef",
    "user_id": "user-uuid",
    "consent_type": "data_processing",
    "purpose_id": "marketing",
    "withdrawn_at": "2025-11-24T10:00:00Z",
    "effective_immediately": true,
    "reason": "user_withdrawal",
    "affected_processes": [
      {
        "process": "marketing_campaigns",
        "status": "stopped",
        "data_retention_period": "30_days"
      },
      {
        "process": "email_newsletters",
        "status": "removed",
        "data_retention_period": "immediate"
      },
      {
        "process": "third_party_sharing",
        "status": "blocked",
        "data_retention_period": "immediate"
      }
    ],
    "confirmation_sent": true
  }
}
```

### Update Consent Version

**PUT** `/gdpr/consent/{consent_id}`

Update consent record with new version or additional purposes.

**Request:**
```json
{
  "consent": {
    "version": "1.1",
    "additional_purposes": [
      {
        "id": "research",
        "description": "Product development and research studies",
        "granted": true,
        "required": false
      }
    ],
    "update_reason": "service_expansion",
    "notify_user": true,
    "require_reconfirmation": false
  }
}
```

## Data Subject Rights

### Create Access Request

**POST** `/gdpr/data-requests/access`

Create a data subject access request.

**Request:**
```json
{
  "request": {
    "user_id": "user-uuid",
    "requester": "user",
    "format": "json",
    "data_types": ["all"],
    "include_deleted": false,
    "include_metadata": true,
    "verification_method": "email",
    "description": "User requesting full data export"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "request_id": "req_1234567890abcdef",
    "user_id": "user-uuid",
    "type": "access",
    "status": "pending",
    "format": "json",
    "data_types": ["all"],
    "created_at": "2025-11-24T10:00:00Z",
    "estimated_completion": "2025-11-25T10:00:00Z",
    "expires_at": "2025-12-01T10:00:00Z",
    "verification_required": true,
    "verification_sent": true
  }
}
```

### Create Erasure Request

**POST** `/gdpr/data-requests/erasure`

Create a data subject erasure request (Right to be Forgotten).

**Request:**
```json
{
  "request": {
    "user_id": "user-uuid",
    "requester": "user",
    "reason": "right_to_be_forgotten",
    "scope": "all",
    "exceptions": ["legal_requirements", "financial_records"],
    "verification_method": "email",
    "confirmation_required": true,
    "immediate_effect": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "request_id": "req_fedcba0987654321",
    "user_id": "user-uuid",
    "type": "erasure",
    "status": "pending_verification",
    "reason": "right_to_be_forgotten",
    "scope": "all",
    "exceptions": ["legal_requirements", "financial_records"],
    "created_at": "2025-11-24T10:00:00Z",
    "verification_required": true,
    "verification_method": "email",
    "confirmation_sent": true
  }
}
```

### Get Request Status

**GET** `/gdpr/data-requests/{request_id}`

Retrieve status and details of a data subject request.

**Response:**
```json
{
  "status": "success",
  "data": {
    "request_id": "req_1234567890abcdef",
    "user_id": "user-uuid",
    "type": "access",
    "status": "completed",
    "created_at": "2025-11-24T10:00:00Z",
    "processing_started_at": "2025-11-24T10:05:00Z",
    "completed_at": "2025-11-24T10:30:00Z",
    "format": "json",
    "data_types": ["all"],
    "result": {
      "total_records": 1542,
      "file_size_bytes": 2048576,
      "download_url": "https://storage.example.com/exports/req_1234567890abcdef/data.json",
      "download_count": 1,
      "expires_at": "2025-12-01T10:00:00Z"
    }
  }
}
```

### Download Data Export

**GET** `/gdpr/data-requests/{request_id}/download`

Download data export file for completed access requests.

**Query Parameters:**
- `format` (string, optional): Export format if multiple available

**Response:**
```
Content-Type: application/json
Content-Disposition: attachment; filename="user_data_export.json"
Content-Length: 2048576

{
  "schema": "gdpr_portability_v1.0",
  "export_date": "2025-11-24T10:30:00Z",
  "data_subject": {
    "id": "user-uuid",
    "email": "user@example.com",
    "name": "John Doe"
  },
  "personal_data": {
    "profile": {
      "name": "John Doe",
      "email": "user@example.com",
      "created_at": "2023-01-15T10:00:00Z",
      "updated_at": "2025-11-20T14:30:00Z"
    },
    "preferences": {
      "language": "en-US",
      "timezone": "UTC",
      "notifications": true
    }
  },
  "consent_records": [
    {
      "consent_type": "data_processing",
      "purpose": "analytics",
      "granted_at": "2025-11-24T10:00:00Z",
      "version": "1.0"
    }
  ],
  "usage_data": {
    "last_login": "2025-11-24T09:30:00Z",
    "total_logins": 1247,
    "sessions": [...]
  }
}
```

### Verify Request

**POST** `/gdpr/data-requests/{request_id}/verify`

Verify user identity for data subject request processing.

**Request:**
```json
{
  "verification": {
    "method": "email_code",
    "code": "123456",
    "timestamp": "2025-11-24T10:15:00Z",
    "ip_address": "192.168.1.100"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "request_id": "req_1234567890abcdef",
    "verified_at": "2025-11-24T10:15:30Z",
    "verification_method": "email_code",
    "processing_started": true,
    "estimated_completion": "2025-11-25T10:00:00Z"
  }
}
```

## Retention Management

### Configure Retention Policies

**POST** `/gdpr/retention/policies`

Configure or update data retention policies.

**Request:**
```json
{
  "policies": {
    "user_profile": {
      "retention_period": {"unit": "years", "value": 7},
      "action": "anonymize",
      "anonymization_fields": ["email", "name", "phone", "address"],
      "exceptions": ["legal_hold", "active_litigation"],
      "conditions": "inactive_for_365_days"
    },
    "financial_records": {
      "retention_period": {"unit": "years", "value": 10},
      "action": "archive",
      "archive_location": "long_term_storage",
      "regulatory_requirements": ["tax_laws", "accounting_standards"],
      "conditions": "always_retain"
    },
    "session_data": {
      "retention_period": {"unit": "months", "value": 6},
      "action": "delete",
      "auto_cleanup": true,
      "cleanup_interval": "weekly",
      "conditions": "session_ended"
    },
    "consent_records": {
      "retention_period": {"unit": "years", "value": 10},
      "action": "retain",
      "legal_basis": "documented_consent",
      "conditions": "always_retain"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "policy_id": "policy_1234567890abcdef",
    "configured_policies": 4,
    "applied_at": "2025-11-24T10:00:00Z",
    "next_scheduled_run": "2025-11-25T10:00:00Z"
  }
}
```

### Apply Retention Policies

**POST** `/gdpr/retention/apply`

Manually trigger retention policy application.

**Request:**
```json
{
  "application": {
    "dry_run": false,
    "batch_size": 1000,
    "policies": ["all"],
    "data_types": ["all"],
    "include_exceptions": true,
    "notify_admin": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "application_id": "app_1234567890abcdef",
    "started_at": "2025-11-24T10:00:00Z",
    "results": {
      "total_records_processed": 15420,
      "deleted_records": 1250,
      "anonymized_records": 3400,
      "archived_records": 890,
      "errors": [
        {
          "data_type": "user_profile",
          "record_id": "rec_123",
          "error": "Legal hold exception",
          "action": "skipped"
        }
      ]
    },
    "processing_time_seconds": 45.2
  }
}
```

### Get Retention Status

**GET** `/gdpr/retention/status`

Get current retention policy status and compliance.

**Query Parameters:**
- `data_type` (string, optional): Filter by specific data type
- `policy_id` (string, optional): Filter by specific policy

**Response:**
```json
{
  "status": "success",
  "data": {
    "overall_compliance": 98.7,
    "last_applied": "2025-11-24T10:00:00Z",
    "next_scheduled": "2025-11-25T10:00:00Z",
    "policies": [
      {
        "data_type": "user_profile",
        "policy_status": "compliant",
        "total_records": 12500,
        "overdue_records": 0,
        "overdue_percentage": 0.0
      },
      {
        "data_type": "session_data",
        "policy_status": "mostly_compliant",
        "total_records": 15420,
        "overdue_records": 125,
        "overdue_percentage": 0.8
      }
    ],
    "alerts": [
      {
        "type": "warning",
        "data_type": "session_data",
        "message": "125 session records exceed retention period",
        "action_required": true,
        "due_date": "2025-11-25T10:00:00Z"
      }
    ]
  }
}
```

## Compliance Monitoring

### Get Compliance Status

**GET** `/gdpr/compliance/status`

Get overall GDPR compliance status and metrics.

**Query Parameters:**
- `include_detailed` (boolean, optional): Include detailed component analysis
- `include_recommendations` (boolean, optional): Include improvement recommendations
- `period` (string, optional): Time period for analysis (default: 30d)

**Response:**
```json
{
  "status": "success",
  "data": {
    "overall_compliance": 98.7,
    "last_scan": "2025-11-24T09:00:00Z",
    "scan_period": "30d",
    "components": {
      "consent_management": {
        "status": "compliant",
        "score": 100.0,
        "issues": [],
        "metrics": {
          "total_consents": 15420,
          "active_consents": 12450,
          "withdrawn_consents": 2970,
          "expired_consents": 0
        }
      },
      "data_retention": {
        "status": "mostly_compliant",
        "score": 95.2,
        "issues": [
          {
            "type": "over_retention",
            "severity": "low",
            "count": 15,
            "description": "15 records exceed retention period"
          }
        ],
        "metrics": {
          "total_records": 89420,
          "compliant_records": 85000,
          "overdue_records": 420,
          "overdue_percentage": 0.5
        }
      },
      "access_requests": {
        "status": "compliant",
        "score": 100.0,
        "metrics": {
          "pending_requests": 2,
          "completed_requests": 45,
          "average_processing_time_days": 2.5,
          "sla_compliance_percentage": 100.0
        }
      },
      "erasure_requests": {
        "status": "compliant",
        "score": 100.0,
        "metrics": {
          "pending_requests": 1,
          "completed_requests": 8,
          "average_processing_time_days": 15.2,
          "sla_compliance_percentage": 100.0
        }
      }
    },
    "risk_assessment": {
      "overall_risk": "low",
      "high_risk_items": 0,
      "medium_risk_items": 1,
      "low_risk_items": 3
    },
    "recommendations": [
      {
        "priority": "medium",
        "category": "data_retention",
        "description": "Review and update retention policies for session data",
        "action": "Configure automatic cleanup session data older than 6 months",
        "estimated_effort": "2-4 hours"
      }
    ]
  }
}
```

### Run Compliance Scan

**POST** `/gdpr/compliance/scan`

Trigger comprehensive GDPR compliance scan.

**Request:**
```json
{
  "scan": {
    "scan_types": [
      "personal_data_detection",
      "consent_compliance_check",
      "retention_policy_compliance",
      "data_processing_audit",
      "security_controls_review"
    ],
    "data_types": ["all"],
    "time_period": "30d",
    "auto_remediate": true,
    "notify_admin": true,
    "include_recommendations": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "scan_id": "scan_1234567890abcdef",
    "started_at": "2025-11-24T10:00:00Z",
    "estimated_completion": "2025-11-24T10:30:00Z",
    "scan_types": [
      "personal_data_detection",
      "consent_compliance_check",
      "retention_policy_compliance",
      "data_processing_audit",
      "security_controls_review"
    ],
    "status": "running"
  }
}
```

### Get Scan Results

**GET** `/gdpr/compliance/scan/{scan_id}`

Retrieve results of a completed compliance scan.

**Response:**
```json
{
  "status": "success",
  "data": {
    "scan_id": "scan_1234567890abcdef",
    "completed_at": "2025-11-24T10:28:45Z",
    "duration_seconds": 1725,
    "overall_score": 98.7,
    "results": {
      "personal_data_detection": {
        "status": "compliant",
        "score": 100.0,
        "personal_data_records_found": 89420,
        "properly_tagged": 89420,
        "issues": []
      },
      "consent_compliance_check": {
        "status": "compliant",
        "score": 100.0,
        "consent_records": 15420,
        "compliant_records": 15420,
        "issues": []
      },
      "retention_policy_compliance": {
        "status": "mostly_compliant",
        "score": 95.2,
        "records_checked": 89420,
        "compliant_records": 88995,
        "issues": [
          {
            "type": "over_retention",
            "count": 425,
            "severity": "low",
            "affected_data_types": ["session_data", "temp_files"]
          }
        ]
      }
    },
    "remediation_actions": [
      {
        "type": "auto_remediation",
        "action": "delete_overdue_session_data",
        "status": "completed",
        "records_processed": 325
      }
    ]
  }
}
```

### Get Audit Logs

**GET** `/gdpr/audit-logs`

Retrieve GDPR compliance audit logs.

**Query Parameters:**
- `event_type` (string, optional): Filter by specific event type
- `user_id` (string, optional): Filter by specific user
- `start_date` (string, optional): Start date (ISO 8601)
- `end_date` (string, optional): End date (ISO 8601)
- `severity` (string, optional): Filter by severity level
- `limit` (integer, optional): Number of logs to return (default: 50)
- `offset` (integer, optional): Number of logs to skip (default: 0)

**Response:**
```json
{
  "status": "success",
  "data": {
    "logs": [
      {
        "id": "log_1234567890abcdef",
        "event_type": "consent_granted",
        "user_id": "user-uuid",
        "actor_id": "user-uuid",
        "actor_type": "user",
        "action": "grant_consent",
        "resource_type": "consent_record",
        "resource_id": "consent_fedcba0987654321",
        "description": "User granted consent for analytics processing",
        "ip_address": "192.168.1.100",
        "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "request_id": "req_1234567890abcdef",
        "session_id": "sess_fedcba0987654321",
        "severity": "info",
        "compliance_relevance": "high",
        "timestamp": "2025-11-24T10:00:00Z",
        "metadata": {
          "consent_type": "data_processing",
          "purpose": "analytics",
          "version": "1.0"
        }
      }
    ],
    "pagination": {
      "total": 1250,
      "limit": 50,
      "offset": 0,
      "has_more": true
    }
  }
}
```

## Data Breach Management

### Report Data Breach

**POST** `/gdpr/breaches`

Report a data breach incident.

**Request:**
```json
{
  "breach": {
    "title": "Unauthorized Access Incident",
    "description": "Phishing attack led to unauthorized access to customer data",
    "severity": "medium",
    "detected_at": "2025-11-24T08:30:00Z",
    "reported_at": "2025-11-24T09:15:00Z",
    "data_types_affected": [
      "email",
      "personal_info",
      "preferences",
      "usage_patterns"
    ],
    "data_subjects_affected": 150,
    "root_cause": "Phishing attack on employee account using compromised credentials",
    "immediate_actions": [
      "Reset compromised passwords",
      "Block malicious IP addresses",
      "Notify security team",
      "Isolate affected systems"
    ],
    "long_term_measures": [
      "Enhanced employee training",
      "Multi-factor authentication enforcement",
      "Advanced threat detection systems",
      "Regular security awareness programs"
    ],
    "investigator_id": "admin_1234567890abcdef"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "breach_id": "breach_1234567890abcdef",
    "title": "Unauthorized Access Incident",
    "severity": "medium",
    "status": "investigating",
    "detected_at": "2025-11-24T08:30:00Z",
    "reported_at": "2025-11-24T09:15:00Z",
    "data_subjects_affected": 150,
    "notification_requirements": {
      "supervisory_authority": {
        "required": true,
        "deadline": "2025-11-25T09:15:00Z",
        "status": "pending"
      },
      "data_subjects": {
        "required": true,
        "deadline": "2025-11-27T09:15:00Z",
        "status": "pending"
      }
    }
  }
}
```

### Update Breach Response

**PUT** `/gdpr/breaches/{breach_id}`

Update breach incident response status and actions.

**Request:**
```json
{
  "update": {
    "status": "contained",
    "contained_at": "2025-11-24T10:30:00Z",
    "investigation_summary": "Attack originated from external IP, credentials compromised via phishing",
    "additional_measures": [
      "Implement IP allowlisting for admin access",
      "Conduct penetration testing",
      "Review access control policies"
    ],
    "lessons_learned": "Employee security awareness needs improvement, phishing simulation training recommended",
    "preventive_measures": [
      "Quarterly security training",
      "Phishing simulation exercises",
      "Enhanced email filtering",
      "Regular security assessments"
    ]
  }
}
```

### Get Breach Details

**GET** `/gdpr/breaches/{breach_id}`

Retrieve detailed information about a data breach.

**Response:**
```json
{
  "status": "success",
  "data": {
    "breach_id": "breach_1234567890abcdef",
    "title": "Unauthorized Access Incident",
    "description": "Phishing attack led to unauthorized access to customer data",
    "severity": "medium",
    "status": "contained",
    "detected_at": "2025-11-24T08:30:00Z",
    "reported_at": "2025-11-24T09:15:00Z",
    "contained_at": "2025-11-24T10:30:00Z",
    "resolved_at": null,
    "data_types_affected": [
      "email",
      "personal_info",
      "preferences",
      "usage_patterns"
    ],
    "data_subjects_affected": 150,
    "root_cause": "Phishing attack on employee account using compromised credentials",
    "immediate_actions": [
      "Reset compromised passwords",
      "Block malicious IP addresses",
      "Notify security team",
      "Isolate affected systems"
    ],
    "long_term_measures": [
      "Enhanced employee training",
      "Multi-factor authentication enforcement",
      "Advanced threat detection systems",
      "Regular security awareness programs"
    ],
    "notification_status": {
      "supervisory_authority": {
        "notified": true,
        "notified_at": "2025-11-24T11:00:00Z",
        "reference": "BREACH-2025-001"
      },
      "data_subjects": {
        "notified": false,
        "planned_date": "2025-11-25T12:00:00Z",
        "notification_method": "email"
      }
    },
    "investigator_id": "admin_1234567890abcdef",
    "lessons_learned": "Employee security awareness needs improvement, phishing simulation training recommended",
    "preventive_measures": [
      "Quarterly security training",
      "Phishing simulation exercises",
      "Enhanced email filtering",
      "Regular security assessments"
    ]
  }
}
```

## Privacy Impact Assessments

### Create DPIA

**POST** `/gdpr/dpia`

Create Data Protection Impact Assessment (DPIA).

**Request:**
```json
{
  "dpia": {
    "processing_activity": "Customer behavior analytics",
    "description": "Analysis of customer behavior patterns to provide personalized recommendations",
    "controller": "marketing_team",
    "controller_contact": "marketing@example.com",
    "processor": "analytics_service_provider",
    "processor_contact": "analytics@provider.com",
    "data_types": [
      "email",
      "usage_patterns",
      "preferences",
      "demographics"
    ],
    "purposes": [
      "Personalized marketing",
      "Service improvement",
      "User experience optimization"
    ],
    "legal_basis": "legitimate_interest",
    "necessity_and_proportionality": {
      "purpose": "Processing is necessary for improving service quality and user experience",
      "alternatives_considered": [
        "Anonymous analytics",
        "Opt-in only data collection",
        "Reduced data scope"
      ],
      "alternatives_rejected": [
        "Anonymous analytics insufficient for personalization",
        "Opt-in only would limit data availability"
      ]
    },
    "risks": [
      {
        "type": "privacy",
        "description": "Unauthorized access to personal behavioral data",
        "likelihood": "medium",
        "severity": "high",
        "impact_score": 8
      }
    ],
    "measures": [
      "Data minimization",
      "Pseudonymization",
      "Encryption at rest and in transit",
      "Access controls",
      "Regular security assessments"
    ],
    "international_transfers": true,
    "transfer_destinations": ["US", "EU"],
    "risk_level": "medium"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "dpia_id": "dpia_1234567890abcdef",
    "status": "pending_review",
    "created_at": "2025-11-24T10:00:00Z",
    "processing_activity": "Customer behavior analytics",
    "risk_level": "medium",
    "requires_review": true,
    "review_deadline": "2025-12-01T10:00:00Z"
  }
}
```

### Review DPIA

**POST** `/gdpr/dpia/{dpia_id}/review`

Review and approve or reject Data Protection Impact Assessment.

**Request:**
```json
{
  "review": {
    "reviewer": "dpo@example.com",
    "reviewer_role": "data_protection_officer",
    "recommendations": [
      "Add explicit consent mechanism for behavioral analytics",
      "Implement stronger encryption for sensitive data",
      "Reduce data retention period from 24 months to 12 months",
      "Add option for users to opt out of behavioral tracking"
    ],
    "additional_measures": [
      "Regular DPIA review schedule",
      "Enhanced user control interface",
      "Detailed privacy notices explaining behavioral analytics"
    ],
    "approved": true,
    "approval_conditions": [
      "Implement explicit consent before 2025-12-15",
      "Complete additional security measures by 2025-12-31",
      "Submit follow-up DPIA review by 2026-03-01"
    ],
    "review_notes": "Processing is high risk but measures are adequate. Regular monitoring required."
  }
}
```

## Error Codes Reference

### Consent Management Errors (400)

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_consent_type` | Consent type not recognized | Use valid consent type values |
| `missing_required_purposes` | Required consent purposes missing | Include all required purposes |
| `consent_expired` | Consent has expired | Record new consent |
| `already_withdrawn` | Consent already withdrawn | No action needed |
| `invalid_verification` | Verification method invalid | Use supported verification methods |

### Data Subject Rights Errors (403)

| Code | Description | Resolution |
|------|-------------|------------|
| `verification_failed` | Identity verification failed | Retry verification with correct method |
| `request_expired` | Data request has expired | Submit new request |
| `insufficient_permissions` | Lacks required permissions | Obtain appropriate permissions |
| `data_not_found` | No data found for user | Confirm user ID and data types |
| `processing_in_progress` | Request already being processed | Wait for current request to complete |

### Retention Policy Errors (422)

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_retention_period` | Retention period format invalid | Use valid retention period format |
| `conflicting_policies` | Multiple conflicting policies | Resolve policy conflicts |
| `policy_in_use` | Policy cannot be deleted | Stop policy use before deletion |
| `exceptions_not_allowed` | Exceptions not allowed for action | Remove or modify exceptions |

### Compliance Monitoring Errors (500)

| Code | Description | Resolution |
|------|-------------|------------|
| `scan_failed` | Compliance scan failed | Retry scan with adjusted parameters |
| `policy_validation_error` | Policy validation error | Fix policy configuration |
| `audit_log_error` | Audit logging error | Check logging system status |
| `breach_reporting_error` | Breach reporting failed | Contact security team |

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|---------|
| Consent Management | 100 requests | per minute |
| Data Subject Rights | 50 requests | per minute |
| Retention Management | 20 requests | per minute |
| Compliance Monitoring | 100 requests | per minute |
| Data Breach Management | 10 requests | per minute |
| DPIA Management | 20 requests | per minute |

## Webhooks

### Data Rights Events

- `consent_granted` - New consent recorded
- `consent_withdrawn` - Consent withdrawn
- `access_request_created` - Data access request submitted
- `access_request_completed` - Data access request completed
- `erasure_request_created` - Data erasure request submitted
- `erasure_request_completed` - Data erasure request completed

### Compliance Events

- `compliance_scan_completed` - Compliance scan finished
- `policy_violation_detected` - Policy violation found
- `retention_action_executed` - Retention action taken
- `breach_reported` - Data breach reported
- `dpia_required` - DPIA requirement identified
- `dpia_approved` - DPIA approved

### Webhook Security

All webhook requests include:
- `X-Signature` header with HMAC signature
- `X-Event-Type` header with event type
- Unique event ID for deduplication
- Timestamp for replay protection

---

**Related Documentation**: [GDPR Compliance Overview](README.md) | [Core Platform](../core-platform/README.md) | [Multi-Tenancy Guide](../multi-tenancy/README.md)