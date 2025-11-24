# Object Storage API Reference

## Overview

The Object Storage API provides comprehensive endpoints for file upload/download, management, access control, and analytics across multiple storage backends. All requests require authentication and appropriate storage permissions.

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

## File Upload Operations

### Upload Single File

**POST** `/storage/upload`

Upload file with automatic processing and metadata extraction.

**Request (multipart/form-data):**
```
file: [binary file data]
key: users/user123/documents/report.pdf
content_type: application/pdf
metadata: {"user_id": "user-uuid", "category": "financial"}
processing: ["virus_scan", "thumbnail", "text_extraction"]
acl: private
encryption: AES256
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "file": {
      "id": "file_1234567890abcdef",
      "key": "users/user123/documents/report.pdf",
      "size_bytes": 2048576,
      "content_type": "application/pdf",
      "etag": "\"d41d8cd98f00b204e9800998ecf8427e\"",
      "uploaded_at": "2025-11-24T10:00:00Z"
    },
    "processing_results": {
      "virus_scan": "clean",
      "thumbnail_generated": true,
      "thumbnail_url": "https://storage.mcp-platform.com/thumbnails/report_thumb.jpg",
      "text_extracted": true,
      "word_count": 1542,
      "language_detected": "en"
    },
    "storage_info": {
      "backend": "s3",
      "bucket": "mcp-user-files",
      "storage_class": "STANDARD",
      "encryption": "AES256",
      "version_id": "version_xyz123"
    }
  }
}
```

### Start Multipart Upload

**POST** `/storage/upload/multipart`

Initiate multipart upload for large files (>100MB).

**Request:**
```json
{
  "upload": {
    "key": "backups/database_backup_20251124.sql.gz",
    "content_type": "application/gzip",
    "part_size": 104857600,
    "metadata": {
      "backup_type": "full_database",
      "created_at": "2025-11-24T10:00:00Z",
      "estimated_size": 2500000000
    },
    "storage_options": {
      "encryption": "AES256",
      "storage_class": "STANDARD_IA",
      "server_side_encryption": true
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "upload_id": "upload_1234567890abcdef",
    "key": "backups/database_backup_20251124.sql.gz",
    "part_size": 104857600,
    "estimated_parts": 24,
    "expires_at": "2025-11-25T10:00:00Z",
    "upload_url": "https://s3.amazonaws.com/mcp-backups/database_backup_20251124.sql.gz?uploadId=upload_1234567890abcdef"
  }
}
```

### Upload Part

**PUT** `/storage/upload/part`

Upload individual part of multipart upload.

**Request:**
```json
{
  "part": {
    "upload_id": "upload_1234567890abcdef",
    "part_number": 1,
    "data": "base64_encoded_binary_data",
    "md5_checksum": "d41d8cd98f00b204e9800998ecf8427e"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "part_number": 1,
    "etag": "\"part_etag_12345\"",
    "size_bytes": 104857600,
    "upload_progress": {
      "completed_parts": 1,
      "total_parts": 24,
      "percentage": 4.17
    }
  }
}
```

### Complete Multipart Upload

**POST** `/storage/upload/complete`

Complete multipart upload and combine all parts.

**Request:**
```json
{
  "completion": {
    "upload_id": "upload_1234567890abcdef",
    "parts": [
      {
        "part_number": 1,
        "etag": "\"part_etag_12345\""
      },
      {
        "part_number": 2,
        "etag": "\"part_etag_67890\""
      }
    ]
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "file": {
      "id": "file_fedcba0987654321",
      "key": "backups/database_backup_20251124.sql.gz",
      "size_bytes": 2500000000,
      "content_type": "application/gzip",
      "completed_at": "2025-11-24T10:25:00Z",
      "etag": "\"complete_file_etg_abc123\""
    },
    "upload_summary": {
      "total_parts": 24,
      "successful_parts": 24,
      "failed_parts": 0,
      "total_upload_time_seconds": 1500,
      "average_speed_mbps": 13.3
    }
  }
}
```

