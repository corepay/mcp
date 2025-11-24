# Core Platform API Reference

## Overview

The Core Platform API provides comprehensive endpoints for system management, monitoring, database operations, caching, storage, and infrastructure management. All requests require authentication and appropriate system administration permissions.

## Authentication

Include your API key and version in the headers:
```http
Authorization: Bearer your-api-key
Content-Type: application/json
API-Version: 2025-11-17
```

**API Versioning**: This platform uses header-based versioning (Stripe-style). Include the `API-Version` header with your desired version date. If not provided, defaults to your account's configured version.

## Base URL
```
https://your-mcp-platform.com/api
```

## System Management

### Health Check

**GET** `/api/health`

Basic health check to verify system is operational.

**Response:**
```json
{
  "status": "success",
  "data": {
    "health": "healthy",
    "timestamp": "2025-11-24T10:00:00Z",
    "uptime_seconds": 86400,
    "version": "1.0.0"
  }
}
```

### Detailed Health Check

**GET** `/api/health/detailed`

Comprehensive health check with component status.

**Response:**
```json
{
  "status": "success",
  "data": {
    "overall": "healthy",
    "timestamp": "2025-11-24T10:00:00Z",
    "components": {
      "database": {
        "status": "healthy",
        "response_time_ms": 15,
        "connections": {
          "active": 45,
          "idle": 55,
          "max": 100
        }
      },
      "cache": {
        "status": "healthy",
        "response_time_ms": 2,
        "hit_rate": 0.87,
        "memory_usage_mb": 256
      },
      "storage": {
        "status": "healthy",
        "response_time_ms": 45,
        "available_space_gb": 1024,
        "total_files": 15420
      },
      "external_apis": {
        "status": "degraded",
        "services": {
          "payment_gateway": "healthy",
          "email_service": "degraded",
          "analytics": "healthy"
        }
      }
    },
    "metrics": {
      "active_users": 1234,
      "requests_per_minute": 450,
      "error_rate": 0.002
    }
  }
}
```

### System Metrics

**GET** `/api/metrics`

Retrieve system performance metrics.

**Query Parameters:**
- `period` (string, optional): Time period (1h, 24h, 7d, 30d)
- `metrics` (string, optional): Comma-separated list of metrics
- `granularity` (string, optional): Data granularity (minute, hour, day)

**Response:**
```json
{
  "status": "success",
  "data": {
    "period": "24h",
    "metrics": {
      "performance": {
        "response_time_p50": 250,
        "response_time_p95": 1200,
        "response_time_p99": 2400,
        "requests_per_second": 450,
        "throughput_mbps": 125.5
      },
      "system": {
        "cpu_usage_percent": 45.2,
        "memory_usage_mb": 4096,
        "memory_usage_percent": 62.8,
        "disk_usage_gb": 250,
        "disk_usage_percent": 78.5,
        "network_io_mbps": 85.3
      },
      "application": {
        "active_users": 1234,
        "concurrent_sessions": 892,
        "error_rate": 0.002,
        "cache_hit_rate": 0.87
      },
      "business": {
        "user_registrations": 45,
        "revenue_usd": 15420.50,
        "api_calls": 1542000,
        "storage_uploads_gb": 12.5
      }
    }
  }
}
```

### System Status

**GET** `/api/status`

Get current system status and maintenance information.

**Response:**
```json
{
  "status": "success",
  "data": {
    "system_status": "operational",
    "maintenance_scheduled": false,
    "incident_history": [
      {
        "id": "inc_1234567890abcdef",
        "title": "Payment Gateway Degradation",
        "status": "resolved",
        "severity": "medium",
        "created_at": "2025-11-23T14:30:00Z",
        "resolved_at": "2025-11-23T15:45:00Z",
        "impact": "Some payment processing delays"
      }
    ],
    "upcoming_maintenance": [],
    "service_disruptions": []
  }
}
```

## Database Management

### Execute Query

**POST** `/api/database/query`

Execute SQL query with safety restrictions.

**Request:**
```json
{
  "query": "SELECT COUNT(*) as total_users FROM users WHERE created_at >= $1",
  "parameters": ["2025-11-01T00:00:00Z"],
  "schema": "acme_corp",  // Optional: for multi-tenant queries
  "read_only": true,      // Safety constraint
  "timeout_ms": 5000
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
      [1234]
    ],
    "columns": ["total_users"],
    "schema": "acme_corp"
  }
}
```

