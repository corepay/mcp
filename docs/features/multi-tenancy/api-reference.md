# Multi-Tenancy API Reference

## Overview

The Multi-Tenancy API provides comprehensive endpoints for tenant management, schema operations, domain resolution, resource monitoring, and tenant administration. All requests require authentication and appropriate multi-tenancy permissions.

## Authentication

Include your API key in the Authorization header:
```http
Authorization: Bearer your-api-key
Content-Type: application/json
```

## Base URL
```
https://your-mcp-platform.com
```

## Tenant Management

### Create Tenant

**POST** `/tenants`

Create a new tenant with isolated environment and complete setup.

**Request:**
```json
{
  "tenant": {
    "name": "Acme Corporation",
    "schema_name": "acme_corp",
    "domain": "acme.mcp-platform.com",
    "settings": {
      "timezone": "America/New_York",
      "currency": "USD",
      "locale": "en-US",
      "date_format": "%m/%d/%Y",
      "time_format": "%I:%M %p",
      "features": {
        "advanced_analytics": true,
        "custom_branding": true,
        "api_access": true,
        "gdpr_compliance": true
      }
    },
    "admin_user": {
      "email": "admin@acme.com",
      "name": "John Admin",
      "password": "SecurePassword123!"
    },
    "limits": {
      "users": 1000,
      "storage_gb": 100,
      "api_calls_per_day": 100000,
      "custom_integrations": 5
    },
    "branding": {
      "logo_url": "https://acme.example.com/logo.png",
      "primary_color": "#007bff",
      "secondary_color": "#6c757d",
      "company_name": "Acme Corporation"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "tenant": {
      "id": "tenant_1234567890abcdef",
      "name": "Acme Corporation",
      "schema_name": "acme_corp",
      "domain": "acme.mcp-platform.com",
      "status": "provisioning",
      "created_at": "2025-11-24T10:00:00Z"
    },
    "admin_user": {
      "id": "user_fedcba0987654321",
      "email": "admin@acme.com",
      "name": "John Admin",
      "role": "tenant_admin"
    },
    "database": {
      "schema_created": true,
      "migrations_applied": true,
      "extensions_enabled": ["uuid-ossp", "pgcrypto", "postgis", "vector"]
    },
    "provisioning": {
      "status": "in_progress",
      "estimated_completion": "2025-11-24T10:05:00Z",
      "steps_completed": ["schema_creation", "migration_setup"],
      "steps_remaining": ["extensions_setup", "admin_creation", "branding_apply"]
    }
  }
}
```

### Get Tenant Information

**GET** `/tenants/{tenant_id}`

Retrieve tenant configuration, status, and usage information.

**Response:**
```json
{
  "status": "success",
  "data": {
    "tenant": {
      "id": "tenant_1234567890abcdef",
      "name": "Acme Corporation",
      "schema_name": "acme_corp",
      "domain": "acme.mcp-platform.com",
      "status": "active",
      "created_at": "2025-11-01T10:00:00Z",
      "updated_at": "2025-11-24T10:00:00Z"
    },
    "usage": {
      "users": {
        "current": 245,
        "limit": 1000,
        "usage_percent": 24.5
      },
      "storage": {
        "current_gb": 45.2,
        "limit_gb": 100,
        "usage_percent": 45.2
      },
      "api_calls": {
        "current_daily": 15420,
        "limit_daily": 100000,
        "usage_percent": 15.4
      },
      "database_connections": {
        "current": 25,
        "limit": 50,
        "usage_percent": 50.0
      }
    },
    "features": {
      "multi_tenancy": true,
      "gdpr_compliance": true,
      "advanced_analytics": true,
      "custom_integrations": true,
      "priority_support": true,
      "custom_domains": true,
      "api_access": true
    },
    "branding": {
      "logo_url": "https://acme.example.com/logo.png",
      "primary_color": "#007bff",
      "secondary_color": "#6c757d",
      "company_name": "Acme Corporation",
      "custom_css_applied": true
    }
  }
}
```

### Update Tenant Configuration

**PUT** `/tenants/{tenant_id}`

Update tenant settings, limits, or configuration.