## File Download Operations

### Download File

**GET** `/storage/download/{key}`

Download file with optional range and streaming support.

**Query Parameters:**
- `range` (string, optional): Byte range (e.g., "bytes=0-1023")
- `version_id` (string, optional): Specific version to download
- `disposition` (string, optional): Content-Disposition header
- `cache_control` (string, optional): Cache-Control header

**Response Headers:**
```http
Content-Type: application/pdf
Content-Length: 2048576
Content-Disposition: attachment; filename="report.pdf"
Accept-Ranges: bytes
ETag: "d41d8cd98f00b204e9800998ecf8427e"
Last-Modified: Mon, 24 Nov 2025 10:00:00 GMT
```

**Response:**
Binary file data or streaming response based on request.

### Get File Information

**GET** `/storage/files/{key}`

Retrieve detailed file metadata and information.

**Query Parameters:**
- `version_id` (string, optional): Specific version information
- `include_processing` (boolean, optional): Include processing results
- `include_access_stats` (boolean, optional): Include access statistics

**Response:**
```json
{
  "status": "success",
  "data": {
    "file": {
      "id": "file_1234567890abcdef",
      "key": "users/user123/documents/report.pdf",
      "size_bytes": 2048576,
      "content_type": "application/pdf",
      "etag": "\"d41d8cd98f00b204e9800998ecf8427e\"",
      "created_at": "2025-11-24T10:00:00Z",
      "modified_at": "2025-11-24T10:00:00Z",
      "storage_class": "STANDARD"
    },
    "metadata": {
      "user_id": "user-uuid",
      "category": "financial",
      "sensitivity": "internal",
      "department": "finance",
      "original_filename": "Q4_Report.pdf"
    },
    "processing_results": {
      "virus_scan": {
        "status": "clean",
        "engine": "clamav",
        "scanned_at": "2025-11-24T10:01:00Z"
      },
      "thumbnail": {
        "generated": true,
        "url": "https://storage.mcp-platform.com/thumbnails/report_thumb.jpg",
        "sizes": [150, 300, 600]
      },
      "text_extraction": {
        "extracted": true,
        "word_count": 1542,
        "language": "en",
        "page_count": 12
      }
    },
    "access_stats": {
      "download_count": 25,
      "last_accessed": "2025-11-24T09:30:00Z",
      "unique_viewers": 8,
      "total_bandwidth_bytes": 52144000
    }
  }
}
```

## File Management Operations

### Copy File

**POST** `/storage/copy`

Copy file with optional processing and metadata updates.

**Request:**
```json
{
  "copy": {
    "source_key": "documents/drafts/report_draft.pdf",
    "destination_key": "documents/final/Q4_Final_Report.pdf",
    "metadata": {
      "status": "final",
      "approved_by": "manager-uuid",
      "approved_at": "2025-11-24T10:00:00Z"
    },
    "processing": [
      {
        "type": "watermark",
        "config": {
          "text": "CONFIDENTIAL - ACME CORP",
          "position": "bottom_right",
          "opacity": 0.7,
          "font_size": 24
        }
      },
      {
        "type": "compression",
        "config": {
          "quality": 85,
          "optimize_for_web": true
        }
      }
    ],
    "storage_options": {
      "storage_class": "STANDARD",
      "encryption": "AES256"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "copy_job": {
      "id": "copy_job_1234567890abcdef",
      "status": "completed",
      "started_at": "2025-11-24T10:00:00Z",
      "completed_at": "2025-11-24T10:02:00Z",
      "duration_seconds": 120
    },
    "source_file": {
      "key": "documents/drafts/report_draft.pdf",
      "size_bytes": 2048576,
      "etag": "\"source_etg_abc123\""
    },
    "destination_file": {
      "key": "documents/final/Q4_Final_Report.pdf",
      "size_bytes": 1843200,
      "etag": "\"dest_etg_def456\"",
      "processing_applied": ["watermark", "compression"]
    },
    "processing_results": {
      "watermark_added": true,
      "compression_ratio": 0.90,
      "quality_maintained": true
    }
  }
}
```