### Get Database Schema

**GET** `/api/database/schema`

Retrieve database schema information.

**Query Parameters:**
- `schema` (string, optional): Specific schema to analyze
- `table` (string, optional): Specific table to analyze
- `include_indexes` (boolean, optional): Include index information

**Response:**
```json
{
  "status": "success",
  "data": {
    "schema": "acme_corp",
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
            "constraints": ["UNIQUE"]
          },
          {
            "name": "created_at",
            "type": "timestamp with time zone",
            "nullable": false,
            "default": "now()"
          }
        ],
        "indexes": [
          {
            "name": "users_pkey",
            "columns": ["id"],
            "type": "primary_key"
          },
          {
            "name": "users_email_idx",
            "columns": ["email"],
            "type": "btree",
            "unique": true
          }
        ],
        "row_count": 1234,
        "size_mb": 45.2
      }
    ]
  }
}
```

### Database Migration

**POST** `/api/database/migrate`

Run database migrations.

**Request:**
```json
{
  "schema": "acme_corp",
  "direction": "up",  // "up" or "down"
  "version": "20251124000101",  // Optional: specific migration version
  "dry_run": false
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
        "name": "Create user profiles",
        "execution_time_ms": 1250,
        "status": "success"
      },
      {
        "version": "20251124000102",
        "name": "Add user preferences",
        "execution_time_ms": 450,
        "status": "success"
      }
    ],
    "total_execution_time_ms": 1800,
    "schema_version": "20251124000102"
  }
}
```

## Cache Management

### Cache Statistics

**GET** `/api/cache/stats`

Retrieve cache performance and usage statistics.

**Response:**
```json
{
  "status": "success",
  "data": {
    "memory": {
      "used_memory_mb": 256,
      "max_memory_mb": 512,
      "usage_percent": 50.0,
      "overhead_memory_mb": 12.5
    },
    "keys": {
      "total_keys": 15420,
      "expired_keys": 1250,
      "evicted_keys": 45,
      "keyspace_hits": 125000,
      "keyspace_misses": 18500
    },
    "performance": {
      "hit_rate": 0.87,
      "average_response_time_ms": 2.1,
      "queries_per_second": 1250,
      "connections": {
        "active": 15,
        "idle": 5,
        "max": 20
      }
    },
    "distribution": {
      "user_sessions": 4520,
      "api_responses": 6780,
      "rate_limits": 2340,
      "config_cache": 1780
    }
  }
}
```

### Warm Cache

**POST** `/api/cache/warm`

Warm cache with specified keys or patterns.

**Request:**
```json
{
  "patterns": [
    "user:*:profile",
    "config:*",
    "rate_limits:*"
  ],
  "keys": [
    "popular_configs",
    "system_settings",
    "tenant_metadata:acme_corp"
  ],
  "concurrency": 10,
  "timeout_seconds": 30
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "warm_id": "warm_1234567890abcdef",
    "total_keys_processed": 1542,
    "successful_loads": 1489,
    "failed_loads": 53,
    "execution_time_seconds": 25.5,
    "cache_hits_added": 1489,
    "patterns_processed": 3,
    "keys_processed": 3
  }
}
```

### Clear Cache

**DELETE** `/api/cache/clear`

Clear cache entries matching criteria.

**Request Body:**
```json
{
  "pattern": "user:123:*",  // Optional: pattern to match
  "keys": [                // Optional: specific keys to clear
    "user:123:profile",
    "user:123:preferences"
  ],
  "scope": "tenant",       // "global", "tenant", "user"
  "tenant_id": "acme_corp"  // Required for tenant scope
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "cleared_keys_count": 15,
    "affected_patterns": ["user:123:*"],
    "execution_time_ms": 125,
    "memory_freed_mb": 2.5
  }
}
```

## Storage Management

### Storage Statistics

**GET** `/api/storage/stats`

Retrieve storage usage and performance statistics.

**Query Parameters:**
- `bucket` (string, optional): Specific storage bucket
- `prefix` (string, optional): Filter by key prefix
- `period` (string, optional): Time period for trends