**Request:**
```json
{
  "settings": {
    "timezone": "Europe/London",
    "locale": "en-GB",
    "currency": "GBP"
  },
  "limits": {
    "users": 2000,
    "storage_gb": 200,
    "api_calls_per_day": 200000
  },
  "features": {
    "advanced_analytics": true,
    "custom_integrations": true,
    "sso_integration": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "tenant": {
      "id": "tenant_1234567890abcdef",
      "updated_at": "2025-11-24T10:00:00Z"
    },
    "changes_applied": [
      "timezone_updated",
      "limits_increased",
      "features_enabled"
    ],
    "restart_required": false
  }
}
```

### Delete Tenant

**DELETE** `/tenants/{tenant_id}`

Delete tenant and all associated data (irreversible).

**Query Parameters:**
- `confirmation` (string, required): "DELETE_PERMANENTLY" to confirm
- `grace_period_days` (integer, optional): Days to retain data before permanent deletion

**Response:**
```json
{
  "status": "success",
  "data": {
    "tenant_id": "tenant_1234567890abcdef",
    "deletion_status": "scheduled",
    "scheduled_at": "2025-11-24T10:00:00Z",
    "final_deletion_date": "2025-12-01T10:00:00Z",
    "data_export_url": "https://storage.mcp-platform.com/exports/tenant_1234567890abcdef.tar.gz"
  }
}
```

## Schema Operations

### Execute Schema Query

**POST** `/tenants/{tenant_id}/query`

Execute SQL query within tenant schema with safety restrictions.

**Request:**
```json
{
  "query": "SELECT COUNT(*) as total_users, COUNT(CASE WHEN created_at >= $1 THEN 1 END) as new_users FROM users",
  "parameters": ["2025-11-01T00:00:00Z"],
  "read_only": true,
  "timeout_ms": 5000,
  "limit_rows": 1000
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "query_id": "q_1234567890abcdef",
    "execution_time_ms": 125,
    "row_count": 1,
    "rows": [
      [245, 32]
    ],
    "columns": ["total_users", "new_users"],
    "schema": "acq_acme_corp",
    "query_plan": {
      "estimated_cost": 12.5,
      "actual_cost": 8.3,
      "execution_time_ms": 95
    }
  }
}
```

### Get Tenant Schema

**GET** `/tenants/{tenant_id}/schema`

Retrieve tenant database schema information.

**Query Parameters:**
- `table` (string, optional): Specific table to analyze
- `include_indexes` (boolean, optional): Include index information
- `include_constraints` (boolean, optional): Include constraint information

**Response:**
```json
{
  "status": "success",
  "data": {
    "schema": "acq_acme_corp",
    "tables": [
      {
        "name": "users",
        "columns": [
          {
            "name": "id",
            "type": "uuid",
            "nullable": false,
            "default": "gen_random_uuid()"
          },
          {
            "name": "email",
            "type": "varchar(255)",
            "nullable": false,
            "constraints": ["UNIQUE", "NOT NULL"]
          },
          {
            "name": "tenant_id",
            "type": "uuid",
            "nullable": false,
            "constraints": ["NOT NULL", "FOREIGN KEY"]
          }
        ],
        "indexes": [
          {
            "name": "users_pkey",
            "columns": ["id"],
            "type": "primary_key"
          },
          {
            "name": "users_tenant_id_idx",
            "columns": ["tenant_id"],
            "type": "btree"
          }
        ],
        "row_count": 245,
        "size_mb": 12.5,
        "last_analyzed": "2025-11-24T09:00:00Z"
      }
    ],
    "schema_size_mb": 45.2,
    "total_indexes": 15,
    "foreign_keys": 8
  }
}
```

### Migrate Tenant Schema

**POST** `/tenants/{tenant_id}/migrate`

Run database migrations for tenant schema.

**Request:**
```json
{
  "direction": "up",
  "version": "20251124000101",
  "dry_run": false,
  "force": false,
  "backup_before": true
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "migration_id": "mig_1234567890abcdef",
    "executed_migrations": [
      {
        "version": "20251124000101",
        "name": "Add user preferences table",
        "execution_time_ms": 1250,
        "status": "success"
      },
      {
        "version": "20251124000102",
        "name": "Create audit_log indexes",
        "execution_time_ms": 450,
        "status": "success"
      }
    ],
    "total_execution_time_ms": 1800,
    "schema_version": "20251124000102",
    "backup_created": true
  }
}
```

