# Notifications & Communication API Reference

## Overview

The Notifications API provides comprehensive endpoints for sending multi-channel notifications, managing templates, configuring delivery channels, and analyzing notification performance. All requests require authentication and appropriate notification permissions.

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

## Send Notifications

### Send Single Notification

**POST** `/notifications/send`

Send notification to a single user through multiple channels.

**Request:**
```json
{
  "notification": {
    "user_id": "user_1234567890abcdef",
    "type": "document_shared",
    "channels": ["email", "in_app"],
    "template": "document_shared_template",
    "priority": "normal",
    "personalization": {
      "user_name": "John Doe",
      "document_title": "Q4 Financial Report",
      "shared_by": "Jane Smith",
      "access_link": "https://app.example.com/docs/abc123",
      "expiry_date": "2025-12-31T23:59:59Z"
    },
    "delivery_options": {
      "send_at": "2025-11-24T10:00:00Z",
      "quiet_hours_respect": true,
      "retry_failed": true,
      "max_attempts": 3
    },
    "metadata": {
      "source": "document_system",
      "campaign_id": "doc_sharing_q4_2025",
      "tracking_id": "track_xyz123"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "notification_id": "notif_1234567890abcdef",
    "user_id": "user_1234567890abcdef",
    "status": "queued",
    "scheduled_at": "2025-11-24T10:00:00Z",
    "channels": {
      "email": {
        "status": "pending",
        "template_id": "email_doc_shared_001",
        "message_id": "msg_email_abc123"
      },
      "in_app": {
        "status": "pending",
        "message_id": "msg_inapp_def456"
      }
    },
    "created_at": "2025-11-24T09:58:00Z"
  }
}
```

### Send Bulk Notification

**POST** `/notifications/send/bulk`

Send notifications to multiple users with batch processing.

**Request:**
```json
{
  "bulk_notification": {
    "user_ids": ["user_1", "user_2", "user_3", "user_4"],
    "type": "system_maintenance",
    "channels": ["email", "in_app"],
    "template": "maintenance_notice",
    "priority": "high",
    "personalization": {
      "maintenance_window": "2025-11-25 02:00-04:00 UTC",
      "affected_services": ["API", "Dashboard", "File Upload"],
      "estimated_duration": "2 hours",
      "support_contact": "support@mcp-platform.com"
    },
    "delivery_options": {
      "batch_size": 100,
      "send_interval_ms": 1000,
      "respect_rate_limits": true,
      "max_concurrent_sends": 5
    },
    "scheduling": {
      "send_immediately": true,
      "priority_queue": true
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "bulk_id": "bulk_1234567890abcdef",
    "total_recipients": 4,
    "status": "processing",
    "batches": [
      {
        "batch_id": "batch_abc123",
        "user_count": 4,
        "status": "queued",
        "estimated_start": "2025-11-24T10:00:00Z"
      }
    ],
    "progress": {
      "sent": 0,
      "failed": 0,
      "pending": 4,
      "percentage": 0
    },
    "created_at": "2025-11-24T09:59:00Z"
  }
}
```

### Schedule Notification

**POST** `/notifications/schedule`

Schedule notification for future delivery with advanced timing options.