### Move File

**POST** `/storage/move`

Move file to new location with metadata updates.

**Request:**
```json
{
  "move": {
    "source_key": "temp/uploads/user123/report.pdf",
    "destination_key": "documents/user123/final/Q4_Report.pdf",
    "metadata_update": {
      "status": "processed",
      "moved_at": "2025-11-24T10:00:00Z",
      "moved_by": "system"
    },
    "preserve_metadata": true,
    "create_intermediate_folders": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "move_operation": {
      "source_key": "temp/uploads/user123/report.pdf",
      "destination_key": "documents/user123/final/Q4_Report.pdf",
      "moved_at": "2025-11-24T10:00:00Z",
      "operation": "move"
    },
    "file": {
      "key": "documents/user123/final/Q4_Report.pdf",
      "size_bytes": 2048576,
      "content_type": "application/pdf",
      "metadata": {
        "status": "processed",
        "moved_at": "2025-11-24T10:00:00Z",
        "moved_by": "system"
      }
    }
  }
}
```

### Batch Operations

**POST** `/storage/batch`

Execute multiple file operations in a single request.

**Request:**
```json
{
  "batch": {
    "operations": [
      {
        "type": "copy",
        "source": "temp/uploads/user123/",
        "destination": "permanent/user123/documents/",
        "preserve_structure": true
      },
      {
        "type": "delete",
        "pattern": "temp/cache/*_old",
        "filters": {
          "older_than_days": 30,
          "size_larger_than_mb": 10
        }
      },
      {
        "type": "move",
        "pattern": "processing/*.ready",
        "destination": "completed/",
        "create_intermediate_folders": true
      },
      {
        "type": "update_metadata",
        "pattern": "documents/financial/*",
        "metadata": {
          "department": "finance",
          "retention_days": 2555
        }
      }
    ],
    "options": {
      "continue_on_error": true,
      "max_concurrent_operations": 5,
      "dry_run": false,
      "notification_on_completion": true
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "batch_id": "batch_1234567890abcdef",
    "status": "completed",
    "started_at": "2025-11-24T10:00:00Z",
    "completed_at": "2025-11-24T10:05:00Z",
    "summary": {
      "total_operations": 4,
      "successful": 4,
      "failed": 0,
      "files_affected": 156,
      "total_size_processed_mb": 2340
    },
    "operation_results": [
      {
        "operation": "copy",
        "status": "success",
        "files_processed": 45,
        "total_size_mb": 890
      },
      {
        "operation": "delete",
        "status": "success",
        "files_deleted": 78,
        "space_freed_mb": 1250
      },
      {
        "operation": "move",
        "status": "success",
        "files_moved": 23,
        "total_size_mb": 156
      },
      {
        "operation": "update_metadata",
        "status": "success",
        "files_updated": 10,
        "total_size_mb": 44
      }
    ]
  }
}
```

### Delete File

**DELETE** `/storage/files/{key}`

Delete file or specific version.

**Query Parameters:**
- `version_id` (string, optional): Delete specific version
- `bypass_governance` (boolean, optional): Bypass governance retention
- `confirm` (string, required): "DELETE_CONFIRMED" for confirmation

**Response:**
```json
{
  "status": "success",
  "data": {
    "deleted_file": {
      "key": "temp/old_document.pdf",
      "deleted_at": "2025-11-24T10:00:00Z",
      "size_bytes": 1024000,
      "version_id": "version_xyz123"
    },
    "deletion_type": "permanent",
    "space_freed_bytes": 1024000,
    "cleanup_completed": true
  }
}
```

## Access Control and Security

### Generate Presigned URL

**GET** `/storage/presigned-url`

Generate secure, time-limited URL for file access.