## Domain Management

### Configure Domain Routing

**POST** `/tenants/{tenant_id}/domains`

Configure domain-based routing for tenant access.

**Request:**
```json
{
  "domains": [
    {
      "domain": "acme.mcp-platform.com",
      "primary": true,
      "ssl_enabled": true,
      "redirects": {
        "old.acme.com": "acme.mcp-platform.com",
        "acmecorp.com": "acme.mcp-platform.com"
      }
    },
    {
      "domain": "portal.acme.com",
      "primary": false,
      "ssl_enabled": true,
      "custom_routing": {
        "path_prefix": "/portal",
        "custom_headers": {
          "X-Portal-Version": "2.0"
        }
      }
    }
  ],
  "routing_rules": {
    "enforce_https": true,
    "www_redirect": true,
    "ssl_expiration_alerts": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "routing_id": "route_1234567890abcdef",
    "domains_configured": 2,
    "primary_domain": "acme.mcp-platform.com",
    "ssl_certificates": [
      {
        "domain": "acme.mcp-platform.com",
        "certificate_id": "cert_abc123",
        "expires_at": "2026-02-24T10:00:00Z",
        "auto_renewal": true
      },
      {
        "domain": "portal.acme.com",
        "certificate_id": "cert_def456",
        "expires_at": "2026-02-24T10:00:00Z",
        "auto_renewal": true
      }
    ],
    "dns_records": [
      {
        "type": "CNAME",
        "host": "acme",
        "value": "mcp-platform.com",
        "ttl": 300
      }
    ]
  }
}
```

### Test Domain Resolution

**POST** `/tenants/{tenant_id}/domains/test`

Test domain resolution and routing configuration.

**Request:**
```json
{
  "domain": "acme.mcp-platform.com",
  "test_paths": [
    "/",
    "/users",
    "/admin/dashboard"
  ],
  "expected_tenant_id": "tenant_1234567890abcdef"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "domain": "acme.mcp-platform.com",
    "resolution_tests": [
      {
        "path": "/",
        "status": "success",
        "response_time_ms": 45,
        "tenant_detected": "tenant_1234567890abcdef",
        "ssl_valid": true
      },
      {
        "path": "/users",
        "status": "success",
        "response_time_ms": 125,
        "tenant_detected": "tenant_1234567890abcdef",
        "api_accessible": true
      },
      {
        "path": "/admin/dashboard",
        "status": "success",
        "response_time_ms": 89,
        "tenant_detected": "tenant_1234567890abcdef",
        "admin_accessible": true
      }
    ],
    "overall_status": "healthy",
    "ssl_certificate": {
      "valid": true,
      "expires_at": "2026-02-24T10:00:00Z",
      "issuer": "Let's Encrypt"
    }
  }
}
```

### Get Tenant by Domain

**GET** `/tenants/by-domain`

Resolve tenant information from domain name.

**Query Parameters:**
- `domain` (string, required): Domain name to resolve

**Response:**
```json
{
  "status": "success",
  "data": {
    "domain": "acme.mcp-platform.com",
    "tenant": {
      "id": "tenant_1234567890abcdef",
      "name": "Acme Corporation",
      "schema_name": "acme_corp",
      "status": "active"
    },
    "routing": {
      "primary_domain": true,
      "ssl_enabled": true,
      "custom_routing": false
    },
    "branding": {
      "logo_url": "https://acme.example.com/logo.png",
      "primary_color": "#007bff",
      "company_name": "Acme Corporation"
    }
  }
}
```

## Resource Management

### Get Tenant Resource Usage

**GET** `/tenants/{tenant_id}/usage`

Retrieve comprehensive resource usage statistics.

**Query Parameters:**
- `period` (string, optional): Time period (1h, 24h, 7d, 30d)
- `metrics` (string, optional): Comma-separated list of specific metrics
- `include_projections` (boolean, optional): Include usage projections