**Request:**
```json
{
  "scheduled_notification": {
    "user_id": "user_1234567890abcdef",
    "type": "meeting_reminder",
    "scheduled_for": "2025-11-25T09:00:00Z",
    "channels": ["email", "sms"],
    "template": "meeting_reminder",
    "priority": "high",
    "personalization": {
      "meeting_title": "Project Review",
      "meeting_time": "2025-11-25T10:00:00Z",
      "meeting_link": "https://zoom.us/j/123456789",
      "participants": ["John Doe", "Jane Smith", "Bob Wilson"],
      "agenda": "Q4 Results, 2025 Planning"
    },
    "reminder_config": {
      "enabled": true,
      "reminders": [
        {
          "minutes_before": 60,
          "channels": ["email"],
          "template": "meeting_reminder_1hr"
        },
        {
          "minutes_before": 15,
          "channels": ["sms"],
          "template": "meeting_reminder_15min"
        }
      ]
    },
    "scheduling_options": {
      "timezone": "America/New_York",
      "reschedule_if_conflict": true,
      "skip_if_inactive": true,
      "max_delay_minutes": 120
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "notification_id": "notif_fedcba0987654321",
    "scheduled_id": "sched_1234567890abcdef",
    "status": "scheduled",
    "scheduled_for": "2025-11-25T09:00:00Z",
    "reminders": [
      {
        "id": "rem_abc123",
        "scheduled_for": "2025-11-25T08:00:00Z",
        "channels": ["email"]
      },
      {
        "id": "rem_def456",
        "scheduled_for": "2025-11-25T08:45:00Z",
        "channels": ["sms"]
      }
    ],
    "created_at": "2025-11-24T10:00:00Z"
  }
}
```

## Template Management

### Create Email Template

**POST** `/notifications/templates/email`

Create new email template with HTML and text content.

**Request:**
```json
{
  "template": {
    "name": "weekly_digest",
    "category": "marketing",
    "description": "Weekly digest email with personalized content",
    "subject": "Your Weekly {{category}} Digest - {{user.engagement_score}}% engaged",
    "html_content": "<html>\n  <head><title>Weekly Digest</title></head>\n  <body>\n    <h1>Hello {{user.first_name}}!</h1>\n    <p>Based on your interests, here's what's trending this week:</p>\n    {% for item in items %}\n      <div class=\"item\">\n        <h3><a href=\"{{item.link}}\">{{item.title}}</a></h3>\n        <p>{{item.summary}}</p>\n        <small>Category: {{item.category}} | Engagement: {{item.engagement}}%</small>\n      </div>\n    {% endfor %}\n    <p>Best regards,<br>The {{company_name}} Team</p>\n  </body>\n</html>",
    "text_content": "Hello {{user.first_name}},\n\nHere's your weekly {{category}} digest:\n{% for item in items %}\n- {{item.title}}: {{item.summary}} ({{item.link}})\n{% endfor %}\n\nBest regards,\nThe {{company_name}} Team",
    "variables": ["user.first_name", "category", "user.engagement_score", "items", "company_name"],
    "metadata": {
      "version": "1.0",
      "author": "marketing_team",
      "tags": ["digest", "weekly", "personalized"],
      "preview_text": "Your personalized weekly updates"
    },
    "tracking": {
      "open_tracking": true,
      "click_tracking": true,
      "custom_tracking_domain": "click.mcp-platform.com"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "template": {
      "id": "template_email_1234567890abcdef",
      "name": "weekly_digest",
      "category": "marketing",
      "version": "1.0",
      "status": "active",
      "created_at": "2025-11-24T10:00:00Z"
    },
    "validation": {
      "syntax_valid": true,
      "variables_defined": true,
      "render_test": {
        "status": "success",
        "sample_render": {
          "subject": "Your Weekly Technology Digest - 85% engaged",
          "html_length": 2456,
          "text_length": 412
        }
      }
    },
    "usage_stats": {
      "times_used": 0,
      "last_used": null,
      "average_render_time_ms": 45
    }
  }
}
```

### Create SMS Template

**POST** `/notifications/templates/sms`

Create new SMS template with length optimization.

**Request:**
```json
{
  "template": {
    "name": "urgent_alert",
    "category": "system",
    "description": "Urgent system alert SMS",
    "content": "{{company_name}}: {{alert_type}} - {{alert_message}}. Reply STOP to opt out.",
    "variables": ["company_name", "alert_type", "alert_message"],
    "metadata": {
      "max_length": 160,
      "unicode_support": true,
      "concatenation_enabled": true,
      "opt_out_keyword": "STOP",
      "help_keyword": "HELP"
    },
    "compliance": {
      "consent_required": true,
      "opt_out_handling": "immediate",
      "age_restriction": false,
      "marketing_flag": false
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "template": {
      "id": "template_sms_1234567890abcdef",
      "name": "urgent_alert",
      "category": "system",
      "version": "1.0",
      "status": "active",
      "created_at": "2025-11-24T10:00:00Z"
    },
    "validation": {
      "content_valid": true,
      "length_check": {
        "character_count": 98,
        "within_limit": true,
        "estimated_segments": 1
      },
      "variables_defined": true,
      "compliance_check": "passed"
    },
    "cost_analysis": {
      "estimated_cost_per_sms": 0.0075,
      "segments_required": 1,
      "international_support": true
    }
  }
}
```