**Response:**
```json
{
  "status": "success",
  "data": {
    "overview": {
      "total_files": 15420,
      "total_size_gb": 125.5,
      "total_size_bytes": 134737075200,
      "average_file_size_mb": 8.2,
      "last_modified": "2025-11-24T09:45:00Z"
    },
    "buckets": [
      {
        "name": "user_files",
        "file_count": 12500,
        "size_gb": 98.2,
        "largest_file_mb": 512,
        "most_common_type": "image/jpeg"
      },
      {
        "name": "temp_uploads",
        "file_count": 2340,
        "size_gb": 15.8,
        "largest_file_mb": 128,
        "most_common_type": "application/pdf"
      },
      {
        "name": "backups",
        "file_count": 580,
        "size_gb": 11.5,
        "largest_file_mb": 2048,
        "most_common_type": "application/gzip"
      }
    ],
    "trends": {
      "daily_uploads": 145,
      "daily_downloads": 892,
      "storage_growth_gb_per_day": 0.5,
      "bandwidth_usage_gb_per_day": 12.3
    }
  }
}
```

### Upload File

**POST** `/api/storage/upload`

Upload file to storage with processing options.

**Request (multipart/form-data):**
```
file: [binary file data]
key: "uploads/user_123/document.pdf"
metadata: {"category": "documents", "user_id": "123"}
processing: ["virus_scan", "thumbnail", "text_extraction"]
acl: "private"
content_type: "application/pdf"
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "file_id": "file_1234567890abcdef",
    "key": "uploads/user_123/document.pdf",
    "url": "https://storage.mcp-platform.com/uploads/user_123/document.pdf",
    "size_bytes": 2048576,
    "content_type": "application/pdf",
    "md5_hash": "d41d8cd98f00b204e9800998ecf8427e",
    "processing_results": {
      "virus_scan": "clean",
      "thumbnail_generated": true,
      "thumbnail_url": "https://storage.mcp-platform.com/thumbnails/user_123/document.pdf_thumb.jpg",
      "text_extracted": true,
      "word_count": 1542
    },
    "uploaded_at": "2025-11-24T10:00:00Z"
  }
}
```

### Generate Presigned URL

**GET** `/api/storage/url`

Generate presigned URL for client-side upload/download.

**Query Parameters:**
- `key` (string): File key/path
- `operation` (string): "upload" or "download"
- `expires_in` (integer, optional): URL expiration in seconds (default: 3600)
- `content_type` (string, optional): Expected content type (upload only)

**Response:**
```json
{
  "status": "success",
  "data": {
    "url": "https://storage.mcp-platform.com/uploads/temp/doc_123.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...",
    "expires_at": "2025-11-24T11:00:00Z",
    "headers": {
      "Content-Type": "application/pdf",
      "X-Amz-Security-Token": "..."
    },
    "key": "uploads/temp/doc_123.pdf",
    "operation": "upload"
  }
}
```

## Secrets Management

### Get Secret

**GET** `/api/secrets/{path}`

Retrieve secret from Vault.

**Query Parameters:**
- `version` (integer, optional): Specific version of secret
- `tenant_id` (string, optional): Tenant context for secret

**Response:**
```json
{
  "status": "success",
  "data": {
    "path": "database/credentials/production",
    "version": 3,
    "created_at": "2025-11-20T10:00:00Z",
    "data": {
      "username": "prod_user",
      "password": "generated_password_123",
      "host": "db.production.mcp-platform.com",
      "port": 5432,
      "database": "mcp_production"
    },
    "metadata": {
      "created_by": "system",
      "last_rotated": "2025-11-15T10:00:00Z",
      "rotation_policy": "monthly"
    }
  }
}
```

### Set Secret

**POST** `/api/secrets/{path}`

Store secret in Vault.

**Request:**
```json
{
  "data": {
    "api_key": "sk_live_1234567890abcdef",
    "webhook_secret": "whsec_1234567890abcdef",
    "environment": "production"
  },
  "ttl": "720h",  // Optional: time to live
  "metadata": {
    "owner": "billing_team",
    "purpose": "stripe_integration",
    "rotation_policy": "quarterly"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "path": "api_keys/stripe/production",
    "version": 4,
    "created_at": "2025-11-24T10:00:00Z",
    "ttl": "720h"
  }
}
```

### Rotate Secret

**POST** `/api/secrets/{path}/rotate`

Rotate secret value automatically.

**Response:**
```json
{
  "status": "success",
  "data": {
    "path": "database/credentials/production",
    "old_version": 3,
    "new_version": 4,
    "rotated_at": "2025-11-24T10:00:00Z",
    "changes": [
      {
        "field": "password",
        "old_value": "[REDACTED]",
        "new_value": "[REDACTED]"
      }
    ]
  }
}
```