**Query Parameters:**
- `key` (string, required): File key
- `operation` (string, required): "upload" or "download"
- `expires_in` (integer, optional): URL expiration in seconds (default: 3600)
- `content_type` (string, optional): Expected content type (upload only)
- `content_length` (integer, optional): Expected content length (upload only)

**Response:**
```json
{
  "status": "success",
  "data": {
    "url": "https://storage.mcp-platform.com/documents/report.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...",
    "expires_at": "2025-11-24T11:00:00Z",
    "method": "GET",
    "headers": {
      "Content-Type": "application/pdf",
      "X-Amz-Security-Token": "..."
    },
    "key": "documents/report.pdf",
    "operation": "download",
    "access_conditions": {
      "ip_whitelist": ["203.0.113.0/24"],
      "user_agent_required": true
    }
  }
}
```

### Generate Presigned POST

**POST** `/storage/presigned-post`

Generate presigned POST for direct browser uploads.

**Request:**
```json
{
  "presigned_post": {
    "key": "uploads/${filename}",
    "expires_in": 3600,
    "content_type": "image/jpeg",
    "max_content_length": 10485760,
    "metadata": {
      "user_id": "user-uuid",
      "upload_source": "web"
    },
    "conditions": [
      {"acl": "private"},
      {"content-type": "image/jpeg"},
      ["content-length-range", 0, 10485760]
    ]
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "url": "https://storage.mcp-platform.com/",
    "fields": {
      "key": "uploads/${filename}",
      "AWSAccessKeyId": "AKIA...",
      "policy": "eyJ...",
      "signature": "xyz123...",
      "Content-Type": "image/jpeg"
    },
    "expires_at": "2025-11-24T11:00:00Z",
    "max_file_size": 10485760
  }
}
```

### Set Object ACL

**PUT** `/storage/files/{key}/acl`

Set access control list for specific file.

**Request:**
```json
{
  "acl": {
    "owner": {
      "id": "user123",
      "display_name": "John Doe"
    },
    "access_controls": [
      {
        "grantee": {
          "type": "CanonicalUser",
          "id": "user123"
        },
        "permission": "FULL_CONTROL"
      },
      {
        "grantee": {
          "type": "CanonicalUser",
          "id": "user456"
        },
        "permission": "READ"
      },
      {
        "grantee": {
          "type": "Group",
          "uri": "http://acs.amazonaws.com/groups/global/AllUsers"
        },
        "permission": "READ"
      }
    ]
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "key": "users/user123/private/document.pdf",
    "acl_updated": true,
    "owner": "user123",
    "access_controls_count": 3,
    "updated_at": "2025-11-24T10:00:00Z"
  }
}
```

### Set Bucket Policy

**PUT** `/storage/buckets/{bucket}/policy`

Set comprehensive bucket access policy.

**Request:**
```json
{
  "policy": {
    "version": "2012-10-17",
    "statements": [
      {
        "effect": "Allow",
        "principals": ["arn:aws:iam::123456789012:user/lawyers"],
        "actions": ["s3:GetObject", "s3:PutObject"],
        "resources": ["arn:aws:s3:::secure-documents/legal/*"],
        "conditions": {
          "IpAddress": {"aws:SourceIp": ["203.0.113.0/24"]},
          "StringEquals": {"s3:prefix": ["legal/"]},
          "DateGreaterThan": {"aws:CurrentTime": "2025-01-01T00:00:00Z"}
        }
      },
      {
        "effect": "Deny",
        "principals": ["*"],
        "actions": ["s3:DeleteObject"],
        "resources": ["arn:aws:s3:::secure-documents/legal/*"],
        "conditions": {
          "StringNotEquals": {"aws:username": ["admin", "legal_admin"]}
        }
      }
    ]
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "bucket": "secure-documents",
    "policy_applied": true,
    "statements_count": 2,
    "validated": true,
    "applied_at": "2025-11-24T10:00:00Z"
  }
}
```