**Response:**
```json
{
  "status": "success",
  "data": {
    "period": "24h",
    "tenant_id": "tenant_1234567890abcdef",
    "usage": {
      "database": {
        "connections": {
          "current": 25,
          "peak": 35,
          "limit": 50,
          "avg_response_time_ms": 12
        },
        "storage": {
          "used_gb": 45.2,
          "limit_gb": 100,
          "growth_24h_gb": 0.1,
          "tables_count": 15,
          "indexes_size_gb": 5.2
        },
        "queries": {
          "total_24h": 15420,
          "avg_execution_time_ms": 45,
          "slow_queries_count": 3,
          "cache_hit_rate": 0.87
        }
      },
      "storage": {
        "files_count": 1250,
        "total_size_gb": 45.2,
        "uploads_24h": 145,
        "downloads_24h": 892,
        "bandwidth_gb_24h": 2.1
      },
      "api": {
        "calls_24h": 15420,
        "rate_limit_hits": 25,
        "avg_response_time_ms": 125,
        "error_rate": 0.002,
        "unique_users_24h": 245
      },
      "cache": {
        "memory_usage_mb": 256,
        "hit_rate": 0.87,
        "evictions_24h": 12,
        "operations_24h": 15420
      }
    },
    "limits": {
      "users": {"current": 245, "limit": 1000, "percent": 24.5},
      "storage_gb": {"current": 45.2, "limit": 100, "percent": 45.2},
      "api_calls_daily": {"current": 15420, "limit": 100000, "percent": 15.4},
      "database_connections": {"current": 25, "limit": 50, "percent": 50.0}
    },
    "projections": {
      "storage_30d_estimate_gb": 48.5,
      "api_calls_30d_estimate": 462600,
      "users_30d_estimate": 265
    }
  }
}
```

### Check Tenant Limits

**POST** `/tenants/{tenant_id}/limits/check`

Check tenant resource limits and enforce restrictions.

**Request:**
```json
{
  "auto_enforce": true,
  "notifications": ["email", "in_app"],
  "check_types": [
    "storage_quota",
    "api_rate_limits",
    "user_count",
    "database_connections"
  ],
  "grace_period_percent": 10
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "check_id": "check_1234567890abcdef",
    "timestamp": "2025-11-24T10:00:00Z",
    "limits_status": [
      {
        "resource": "storage_quota",
        "current": 45.2,
        "limit": 100,
        "usage_percent": 45.2,
        "status": "healthy",
        "actions_taken": []
      },
      {
        "resource": "api_rate_limits",
        "current": 15420,
        "limit": 100000,
        "usage_percent": 15.4,
        "status": "healthy",
        "actions_taken": []
      },
      {
        "resource": "database_connections",
        "current": 25,
        "limit": 50,
        "usage_percent": 50.0,
        "status": "warning",
        "actions_taken": [
          "connection_pool_monitoring_enabled"
        ]
      }
    ],
    "overall_status": "healthy",
    "notifications_sent": 1,
    "next_check_at": "2025-11-24T11:00:00Z"
  }
}
```

### Scale Tenant Resources

**POST** `/tenants/{tenant_id}/scale`

Scale tenant resource limits and allocation.

**Request:**
```json
{
  "target_limits": {
    "users": 2000,
    "storage_gb": 200,
    "api_calls_per_day": 200000,
    "database_connections": 75
  },
  "scale_strategy": "immediate",
  "billing_approval": true,
  "notification_settings": {
    "notify_admin": true,
    "notify_users": false
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "scaling_id": "scale_1234567890abcdef",
    "status": "in_progress",
    "estimated_completion": "2025-11-24T10:15:00Z",
    "current_limits": {
      "users": 1000,
      "storage_gb": 100,
      "api_calls_per_day": 100000,
      "database_connections": 50
    },
    "target_limits": {
      "users": 2000,
      "storage_gb": 200,
      "api_calls_per_day": 200000,
      "database_connections": 75
    },
    "steps": [
      {
        "name": "database_connection_pool",
        "status": "completed",
        "completed_at": "2025-11-24T10:02:00Z"
      },
      {
        "name": "storage_quota_update",
        "status": "in_progress",
        "estimated_completion": "2025-11-24T10:08:00Z"
      },
      {
        "name": "api_limit_update",
        "status": "pending",
        "estimated_completion": "2025-11-24T10:12:00Z"
      }
    ],
    "billing_impact": {
      "additional_cost_monthly": 500.00,
      "prorated_today": 16.67,
      "next_billing_date": "2025-12-01T00:00:00Z"
    }
  }
}
```