## Multi-Tenancy Management

### Create Tenant

**POST** `/api/tenants`

Create new tenant with isolated environment.

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
      "features": {
        "advanced_analytics": true,
        "custom_integrations": true,
        "priority_support": true
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
      "api_calls_per_day": 100000
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
      "status": "active",
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
    }
  }
}
```

### Get Tenant Information

**GET** `/api/tenants/{tenant_id}`

Retrieve tenant configuration and status.

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
      }
    },
    "features": {
      "multi_tenancy": true,
      "gdpr_compliance": true,
      "advanced_analytics": true,
      "custom_integrations": true,
      "priority_support": true
    }
  }
}
```

## Event Management

### Broadcast Event

**POST** `/api/events/broadcast`

Broadcast event to subscribed clients.

**Request:**
```json
{
  "event": {
    "type": "user_updated",
    "data": {
      "user_id": "user_1234567890abcdef",
      "changes": {
        "email": "newemail@example.com",
        "updated_at": "2025-11-24T10:00:00Z"
      }
    },
    "targets": {
      "tenant_id": "acme_corp",
      "channels": ["user_management", "audit_log"],
      "user_ids": ["user_1234567890abcdef", "user_fedcba0987654321"]
    },
    "metadata": {
      "source": "admin_panel",
      "initiator": "admin_user_123",
      "priority": "high"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "event_id": "evt_1234567890abcdef",
    "broadcast_at": "2025-11-24T10:00:00Z",
    "recipients": {
      "total_subscribers": 15,
      "delivered_count": 14,
      "failed_count": 1,
      "channels": ["websocket", "webhook", "email"]
    }
  }
}
```

## Error Codes Reference

### System Errors (500)

| Code | Description | Resolution |
|------|-------------|------------|
| `database_connection_failed` | Unable to connect to database | Check database configuration and connectivity |
| `cache_unavailable` | Redis cache is not responding | Check Redis service status and network connectivity |
| `storage_service_error` | Object storage service error | Verify storage credentials and service availability |
| `vault_unavailable` | Secrets vault is not accessible | Check Vault service status and authentication |

### Validation Errors (400)

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_query` | SQL query contains unsafe operations | Use only SELECT queries or modify query to be safe |
| `invalid_cache_pattern` | Cache pattern syntax invalid | Use proper Redis pattern syntax |
| `invalid_tenant_config` | Tenant configuration is invalid | Check required fields and format |
| `invalid_secret_path` | Secret path format is invalid | Use proper Vault path format |

### Permission Errors (403)

| Code | Description | Resolution |
|------|-------------|------------|
| `insufficient_permissions` | Lacks required system permissions | Grant appropriate system administration permissions |
| `tenant_access_denied` | Cannot access specified tenant | Check tenant membership and permissions |
| `schema_access_denied` | Cannot access database schema | Verify schema permissions and multi-tenancy context |

### Rate Limiting Errors (429)

| Code | Description | Resolution |
|------|-------------|------------|
| `api_rate_limit_exceeded` | Too many API requests | Reduce request frequency or upgrade rate limits |
| `query_rate_limit_exceeded` | Too many database queries | Implement query optimization or caching |
| `upload_rate_limit_exceeded` | Too many file uploads | Implement upload throttling or use batch processing |

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|---------|
| System Health | 1000 requests | per minute |
| Database Query | 100 requests | per minute |
| Cache Operations | 500 requests | per minute |
| Storage Upload | 100 requests | per minute |
| Secrets Management | 50 requests | per minute |
| Event Broadcast | 200 requests | per minute |

## Webhooks

### System Events

- `system.health_check` - System health status changes
- `system.maintenance_started` - Maintenance window started
- `system.maintenance_completed` - Maintenance window completed
- `tenant.created` - New tenant created
- `tenant.suspended` - Tenant suspended or deactivated
- `database.migration_completed` - Database migration finished
- `storage.quota_exceeded` - Storage quota limit exceeded

### Webhook Security

All webhook requests include:
- `X-Signature` header with HMAC signature
- `X-Event-Type` header with event type
- Unique event ID for deduplication
- Timestamp for replay protection

---

**Related Documentation**: [Core Platform Overview](README.md) | [Multi-Tenancy Guide](../multi-tenancy/README.md) | [Developer Guide](../developers/README.md)