## Versioning and Lifecycle

### List Object Versions

**GET** `/storage/files/{key}/versions`

List all versions of a specific file.

**Query Parameters:**
- `limit` (integer, optional): Maximum versions to return
- `include_deleted` (boolean, optional): Include delete markers
- `sort_order` (string, optional): "asc" or "desc" by last modified

**Response:**
```json
{
  "status": "success",
  "data": {
    "key": "documents/agreement.pdf",
    "versions": [
      {
        "version_id": "version_abc123",
        "is_latest": true,
        "last_modified": "2025-11-24T10:00:00Z",
        "size_bytes": 2048576,
        "etag": "\"etag_abc123\"",
        "storage_class": "STANDARD",
        "delete_marker": false
      },
      {
        "version_id": "version_def456",
        "is_latest": false,
        "last_modified": "2025-11-23T15:30:00Z",
        "size_bytes": 1992294,
        "etag": "\"etag_def456\"",
        "storage_class": "STANDARD",
        "delete_marker": false
      }
    ],
    "total_versions": 2,
    "has_more": false
  }
}
```

### Restore Object Version

**POST** `/storage/files/{key}/restore`

Restore specific version of a file.

**Request:**
```json
{
  "restore": {
    "version_id": "version_def456",
    "restore_options": {
      "create_new_version": true,
      "preserve_current": true,
      "metadata": {
        "restored_from_version": "version_def456",
        "restored_by": "admin-uuid",
        "restore_reason": "incorrect_deletion",
        "restore_date": "2025-11-24T10:00:00Z"
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
    "restore_operation": {
      "source_key": "documents/agreement.pdf",
      "source_version": "version_def456",
      "restored_key": "documents/agreement.pdf",
      "new_version_id": "version_ghi789",
      "restored_at": "2025-11-24T10:00:00Z",
      "restore_type": "version_restoration"
    },
    "restored_file": {
      "key": "documents/agreement.pdf",
      "version_id": "version_ghi789",
      "size_bytes": 1992294,
      "content_restored": true,
      "metadata_applied": true
    }
  }
}
```

### Create Lifecycle Rule

**POST** `/storage/lifecycle/rules`

Create automated lifecycle management rule.

**Request:**
```json
{
  "rule": {
    "name": "financial_documents_retention",
    "status": "enabled",
    "filter": {
      "prefix": "documents/financial/",
      "tags": {
        "document_type": "financial",
        "retention_class": "regulated"
      }
    },
    "transitions": [
      {
        "days": 30,
        "storage_class": "STANDARD_IA"
      },
      {
        "days": 90,
        "storage_class": "GLACIER"
      },
      {
        "days": 365,
        "storage_class": "DEEP_ARCHIVE"
      }
    ],
    "expiration": {
      "days": 2555
    },
    "abort_incomplete_multipart_upload": {
      "days_after_initiation": 7
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "rule": {
      "id": "lifecycle_rule_1234567890abcdef",
      "name": "financial_documents_retention",
      "status": "active",
      "created_at": "2025-11-24T10:00:00Z"
    },
    "schedule": {
      "transitions": [
        {"days": 30, "storage_class": "STANDARD_IA"},
        {"days": 90, "storage_class": "GLACIER"},
        {"days": 365, "storage_class": "DEEP_ARCHIVE"}
      ],
      "expiration": {"days": 2555}
    },
    "estimated_savings": {
      "monthly_cost_reduction": 15.75,
      "currency": "USD"
    }
  }
}
```

## Search and Analytics

### Search Storage

**POST** `/storage/search`

Search files by content, metadata, and properties.