### Update Template with A/B Testing

**PUT** `/notifications/templates/{template_id}`

Update existing template and enable A/B testing.

**Request:**
```json
{
  "template_update": {
    "new_content": {
      "subject": "Your Weekly {{category}} Update - {{user.engagement_score}}% engaged",
      "html_content": "<h1>Hi {{user.first_name}}!</h1><p>Based on your interests, here's what's trending this week:</p>",
      "variables": ["user.first_name", "category", "user.engagement_score"]
    },
    "ab_test_config": {
      "enabled": true,
      "traffic_split": 0.5,
      "success_metrics": ["open_rate", "click_rate", "conversion_rate"],
      "test_duration_days": 14,
      "confidence_level": 0.95,
      "min_sample_size": 1000
    },
    "version_info": {
      "version": "2.0",
      "change_summary": "Enhanced personalization with engagement scoring",
      "rollback_enabled": true
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "template": {
      "id": "template_email_1234567890abcdef",
      "name": "weekly_digest",
      "current_version": "2.0",
      "status": "ab_testing",
      "updated_at": "2025-11-24T10:00:00Z"
    },
    "ab_test": {
      "test_id": "abtest_1234567890abcdef",
      "status": "running",
      "variants": [
        {
          "version": "1.0",
          "traffic_percentage": 50,
          "performance": {
            "open_rate": 0.42,
            "click_rate": 0.08,
            "sample_size": 1250
          }
        },
        {
          "version": "2.0",
          "traffic_percentage": 50,
          "performance": {
            "open_rate": 0.45,
            "click_rate": 0.09,
            "sample_size": 1230
          }
        }
      ],
      "statistical_significance": 0.87,
      "winner_determined": false,
      "estimated_completion": "2025-12-08T10:00:00Z"
    }
  }
}
```

### Get Template Details

**GET** `/notifications/templates/{template_id}`

Retrieve detailed template information including usage statistics.

**Response:**
```json
{
  "status": "success",
  "data": {
    "template": {
      "id": "template_email_1234567890abcdef",
      "name": "weekly_digest",
      "category": "marketing",
      "version": "1.0",
      "status": "active",
      "created_at": "2025-11-15T10:00:00Z",
      "updated_at": "2025-11-20T15:30:00Z"
    },
    "content": {
      "subject": "Your Weekly {{category}} Digest",
      "html_content_length": 2456,
      "text_content_length": 412,
      "variables": ["user.first_name", "category", "user.engagement_score", "items"]
    },
    "usage_statistics": {
      "times_used": 15420,
      "last_used": "2025-11-24T09:00:00Z",
      "unique_recipients": 3420,
      "performance_metrics": {
        "delivery_rate": 0.985,
        "open_rate": 0.423,
        "click_rate": 0.083,
        "unsubscribe_rate": 0.002
      }
    },
    "ab_testing": {
      "active_test": false,
      "completed_tests": 2,
      "best_version": "1.0"
    }
  }
}
```

## User Preferences

### Get User Preferences

**GET** `/notifications/preferences`

Retrieve current user notification preferences.