## Tenant User Management

### List Tenant Users

**GET** `/tenants/{tenant_id}/users`

Retrieve paginated list of tenant users.

**Query Parameters:**
- `page` (integer, optional): Page number (default: 1)
- `page_size` (integer, optional): Items per page (default: 50)
- `sort` (string, optional): Sort field (created_at, name, email)
- `order` (string, optional): Sort order (asc, desc)
- `search` (string, optional): Search term for name/email
- `status` (string, optional): Filter by status (active, inactive, suspended)

**Response:**
```json
{
  "status": "success",
  "data": {
    "users": [
      {
        "id": "user_1234567890abcdef",
        "email": "john.doe@acme.com",
        "name": "John Doe",
        "role": "user",
        "status": "active",
        "last_login_at": "2025-11-24T09:30:00Z",
        "created_at": "2025-11-01T10:00:00Z",
        "profile": {
          "department": "Engineering",
          "location": "New York"
        }
      },
      {
        "id": "user_fedcba0987654321",
        "email": "jane.smith@acme.com",
        "name": "Jane Smith",
        "role": "admin",
        "status": "active",
        "last_login_at": "2025-11-24T08:15:00Z",
        "created_at": "2025-11-02T14:20:00Z",
        "profile": {
          "department": "Management",
          "location": "San Francisco"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 50,
      "total_count": 245,
      "total_pages": 5,
      "has_next": true,
      "has_prev": false
    }
  }
}
```

### Create Tenant User

**POST** `/tenants/{tenant_id}/users`

Create new user within tenant schema.

**Request:**
```json
{
  "user": {
    "email": "new.user@acme.com",
    "name": "New User",
    "password": "SecurePassword123!",
    "role": "user",
    "profile": {
      "department": "Sales",
      "location": "Chicago",
      "phone": "+1-555-0123"
    },
    "preferences": {
      "timezone": "America/Chicago",
      "locale": "en-US",
      "notifications": {
        "email": true,
        "in_app": true
      }
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": "user_new1234567890ab",
      "email": "new.user@acme.com",
      "name": "New User",
      "role": "user",
      "status": "active",
      "tenant_id": "tenant_1234567890abcdef",
      "created_at": "2025-11-24T10:00:00Z",
      "last_login_at": null
    },
    "welcome_email_sent": true,
    "temporary_password": false
  }
}
```

## Backup and Migration

### Create Tenant Backup

**POST** `/tenants/{tenant_id}/backup`

Create comprehensive backup of tenant data and schema.

**Request:**
```json
{
  "backup_type": "full",
  "include_schema": true,
  "include_data": true,
  "include_files": true,
  "compression": true,
  "encryption": true,
  "storage_location": "s3://tenant-backups/",
  "retention_days": 90,
  "notification_settings": {
    "email_on_completion": true,
    "webhook_url": "https://acme.com/webhooks/backup"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "backup_id": "backup_1234567890abcdef",
    "status": "in_progress",
    "started_at": "2025-11-24T10:00:00Z",
    "estimated_completion": "2025-11-24T10:25:00Z",
    "configuration": {
      "backup_type": "full",
      "includes": ["schema", "data", "files"],
      "compression": true,
      "encryption": true
    },
    "progress": {
      "percentage": 0,
      "current_step": "schema_export",
      "estimated_size_gb": 2.5
    },
    "storage_location": "s3://tenant-backups/acme_corp_20251124_100000.gz"
  }
}
```

### Get Backup Status

**GET** `/tenants/{tenant_id}/backups/{backup_id}`

Retrieve status and progress of tenant backup.

**Response:**
```json
{
  "status": "success",
  "data": {
    "backup_id": "backup_1234567890abcdef",
    "status": "completed",
    "started_at": "2025-11-24T10:00:00Z",
    "completed_at": "2025-11-24T10:18:00Z",
    "duration_minutes": 18,
    "result": {
      "backup_size_gb": 2.1,
      "compressed_size_gb": 0.8,
      "compression_ratio": 0.38,
      "tables_backed_up": 15,
      "rows_backed_up": 12450,
      "files_backed_up": 1250,
      "checksum": "sha256:a1b2c3d4e5f6...",
      "storage_path": "s3://tenant-backups/acme_corp_20251124_100000.gz"
    },
    "verification": {
      "integrity_check": "passed",
      "data_sample_verified": true,
      "schema_validation": "passed"
    }
  }
}
```