**Request:**
```json
{
  "search": {
    "query": "financial report Q4 2025 revenue",
    "filters": {
      "content_types": ["application/pdf", "application/vnd.ms-excel"],
      "date_range": {
        "start": "2025-10-01T00:00:00Z",
        "end": "2025-12-31T23:59:59Z"
      },
      "size_range": {
        "min_bytes": 1024,
        "max_bytes": 52428800
      },
      "tags": {
        "department": "finance",
        "sensitivity": "internal"
      },
      "user_id": "user-uuid"
    },
    "search_options": {
      "include_content": true,
      "highlight_matches": true,
      "fuzzy_matching": true,
      "rank_by_relevance": true,
      "max_results": 50
    },
    "pagination": {
      "page": 1,
      "page_size": 20
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "search_results": [
      {
        "file": {
          "key": "documents/finance/Q4_2025_Report.pdf",
          "size_bytes": 2048576,
          "content_type": "application/pdf",
          "last_modified": "2025-11-15T10:00:00Z"
        },
        "relevance_score": 0.95,
        "matches": {
          "title": ["Q4", "2025", "Report"],
          "content": ["financial", "revenue"],
          "metadata": ["department: finance"]
        },
        "highlights": {
          "content": "...<mark>financial</mark> report showing <mark>revenue</mark> growth...",
          "title": "<mark>Q4</mark> <mark>2025</mark> <mark>Report</mark>"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total_results": 3,
      "total_pages": 1,
      "has_next": false
    },
    "search_metadata": {
      "query_time_ms": 45,
      "total_files_searched": 1250,
      "filters_applied": 5
    }
  }
}
```

### Get Storage Analytics

**GET** `/storage/analytics`

Retrieve comprehensive storage usage and performance analytics.

**Query Parameters:**
- `period` (string, optional): Time period (7d, 30d, 90d)
- `metrics` (string, optional): Comma-separated metrics
- `dimensions` (string, optional): Comma-separated dimensions
- `filters` (string, optional): JSON-encoded filters

**Response:**
```json
{
  "status": "success",
  "data": {
    "period": "30d",
    "generated_at": "2025-11-24T10:00:00Z",
    "overview": {
      "total_storage_gb": 1250.5,
      "total_files": 15420,
      "total_buckets": 8,
      "daily_growth_gb": 2.3,
      "projected_monthly_growth_gb": 69.0
    },
    "storage_breakdown": {
      "by_bucket": [
        {
          "bucket": "user-uploads",
          "size_gb": 456.2,
          "files_count": 6780,
          "growth_rate_30d": 0.12
        },
        {
          "bucket": "documents",
          "size_gb": 320.1,
          "files_count": 3456,
          "growth_rate_30d": 0.08
        }
      ],
      "by_storage_class": {
        "STANDARD": {"size_gb": 890.3, "files": 12450},
        "STANDARD_IA": {"size_gb": 234.5, "files": 2340},
        "GLACIER": {"size_gb": 125.7, "files": 620}
      },
      "by_content_type": {
        "application/pdf": {"size_gb": 456.8, "files": 3456},
        "image/jpeg": {"size_gb": 234.2, "files": 5670},
        "video/mp4": {"size_gb": 345.1, "files": 234}
      }
    },
    "performance_metrics": {
      "requests": {
        "total_30d": 1542000,
        "daily_average": 51400,
        "peak_daily": 125000,
        "error_rate": 0.002
      },
      "latency": {
        "p50_ms": 45,
        "p95_ms": 125,
        "p99_ms": 245,
        "max_ms": 1200
      },
      "throughput": {
        "upload_mbps": 125.5,
        "download_mbps": 245.8,
        "peak_upload_mbps": 450.2
      }
    },
    "cost_analysis": {
      "storage_cost_monthly": 2850.75,
      "request_cost_monthly": 125.50,
      "data_transfer_cost_monthly": 456.25,
      "total_monthly_cost": 3432.50,
      "cost_per_gb_month": 2.74
    }
  }
}
```

### Monitor Performance

**GET** `/storage/performance`

Get real-time performance monitoring and alerts.

**Query Parameters:**
- `time_window` (string, optional): Time window (1h, 24h, 7d)
- `metrics` (string, optional): Specific metrics to monitor
- `alerts` (boolean, optional): Include alert configuration