**Response:**
```json
{
  "status": "success",
  "data": {
    "user_id": "user_1234567890abcdef",
    "preferences": {
      "channels": {
        "email": {
          "enabled": true,
          "types": ["security", "documents", "billing", "marketing"],
          "frequency": "immediate",
          "address": "john.doe@example.com"
        },
        "sms": {
          "enabled": true,
          "types": ["security", "urgent_only"],
          "frequency": "immediate",
          "phone_number": "+15551234567",
          "country_code": "US"
        },
        "push": {
          "enabled": true,
          "types": ["messages", "mentions", "updates"],
          "frequency": "immediate",
          "devices": [
            {
              "device_id": "device_abc123",
              "platform": "ios",
              "token": "ios_push_token_123",
              "last_active": "2025-11-24T08:30:00Z"
            }
          ]
        },
        "in_app": {
          "enabled": true,
          "types": ["all"],
          "frequency": "real_time"
        }
      },
      "quiet_hours": {
        "enabled": true,
        "start_time": "22:00",
        "end_time": "08:00",
        "timezone": "America/New_York",
        "weekends": true,
        "exceptions": ["security", "urgent"]
      },
      "digest_settings": {
        "email_digest": {
          "enabled": true,
          "frequency": "weekly",
          "day": "monday",
          "time": "09:00",
          "include_types": ["updates", "summaries"]
        }
      }
    },
    "updated_at": "2025-11-20T14:15:00Z"
  }
}
```

### Update User Preferences

**PUT** `/notifications/preferences`

Update user notification preferences.

**Request:**
```json
{
  "preferences": {
    "channels": {
      "email": {
        "enabled": true,
        "types": ["security", "documents", "billing"],
        "frequency": "immediate"
      },
      "sms": {
        "enabled": true,
        "types": ["security", "urgent_only"],
        "frequency": "immediate"
      },
      "push": {
        "enabled": true,
        "types": ["messages", "mentions", "updates"],
        "frequency": "immediate"
      },
      "in_app": {
        "enabled": true,
        "types": ["all"],
        "frequency": "real_time"
      }
    },
    "quiet_hours": {
      "enabled": true,
      "start_time": "22:00",
      "end_time": "08:00",
      "timezone": "America/New_York",
      "weekends": true,
      "exceptions": ["security", "urgent"]
    },
    "digest_settings": {
      "email_digest": {
        "enabled": true,
        "frequency": "weekly",
        "day": "monday",
        "time": "09:00",
        "include_types": ["updates", "summaries"]
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
    "user_id": "user_1234567890abcdef",
    "preferences_updated": true,
    "changes_applied": [
      "email_types_updated",
      "quiet_hours_enabled",
      "digest_scheduled"
    ],
    "updated_at": "2025-11-24T10:00:00Z",
    "next_digest_scheduled": "2025-11-25T09:00:00Z"
  }
}
```

### Get Notification History

**GET** `/notifications/history`

Retrieve paginated notification history for user.

**Query Parameters:**
- `page` (integer, optional): Page number (default: 1)
- `page_size` (integer, optional): Items per page (default: 50)
- `type` (string, optional): Filter by notification type
- `channel` (string, optional): Filter by delivery channel
- `status` (string, optional): Filter by delivery status
- `date_from` (string, optional): Start date (ISO 8601)
- `date_to` (string, optional): End date (ISO 8601)

**Response:**
```json
{
  "status": "success",
  "data": {
    "notifications": [
      {
        "id": "notif_1234567890abcdef",
        "type": "document_shared",
        "channels": ["email", "in_app"],
        "status": {
          "email": "delivered",
          "in_app": "read"
        },
        "content": {
          "subject": "Document shared: Q4 Financial Report",
          "preview": "Jane Smith shared 'Q4 Financial Report' with you..."
        },
        "timestamps": {
          "sent_at": "2025-11-24T09:00:00Z",
          "delivered_at": "2025-11-24T09:01:00Z",
          "read_at": "2025-11-24T09:15:00Z"
        },
        "metadata": {
          "source": "document_system",
          "campaign_id": "doc_sharing_q4_2025"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 50,
      "total_count": 124,
      "total_pages": 3,
      "has_next": true,
      "has_prev": false
    },
    "filters": {
      "type": "document_shared",
      "channel": "email",
      "status": "delivered",
      "date_from": "2025-11-01T00:00:00Z",
      "date_to": "2025-11-30T23:59:59Z"
    }
  }
}
```