### Restore Tenant from Backup

**POST** `/tenants/{tenant_id}/restore`

Restore tenant data from backup.

**Request:**
```json
{
  "backup_id": "backup_1234567890abcdef",
  "restore_options": {
    "overwrite_existing": false,
    "verify_integrity": true,
    "rollback_on_error": true,
    "dry_run": false
  },
  "target_schema": "acme_corp_restored",
  "selective_restore": {
    "tables": ["users", "documents"],
    "date_range": {
      "start": "2025-11-01T00:00:00Z",
      "end": "2025-11-24T10:00:00Z"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "restore_id": "restore_1234567890abcdef",
    "status": "in_progress",
    "started_at": "2025-11-24T10:00:00Z",
    "estimated_completion": "2025-11-24T10:45:00Z",
    "backup_source": {
      "backup_id": "backup_1234567890abcdef",
      "created_at": "2025-11-23T10:00:00Z",
      "backup_size_gb": 2.1
    },
    "restore_plan": [
      {
        "step": "schema_validation",
        "status": "completed",
        "completed_at": "2025-11-24T10:02:00Z"
      },
      {
        "step": "table_creation",
        "status": "in_progress",
        "estimated_completion": "2025-11-24T10:15:00Z"
      },
      {
        "step": "data_restoration",
        "status": "pending",
        "estimated_completion": "2025-11-24T10:35:00Z"
      },
      {
        "step": "index_rebuilding",
        "status": "pending",
        "estimated_completion": "2025-11-24T10:42:00Z"
      },
      {
        "step": "verification",
        "status": "pending",
        "estimated_completion": "2025-11-24T10:45:00Z"
      }
    ]
  }
}
```

## Analytics and Monitoring

### Get Tenant Analytics

**GET** `/tenants/{tenant_id}/analytics`

Retrieve comprehensive analytics for tenant.

**Query Parameters:**
- `period` (string, optional): Time period (7d, 30d, 90d)
- `metrics` (string, optional): Specific metrics to retrieve
- `segment` (string, optional): Data segmentation (users, storage, api)

**Response:**
```json
{
  "status": "success",
  "data": {
    "period": "30d",
    "tenant_id": "tenant_1234567890abcdef",
    "analytics": {
      "user_metrics": {
        "total_users": 245,
        "active_users_30d": 198,
        "new_users_30d": 32,
        "user_retention_rate": 0.91,
        "avg_session_duration_minutes": 45,
        "user_growth_rate": 0.15
      },
      "usage_metrics": {
        "api_calls_total": 462600,
        "api_calls_per_day_avg": 15420,
        "storage_growth_gb": 1.2,
        "peak_concurrent_users": 45,
        "avg_response_time_ms": 125
      },
      "feature_adoption": {
        "advanced_analytics": 0.78,
        "custom_integrations": 0.23,
        "api_access": 0.45,
        "gdpr_compliance": 1.0
      },
      "performance_metrics": {
        "uptime_percentage": 99.9,
        "error_rate": 0.002,
        "cache_hit_rate": 0.87,
        "database_query_avg_ms": 45
      }
    },
    "trends": {
      "user_growth": "increasing",
      "storage_usage": "steady",
      "api_usage": "increasing",
      "error_rate": "stable"
    }
  }
}
```

### Get Cross-Tenant Analytics

**GET** `/analytics/cross-tenant`

Retrieve aggregated analytics across multiple tenants (platform admin only).

**Query Parameters:**
- `tenant_ids` (string, optional): Comma-separated tenant IDs
- `period` (string, optional): Time period
- `metrics` (string, optional): Specific metrics
- `segment_by` (string, optional): Grouping field