**Response:**
```json
{
  "status": "success",
  "data": {
    "time_window": "24h",
    "current_metrics": {
      "upload_speed_mbps": 145.2,
      "download_speed_mbps": 267.8,
      "latency_p50_ms": 42,
      "latency_p95_ms": 118,
      "latency_p99_ms": 234,
      "error_rate": 0.0015,
      "active_uploads": 23,
      "active_downloads": 156
    },
    "performance_trends": {
      "hourly_averages": [
        {
          "hour": "2025-11-24T09:00:00Z",
          "upload_mbps": 123.4,
          "download_mbps": 245.6,
          "error_rate": 0.0012
        }
      ]
    },
    "alerts": [
      {
        "type": "performance_warning",
        "metric": "latency_p95_ms",
        "current_value": 118,
        "threshold": 150,
        "status": "normal",
        "last_triggered": null
      },
      {
        "type": "capacity_warning",
        "metric": "storage_utilization_percent",
        "current_value": 67.5,
        "threshold": 80.0,
        "status": "monitoring",
        "projected_threshold_date": "2026-02-15T00:00:00Z"
      }
    ]
  }
}
```

## Error Codes Reference

### Upload Errors (400)

| Code | Description | Resolution |
|------|-------------|------------|
| `file_too_large` | File exceeds size limit | Use multipart upload or reduce file size |
| `invalid_file_type` | File type not allowed | Check allowed file types and content-type |
| `virus_detected` | File contains malware | Clean file and upload again |
| `storage_quota_exceeded` | User or system quota exceeded | Delete old files or increase storage quota |

### Download Errors (404)

| Code | Description | Resolution |
|------|-------------|------------|
| `file_not_found` | File does not exist | Verify file key and check if file was deleted |
| `version_not_found` | Specific file version not found | Check version ID and list available versions |
| `access_denied` | No permission to access file | Verify user permissions and file ACLs |
| `presigned_url_expired` | Presigned URL has expired | Generate new presigned URL |

### Permission Errors (403)

| Code | Description | Resolution |
|------|-------------|------------|
| `insufficient_permissions` | User lacks required permissions | Grant appropriate storage permissions |
| `invalid_acl` | Invalid ACL configuration | Check ACL syntax and required fields |
| `policy_violation` | Request violates bucket policy | Review bucket policy and adjust request |
| `signature_mismatch` | Invalid signature for presigned URL | Generate new presigned URL with correct credentials |

### Storage Errors (500)

| Code | Description | Resolution |
|------|-------------|------------|
| `storage_backend_error` | Backend storage service error | Check storage service status and connectivity |
| `multipart_upload_expired` | Multipart upload expired | Restart multipart upload process |
| `concurrent_modification` | File modified during operation | Retry operation with latest file version |
| `internal_server_error` | Unexpected system error | Contact support with error details |

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|---------|
| File Upload | 100 requests | per minute |
| File Download | 500 requests | per minute |
| Presigned URL | 50 requests | per minute |
| Search | 25 requests | per minute |
| Analytics | 10 requests | per minute |
| Batch Operations | 5 requests | per minute |

## Webhooks

### Storage Events

- `file.uploaded` - File successfully uploaded
- `file.downloaded` - File downloaded (first time per user)
- `file.deleted` - File permanently deleted
- `file.processed` - File processing completed
- `virus.detected` - Malware detected in uploaded file
- `quota.warning` - Storage quota threshold reached
- `lifecycle.transition` - File moved to different storage class

### Webhook Security

All webhook requests include:
- `X-Signature` header with HMAC-SHA256 signature
- `X-Event-Type` header with event type
- `X-Storage-Bucket` header with bucket name
- Unique event ID for deduplication
- Timestamp for replay protection

---

**Related Documentation**: [Storage Overview](README.md) | [Core Platform API](../core-platform/api-reference.md) | [Multi-Tenancy API](../multi-tenancy/api-reference.md)