## Channel Configuration

### Configure Email Channel

**POST** `/notifications/channels/email/configure`

Configure email delivery provider and settings.

**Request:**
```json
{
  "email_config": {
    "provider": "sendgrid",
    "settings": {
      "api_key": "SG.sendgrid_api_key_here",
      "from_email": "noreply@mcp-platform.com",
      "from_name": "MCP Platform",
      "reply_to": "support@mcp-platform.com"
    },
    "features": {
      "tracking": {
        "opens": true,
        "clicks": true,
        "spam_reports": true,
        "unsubscribe_tracking": true
      },
      "templates": {
        "manage_via_api": true,
        "versioning": true,
        "preview_mode": true,
        "test_mode": true
      },
      "delivery": {
        "bounce_processing": true,
        "spam_complaint_handling": true,
        "automatic_retries": true
      }
    },
    "rate_limits": {
      "per_second": 10,
      "per_minute": 600,
      "per_hour": 10000,
      "per_day": 100000
    },
    "compliance": {
      "can_spam_compliant": true,
      "unsubscribe_link_required": true,
      "physical_address_required": true
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "channel": "email",
    "provider": "sendgrid",
    "status": "configured",
    "test_results": {
      "api_connection": "success",
      "send_test": "success",
      "template_rendering": "success",
      "tracking_setup": "success"
    },
    "rate_limits_applied": {
      "per_second": 10,
      "per_minute": 600,
      "per_hour": 10000,
      "per_day": 100000
    },
    "features_enabled": [
      "open_tracking",
      "click_tracking",
      "spam_report_tracking",
      "template_management"
    ],
    "configured_at": "2025-11-24T10:00:00Z"
  }
}
```

### Configure SMS Channel

**POST** `/notifications/channels/sms/configure`

Configure SMS delivery provider and settings.

**Request:**
```json
{
  "sms_config": {
    "provider": "twilio",
    "settings": {
      "account_sid": "AC.twilio_account_sid",
      "auth_token": "twilio_auth_token",
      "from_number": "+15551234567",
      "messaging_service_sid": "MG.messaging_service_sid"
    },
    "features": {
      "mms_support": true,
      "alpha_sender": false,
      "delivery_tracking": true,
      "concatenation": true,
      "unicode_support": true
    },
    "rate_limits": {
      "per_second": 1,
      "per_minute": 10,
      "per_hour": 100,
      "per_day": 1000
    },
    "cost_controls": {
      "max_cost_per_user_month": 5.00,
      "currency": "USD",
      "alert_threshold": 4.00,
      "cost_alerts_enabled": true
    },
    "compliance": {
      "tcpa_compliant": true,
      "opt_out_handling": "automatic",
      "age_verification": false,
      "marketing_consent_required": true
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "channel": "sms",
    "provider": "twilio",
    "status": "configured",
    "phone_number": "+15551234567",
    "features_enabled": [
      "mms_support",
      "delivery_tracking",
      "concatenation",
      "unicode_support"
    ],
    "cost_controls": {
      "max_cost_per_user_month": 5.00,
      "currency": "USD",
      "alert_threshold": 4.00,
      "tracking_enabled": true
    },
    "test_results": {
      "sms_send_test": "success",
      "mms_send_test": "success",
      "opt_out_test": "success"
    },
    "configured_at": "2025-11-24T10:00:00Z"
  }
}
```

## Analytics and Reporting

### Get Notification Analytics

**GET** `/notifications/analytics`