**Response:**
```json
{
  "status": "success",
  "data": {
    "period": "30d",
    "tenants_included": 15,
    "aggregated_metrics": {
      "total_users": 5678,
      "active_users": 4234,
      "total_storage_gb": 234.5,
      "total_api_calls": 15420000,
      "average_response_time_ms": 145,
      "platform_uptime": 99.95
    },
    "tenant_comparison": [
      {
        "tenant_id": "tenant_1234567890abcdef",
        "name": "Acme Corporation",
        "user_count": 245,
        "storage_gb": 45.2,
        "api_calls": 462600,
        "growth_rate": 0.15
      }
    ],
    "platform_health": {
      "overall_status": "healthy",
      "resource_utilization": 0.67,
      "error_rate": 0.001,
      "performance_score": 94.2
    }
  }
}
```

## Error Codes Reference

### Tenant Management Errors (400)

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_tenant_config` | Tenant configuration is invalid | Check required fields and format |
| `schema_name_exists` | Schema name already exists | Choose a different schema name |
| `domain_already_used` | Domain is already assigned to another tenant | Choose a different domain |
| `limits_exceeded` | Requested limits exceed platform maximum | Reduce limits or upgrade plan |

### Schema Operation Errors (500)

| Code | Description | Resolution |
|------|-------------|------------|
| `schema_creation_failed` | Failed to create tenant schema | Check database permissions and disk space |
| `migration_failed` | Database migration failed | Check migration syntax and dependencies |
| `query_timeout` | Database query exceeded timeout limit | Optimize query or increase timeout |
| `connection_failed` | Cannot connect to tenant schema | Verify schema exists and permissions |

### Domain Resolution Errors (404)

| Code | Description | Resolution |
|------|-------------|------------|
| `tenant_not_found` | Tenant not found for domain | Verify domain configuration |
| `dns_resolution_failed` | DNS resolution failed for domain | Check DNS configuration |
| `ssl_certificate_error` | SSL certificate issue detected | Renew or update SSL certificate |

### Resource Limit Errors (429)

| Code | Description | Resolution |
|------|-------------|------------|
| `tenant_limit_exceeded` | Tenant resource limit exceeded | Upgrade tenant limits or reduce usage |
| `rate_limit_exceeded` | API rate limit exceeded | Reduce request frequency |
| `storage_quota_exceeded` | Storage quota exceeded | Clean up files or increase storage limit |
| `connection_pool_full` | Database connection pool full | Wait and retry, or increase pool size |

### Permission Errors (403)

| Code | Description | Resolution |
|------|-------------|------------|
| `tenant_access_denied` | Cannot access specified tenant | Check tenant membership and permissions |
| `schema_access_denied` | Cannot access database schema | Verify schema permissions |
| `admin_privileges_required` | Operation requires admin privileges | Grant appropriate admin permissions |
| `cross_tenant_access_denied` | Cannot access other tenant data | Stay within tenant scope |

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|---------|
| Tenant Creation | 10 requests | per hour |
| Tenant Queries | 100 requests | per minute |
| Domain Configuration | 20 requests | per hour |
| Resource Usage | 50 requests | per minute |
| Backup Operations | 5 requests | per hour |
| Schema Operations | 25 requests | per minute |

## Webhooks

### Tenant Events

- `tenant.created` - New tenant created and provisioned
- `tenant.updated` - Tenant configuration updated
- `tenant.suspended` - Tenant suspended for policy violation
- `tenant.deleted` - Tenant deletion scheduled or completed
- `tenant.limits.exceeded` - Tenant exceeded resource limits
- `tenant.backup.completed` - Tenant backup completed successfully
- `tenant.restored` - Tenant restored from backup

### Schema Events

- `schema.migration.started` - Database migration started
- `schema.migration.completed` - Database migration completed
- `schema.migration.failed` - Database migration failed
- `schema.performance.alert` - Schema performance issue detected

### Resource Events

- `resources.quota.warning` - Resource usage approaching limit
- `resources.quota.exceeded` - Resource quota exceeded
- `resources.scaled` - Tenant resources scaled up or down
- `resources.optimized` - Resource optimization applied

### Webhook Security

All webhook requests include:
- `X-Signature` header with HMAC signature
- `X-Tenant-ID` header with tenant identifier
- `X-Event-Type` header with event type
- Unique event ID for deduplication
- Timestamp for replay protection

---

**Related Documentation**: [Multi-Tenancy Overview](README.md) | [Core Platform API](../core-platform/api-reference.md) | [GDPR Compliance API](../gdpr-compliance/api-reference.md)