Retrieve comprehensive notification performance analytics.

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
    "overall_metrics": {
      "total_sent": 154200,
      "delivery_rate": 0.985,
      "open_rate": 0.423,
      "click_rate": 0.083,
      "conversion_rate": 0.021,
      "unsubscribe_rate": 0.002,
      "spam_complaint_rate": 0.0001
    },
    "channel_breakdown": {
      "email": {
        "sent": 125000,
        "delivered": 123125,
        "opened": 52000,
        "clicked": 10375,
        "delivery_rate": 0.985,
        "open_rate": 0.422,
        "click_rate": 0.084
      },
      "sms": {
        "sent": 15420,
        "delivered": 15320,
        "opened": 12256,
        "clicked": null,
        "delivery_rate": 0.994,
        "open_rate": 0.800
      },
      "push": {
        "sent": 13480,
        "delivered": 13215,
        "opened": 7929,
        "clicked": 795,
        "delivery_rate": 0.980,
        "open_rate": 0.600,
        "click_rate": 0.060
      },
      "in_app": {
        "sent": 300,
        "delivered": 300,
        "opened": 210,
        "clicked": 45,
        "delivery_rate": 1.000,
        "open_rate": 0.700,
        "click_rate": 0.150
      }
    },
    "template_performance": [
      {
        "template_id": "template_weekly_digest",
        "name": "weekly_digest",
        "sent": 4500,
        "open_rate": 0.456,
        "click_rate": 0.092,
        "conversion_rate": 0.025,
        "performance_rank": 1
      }
    ],
    "time_based_analytics": {
      "best_send_times": [
        {
          "day": "Tuesday",
          "hour": 10,
          "open_rate": 0.485,
          "sample_size": 2450
        }
      ],
      "performance_by_day_of_week": {
        "Monday": {"open_rate": 0.412, "sent": 22000},
        "Tuesday": {"open_rate": 0.445, "sent": 23500},
        "Wednesday": {"open_rate": 0.428, "sent": 21000}
      }
    }
  }
}
```

### Get Bulk Notification Status

**GET** `/notifications/bulk/{bulk_id}/status`

Check status and progress of bulk notification send.

**Response:**
```json
{
  "status": "success",
  "data": {
    "bulk_id": "bulk_1234567890abcdef",
    "status": "completed",
    "started_at": "2025-11-24T09:00:00Z",
    "completed_at": "2025-11-24T09:08:00Z",
    "duration_minutes": 8,
    "progress": {
      "total_recipients": 1250,
      "sent": 1205,
      "failed": 45,
      "pending": 0,
      "percentage": 100
    },
    "batches": [
      {
        "batch_id": "batch_abc123",
        "user_count": 250,
        "status": "completed",
        "sent": 242,
        "failed": 8,
        "completion_time": "2025-11-24T09:01:30Z"
      }
    ],
    "channel_breakdown": {
      "email": {
        "sent": 1205,
        "failed": 45,
        "delivery_rate": 0.964
      }
    },
    "errors": [
      {
        "error_type": "invalid_email",
        "count": 15,
        "sample_users": ["user_invalid_1", "user_invalid_2"]
      }
    ]
  }
}
```

## Webhook Management

### Create Webhook

**POST** `/notifications/webhooks`

Create webhook for real-time notification events.

**Request:**
```json
{
  "webhook": {
    "name": "notification_events_webhook",
    "url": "https://your-app.com/webhooks/notifications",
    "events": [
      "notification.sent",
      "notification.delivered",
      "notification.opened",
      "notification.clicked",
      "notification.failed"
    ],
    "security": {
      "signature_enabled": true,
      "secret_key": "whsec_1234567890abcdef",
      "ip_whitelist": ["203.0.113.0/24"]
    },
    "retry_policy": {
      "max_attempts": 3,
      "backoff_strategy": "exponential",
      "initial_delay_seconds": 5,
      "max_delay_seconds": 300
    },
    "filters": {
      "user_ids": [],
      "notification_types": [],
      "channels": []
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "webhook": {
      "id": "webhook_1234567890abcdef",
      "name": "notification_events_webhook",
      "url": "https://your-app.com/webhooks/notifications",
      "status": "active",
      "created_at": "2025-11-24T10:00:00Z"
    },
    "events_subscribed": [
      "notification.sent",
      "notification.delivered",
      "notification.opened",
      "notification.clicked",
      "notification.failed"
    ],
    "security_config": {
      "signature_enabled": true,
      "ip_whitelist_configured": true
    },
    "test_results": {
      "endpoint_reachable": true,
      "ssl_valid": true,
      "test_payload_sent": true
    }
  }
}
```

## Error Codes Reference

### Delivery Errors (500)

| Code | Description | Resolution |
|------|-------------|------------|
| `template_render_failed` | Template rendering failed | Check template syntax and variables |
| `channel_configuration_error` | Channel not properly configured | Verify channel settings and credentials |
| `rate_limit_exceeded` | Sending rate limit exceeded | Reduce send frequency or increase limits |
| `provider_api_error` | External provider API error | Check provider status and API credentials |

### Validation Errors (400)

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_recipient` | Recipient ID or contact info invalid | Verify user exists and contact info is correct |
| `template_not_found` | Template does not exist | Check template ID and ensure it's active |
| `invalid_personalization` | Personalization data missing or invalid | Provide all required template variables |
| `channel_not_enabled` | User has disabled notification channel | Use different channel or respect user preferences |

### Permission Errors (403)

| Code | Description | Resolution |
|------|-------------|------------|
| `notification_access_denied` | Cannot access notification preferences | Verify user permissions |
| `template_management_denied` | Cannot manage templates | Grant template management permissions |
| `analytics_access_denied` | Cannot access notification analytics | Grant analytics permissions |
| `channel_config_denied` | Cannot configure channels | Grant channel administration permissions |

### User Preference Errors (409)

| Code | Description | Resolution |
|------|-------------|------------|
| `quiet_hours_conflict` | Quiet hours conflict with other settings | Adjust quiet hours or notification timing |
| `digest_conflict` | Digest settings conflict with frequency | Resolve frequency or digest conflicts |
| `channel_opt_out_required` | Legal opt-out required for channel | Ensure proper opt-out mechanisms |
| `consent_missing` | User consent missing for notification type | Obtain proper user consent |

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|---------|
| Send Notification | 100 requests | per minute |
| Send Bulk Notification | 10 requests | per minute |
| Schedule Notification | 50 requests | per minute |
| Template Management | 25 requests | per minute |
| User Preferences | 20 requests | per minute |
| Analytics | 10 requests | per minute |

## Webhooks

### Notification Events

- `notification.created` - Notification created and queued
- `notification.sent` - Notification sent to delivery channel
- `notification.delivered` - Successfully delivered to recipient
- `notification.opened` - Email opened or push notification viewed
- `notification.clicked` - Link clicked in notification
- `notification.failed` - Delivery failed after retries
- `notification.bounced` - Email bounced or SMS failed permanently
- `user.preferences.updated` - User notification preferences changed
- `template.created` - New template created
- `template.updated` - Template updated or modified

### Webhook Security

All webhook requests include:
- `X-Signature` header with HMAC-SHA256 signature
- `X-Event-Type` header with event type
- `X-Webhook-ID` header with unique webhook ID
- `X-Timestamp` header for replay protection
- JSON payload with event data and metadata

### Event Payload Example

```json
{
  "event_id": "evt_1234567890abcdef",
  "event_type": "notification.delivered",
  "timestamp": "2025-11-24T10:00:00Z",
  "data": {
    "notification_id": "notif_abc123",
    "user_id": "user_def456",
    "channel": "email",
    "template_id": "template_weekly_digest",
    "delivered_at": "2025-11-24T10:00:00Z",
    "delivery_details": {
      "provider": "sendgrid",
      "message_id": "msg_xyz789",
      "response_code": 200
    }
  },
  "webhook": {
    "id": "webhook_123",
    "name": "notification_events_webhook"
  }
}
```

---

**Related Documentation**: [Notifications Overview](README.md) | [Core Platform API](../core-platform/api-reference.md) | [Multi-Tenancy API](../multi-tenancy/api-reference.md)