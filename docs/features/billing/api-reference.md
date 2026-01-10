# Billing API Reference

## Overview

The Billing API provides comprehensive endpoints for managing subscriptions, payments, plans, and customer billing operations. All requests require authentication and appropriate billing permissions.

## Authentication

Include your API key in the Authorization header:
```http
Authorization: Bearer your-api-key
Content-Type: application/json
```

## Base URL
```
https://your-mcp-platform.com/billing
```

## Plan Management

### Create Plan

**POST** `/billing/plans`

Create a new pricing plan with specified features and limits.

**Request:**
```json
{
  "plan": {
    "name": "Professional",
    "description": "Advanced features for growing businesses",
    "pricing": {
      "amount": 9900,
      "currency": "USD",
      "interval": "month",
      "trial_period_days": 14,
      "billing_cycles": null
    },
    "features": [
      "unlimited_users",
      "advanced_analytics",
      "priority_support",
      "custom_integrations",
      "advanced_security"
    ],
    "limits": {
      "users": 1000,
      "storage_gb": 100,
      "api_calls_per_day": 50000,
      "projects": 50
    },
    "metadata": {
      "tier": "professional",
      "popular": true,
      "contact_required": false
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "plan": {
      "id": "plan_1234567890abcdef",
      "name": "Professional",
      "description": "Advanced features for growing businesses",
      "pricing": {
        "amount": 9900,
        "currency": "USD",
        "interval": "month",
        "formatted_amount": "$99.00",
        "trial_period_days": 14
      },
      "features": [
        "unlimited_users",
        "advanced_analytics",
        "priority_support",
        "custom_integrations",
        "advanced_security"
      ],
      "limits": {
        "users": 1000,
        "storage_gb": 100,
        "api_calls_per_day": 50000,
        "projects": 50
      },
      "metadata": {
        "tier": "professional",
        "popular": true,
        "contact_required": false
      },
      "status": "active",
      "created_at": "2025-11-24T10:00:00Z",
      "updated_at": "2025-11-24T10:00:00Z"
    }
  }
}
```

### List Plans

**GET** `/billing/plans`

Retrieve all available pricing plans with optional filtering.

**Query Parameters:**
- `active_only` (boolean, optional): Show only active plans
- `tier` (string, optional): Filter by plan tier (starter, professional, enterprise)
- `limit` (integer, optional): Number of plans to return (default: 20)
- `offset` (integer, optional): Number of plans to skip (default: 0)

**Response:**
```json
{
  "status": "success",
  "data": {
    "plans": [
      {
        "id": "plan_1234567890abcdef",
        "name": "Starter",
        "description": "Perfect for small teams getting started",
        "pricing": {
          "amount": 2900,
          "currency": "USD",
          "interval": "month",
          "formatted_amount": "$29.00",
          "trial_period_days": 14
        },
        "metadata": {
          "tier": "starter",
          "popular": false,
          "contact_required": false
        }
      },
      {
        "id": "plan_0987654321fedcba",
        "name": "Professional",
        "description": "Advanced features for growing businesses",
        "pricing": {
          "amount": 9900,
          "currency": "USD",
          "interval": "month",
          "formatted_amount": "$99.00",
          "trial_period_days": 14
        },
        "metadata": {
          "tier": "professional",
          "popular": true,
          "contact_required": false
        }
      }
    ],
    "pagination": {
      "total": 3,
      "limit": 20,
      "offset": 0,
      "has_more": false
    }
  }
}
```

### Get Plan

**GET** `/billing/plans/{plan_id}`

Retrieve detailed information about a specific plan.

**Response:**
```json
{
  "status": "success",
  "data": {
    "plan": {
      "id": "plan_1234567890abcdef",
      "name": "Professional",
      "description": "Advanced features for growing businesses",
      "pricing": {
        "amount": 9900,
        "currency": "USD",
        "interval": "month",
        "formatted_amount": "$99.00",
        "trial_period_days": 14
      },
      "features": [
        "unlimited_users",
        "advanced_analytics",
        "priority_support",
        "custom_integrations",
        "advanced_security"
      ],
      "limits": {
        "users": 1000,
        "storage_gb": 100,
        "api_calls_per_day": 50000,
        "projects": 50
      },
      "usage_rates": {
        "api_calls_over_limit": 0.001,
        "storage_gb_over_limit": 0.10,
        "data_transfer_gb": 0.05
      },
      "metadata": {
        "tier": "professional",
        "popular": true,
        "contact_required": false
      },
      "status": "active",
      "created_at": "2025-11-24T10:00:00Z",
      "updated_at": "2025-11-24T10:00:00Z"
    }
  }
}
```

### Update Plan

**PUT** `/billing/plans/{plan_id}`

Update plan details. Changing pricing will affect only new subscriptions.

**Request:**
```json
{
  "plan": {
    "name": "Professional Plus",
    "description": "Enhanced features with additional storage",
    "pricing": {
      "amount": 10900,
      "currency": "USD",
      "interval": "month"
    },
    "limits": {
      "storage_gb": 200,
      "api_calls_per_day": 75000
    },
    "metadata": {
      "popular": true,
      "featured": true
    }
  }
}
```

### Archive Plan

**DELETE** `/billing/plans/{plan_id}`

Archive a plan. Existing subscriptions remain active but new signups are prevented.

**Response:**
```json
{
  "status": "success",
  "data": {
    "plan": {
      "id": "plan_1234567890abcdef",
      "status": "archived",
      "archived_at": "2025-11-24T10:00:00Z"
    }
  }
}
```

## Customer Management

### Create Customer

**POST** `/billing/customers`

Create a new billing customer with payment methods.

**Request:**
```json
{
  "customer": {
    "email": "customer@example.com",
    "name": "John Doe",
    "description": "Enterprise customer from Tech Corp",
    "address": {
      "line1": "123 Business St",
      "line2": "Suite 456",
      "city": "San Francisco",
      "state": "CA",
      "postal_code": "94105",
      "country": "US"
    },
    "phone": "+1-555-123-4567",
    "tax_info": {
      "tax_id": "US123456789",
      "tax_exempt": false,
      "exemption_type": null
    },
    "metadata": {
      "source": "web_signup",
      "sales_rep": "jane@example.com",
      "company_size": "enterprise"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "customer": {
      "id": "cus_1234567890abcdef",
      "email": "customer@example.com",
      "name": "John Doe",
      "description": "Enterprise customer from Tech Corp",
      "status": "active",
      "address": {
        "line1": "123 Business St",
        "line2": "Suite 456",
        "city": "San Francisco",
        "state": "CA",
        "postal_code": "94105",
        "country": "US"
      },
      "tax_info": {
        "tax_id": "US123456789",
        "tax_exempt": false
      },
      "metadata": {
        "source": "web_signup",
        "sales_rep": "jane@example.com",
        "company_size": "enterprise"
      },
      "created_at": "2025-11-24T10:00:00Z",
      "stripe_customer_id": "cus_stripe_123456"
    }
  }
}
```

### Get Customer

**GET** `/billing/customers/{customer_id}`

Retrieve customer details including subscriptions and payment methods.

**Response:**
```json
{
  "status": "success",
  "data": {
    "customer": {
      "id": "cus_1234567890abcdef",
      "email": "customer@example.com",
      "name": "John Doe",
      "description": "Enterprise customer from Tech Corp",
      "status": "active",
      "subscriptions": [
        {
          "id": "sub_1234567890abcdef",
          "plan_id": "plan_0987654321fedcba",
          "plan_name": "Professional",
          "status": "active",
          "current_period_start": "2025-11-01T10:00:00Z",
          "current_period_end": "2025-12-01T10:00:00Z",
          "trial_end": null,
          "cancel_at_period_end": false,
          "created_at": "2025-11-01T10:00:00Z"
        }
      ],
      "payment_methods": [
        {
          "id": "pm_1234567890abcdef",
          "type": "card",
          "brand": "visa",
          "last4": "4242",
          "exp_month": 12,
          "exp_year": 2025,
          "is_default": true,
          "created_at": "2025-11-01T10:00:00Z"
        }
      ],
      "invoices": [
        {
          "id": "inv_1234567890abcdef",
          "status": "paid",
          "total": 9900,
          "formatted_total": "$99.00",
          "currency": "USD",
          "due_date": "2025-12-01T00:00:00Z",
          "created_at": "2025-11-24T10:00:00Z"
        }
      ],
      "metadata": {
        "source": "web_signup",
        "sales_rep": "jane@example.com",
        "company_size": "enterprise"
      },
      "created_at": "2025-11-01T10:00:00Z"
    }
  }
}
```

### Update Customer

**PUT** `/billing/customers/{customer_id}`

Update customer information.

**Request:**
```json
{
  "customer": {
    "name": "John Smith",
    "description": "Updated customer information",
    "address": {
      "line1": "456 New Address Ave",
      "city": "New York",
      "state": "NY",
      "postal_code": "10001",
      "country": "US"
    },
    "metadata": {
      "company_size": "mid-market",
      "account_manager": "bob@example.com"
    }
  }
}
```

## Payment Methods

### Add Payment Method

**POST** `/billing/customers/{customer_id}/payment-methods`

Add a new payment method for a customer.

**Request:**
```json
{
  "payment_method": {
    "type": "card",
    "card": {
      "number": "4242424242424242",
      "exp_month": 12,
      "exp_year": 2025,
      "cvc": "123"
    },
    "billing_address": {
      "line1": "123 Billing St",
      "city": "San Francisco",
      "state": "CA",
      "postal_code": "94105",
      "country": "US"
    },
    "metadata": {
      "nickname": "Company Visa Card"
    },
    "set_as_default": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "payment_method": {
      "id": "pm_1234567890abcdef",
      "type": "card",
      "brand": "visa",
      "last4": "4242",
      "exp_month": 12,
      "exp_year": 2025,
      "is_default": true,
      "billing_address": {
        "line1": "123 Billing St",
        "city": "San Francisco",
        "state": "CA",
        "postal_code": "94105",
        "country": "US"
      },
      "metadata": {
        "nickname": "Company Visa Card"
      },
      "created_at": "2025-11-24T10:00:00Z"
    }
  }
}
```

### List Payment Methods

**GET** `/billing/customers/{customer_id}/payment-methods`

List all payment methods for a customer.

**Response:**
```json
{
  "status": "success",
  "data": {
    "payment_methods": [
      {
        "id": "pm_1234567890abcdef",
        "type": "card",
        "brand": "visa",
        "last4": "4242",
        "exp_month": 12,
        "exp_year": 2025,
        "is_default": true,
        "metadata": {
          "nickname": "Company Visa Card"
        },
        "created_at": "2025-11-01T10:00:00Z"
      },
      {
        "id": "pm_0987654321fedcba",
        "type": "card",
        "brand": "mastercard",
        "last4": "5555",
        "exp_month": 6,
        "exp_year": 2026,
        "is_default": false,
        "created_at": "2025-10-15T14:30:00Z"
      }
    ]
  }
}
```

## Subscription Management

### Create Subscription

**POST** `/billing/subscriptions`

Create a new subscription for a customer.

**Request:**
```json
{
  "subscription": {
    "customer_id": "cus_1234567890abcdef",
    "plan_id": "plan_0987654321fedcba",
    "payment_method_id": "pm_1234567890abcdef",
    "trial_period_days": 14,
    "billing_cycle_anchor": "2025-12-01",
    "metadata": {
      "sales_channel": "website",
      "promo_code": "WELCOME2025",
      "referral_source": "google"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "subscription": {
      "id": "sub_1234567890abcdef",
      "customer_id": "cus_1234567890abcdef",
      "plan_id": "plan_0987654321fedcba",
      "plan_name": "Professional",
      "status": "trialing",
      "current_period_start": "2025-11-24T10:00:00Z",
      "current_period_end": "2025-12-08T10:00:00Z",
      "trial_end": "2025-12-08T10:00:00Z",
      "trial_start": "2025-11-24T10:00:00Z",
      "cancel_at_period_end": false,
      "billing_cycle_anchor": "2025-12-01T10:00:00Z",
      "metadata": {
        "sales_channel": "website",
        "promo_code": "WELCOME2025",
        "referral_source": "google"
      },
      "created_at": "2025-11-24T10:00:00Z",
      "next_billing_date": "2025-12-08T10:00:00Z"
    }
  }
}
```

### Get Subscription

**GET** `/billing/subscriptions/{subscription_id}`

Retrieve detailed subscription information.

**Response:**
```json
{
  "status": "success",
  "data": {
    "subscription": {
      "id": "sub_1234567890abcdef",
      "customer_id": "cus_1234567890abcdef",
      "plan_id": "plan_0987654321fedcba",
      "plan_name": "Professional",
      "status": "active",
      "current_period_start": "2025-11-01T10:00:00Z",
      "current_period_end": "2025-12-01T10:00:00Z",
      "trial_end": null,
      "cancel_at_period_end": false,
      "billing_cycle_anchor": "2025-12-01T10:00:00Z",
      "usage_summary": {
        "api_calls_used": 15420,
        "api_calls_limit": 50000,
        "storage_used_gb": 45.7,
        "storage_limit_gb": 100,
        "projects_used": 12,
        "projects_limit": 50
      },
      "next_invoice": {
        "amount": 9900,
        "currency": "USD",
        "formatted_amount": "$99.00",
        "date": "2025-12-01T10:00:00Z"
      },
      "metadata": {
        "sales_channel": "website",
        "promo_code": "WELCOME2025"
      },
      "created_at": "2025-11-01T10:00:00Z"
    }
  }
}
```

### Update Subscription

**PUT** `/billing/subscriptions/{subscription_id}`

Update subscription parameters.

**Request:**
```json
{
  "subscription": {
    "metadata": {
      "account_manager": "sarah@example.com",
      "support_tier": "premium"
    },
    "payment_method_id": "pm_0987654321fedcba",
    "proration_behavior": "create_prorations"
  }
}
```

### Upgrade Subscription

**PUT** `/billing/subscriptions/{subscription_id}/upgrade`

Upgrade subscription to a higher-tier plan.

**Request:**
```json
{
  "upgrade": {
    "target_plan_id": "plan_fedcba0987654321",
    "proration_behavior": "create_prorations",
    "billing_cycle_anchor": "immediate"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "subscription": {
      "id": "sub_1234567890abcdef",
      "plan_id": "plan_fedcba0987654321",
      "plan_name": "Enterprise",
      "status": "active",
      "current_period_end": "2025-12-01T10:00:00Z",
      "proration": {
        "proration_amount": 12000,
        "proration_date": "2025-11-24T10:00:00Z",
        "formatted_proration": "$120.00"
      },
      "next_invoice": {
        "amount": 29900,
        "currency": "USD",
        "formatted_amount": "$299.00",
        "date": "2025-12-01T10:00:00Z"
      }
    }
  }
}
```

### Cancel Subscription

**DELETE** `/billing/subscriptions/{subscription_id}`

Cancel subscription with immediate or period-end cancellation.

**Query Parameters:**
- `immediately` (boolean, optional): Cancel immediately or at period end (default: false)
- `reason` (string, optional): Cancellation reason
- `feedback` (string, optional): Customer feedback

**Response:**
```json
{
  "status": "success",
  "data": {
    "subscription": {
      "id": "sub_1234567890abcdef",
      "status": "canceled",
      "cancel_at_period_end": true,
      "canceled_at": "2025-11-24T10:00:00Z",
      "ends_at": "2025-12-01T10:00:00Z",
      "current_period_end": "2025-12-01T10:00:00Z",
      "cancellation_reason": "customer_request"
    }
  }
}
```

## Invoices

### List Invoices

**GET** `/billing/invoices`

List customer invoices with filtering options.

**Query Parameters:**
- `customer_id` (string, optional): Filter by customer
- `subscription_id` (string, optional): Filter by subscription
- `status` (string, optional): Filter by status (draft, open, paid, void, uncollectible)
- `limit` (integer, optional): Number of invoices to return (default: 20)
- `offset` (integer, optional): Number of invoices to skip (default: 0)
- `date_from` (string, optional): Filter invoices from this date (ISO 8601)
- `date_to` (string, optional): Filter invoices to this date (ISO 8601)

**Response:**
```json
{
  "status": "success",
  "data": {
    "invoices": [
      {
        "id": "inv_1234567890abcdef",
        "customer_id": "cus_1234567890abcdef",
        "subscription_id": "sub_1234567890abcdef",
        "status": "paid",
        "total": 9900,
        "subtotal": 9900,
        "tax": 0,
        "currency": "USD",
        "formatted_total": "$99.00",
        "due_date": "2025-12-01T00:00:00Z",
        "paid_at": "2025-11-30T15:30:00Z",
        "created_at": "2025-11-24T10:00:00Z"
      }
    ],
    "pagination": {
      "total": 25,
      "limit": 20,
      "offset": 0,
      "has_more": true
    }
  }
}
```

### Get Invoice

**GET** `/billing/invoices/{invoice_id}`

Retrieve detailed invoice information.

**Response:**
```json
{
  "status": "success",
  "data": {
    "invoice": {
      "id": "inv_1234567890abcdef",
      "customer_id": "cus_1234567890abcdef",
      "subscription_id": "sub_1234567890abcdef",
      "status": "paid",
      "total": 10450,
      "subtotal": 9900,
      "tax": 550,
      "currency": "USD",
      "formatted_total": "$104.50",
      "due_date": "2025-12-01T00:00:00Z",
      "paid_at": "2025-11-30T15:30:00Z",
      "billing_period_start": "2025-11-01T00:00:00Z",
      "billing_period_end": "2025-12-01T00:00:00Z",
      "line_items": [
        {
          "id": "li_1234567890abcdef",
          "description": "Professional Plan - Monthly",
          "quantity": 1,
          "unit_price": 9900,
          "amount": 9900,
          "currency": "USD",
          "proration": false,
          "period": {
            "start": "2025-11-01T00:00:00Z",
            "end": "2025-12-01T00:00:00Z"
          }
        },
        {
          "id": "li_0987654321fedcba",
          "description": "Sales Tax (CA 8.75%)",
          "quantity": 1,
          "unit_price": 550,
          "amount": 550,
          "currency": "USD"
        }
      ],
      "payment_attempt_count": 1,
      "next_payment_attempt": null,
      "created_at": "2025-11-24T10:00:00Z",
      "pdf_url": "https://your-mcp-platform.com/invoices/inv_1234567890abcdef.pdf"
    }
  }
}
```

### Create Invoice

**POST** `/billing/invoices`

Create a manual invoice for a customer.

**Request:**
```json
{
  "invoice": {
    "customer_id": "cus_1234567890abcdef",
    "description": "Professional services - November 2025",
    "due_date": "2025-12-15",
    "tax_behavior": "exclusive",
    "line_items": [
      {
        "description": "Custom integration development",
        "quantity": 40,
        "unit_price": 15000,
        "currency": "USD"
      },
      {
        "description": "Priority support package",
        "quantity": 1,
        "unit_price": 5000,
        "currency": "USD"
      }
    ],
    "metadata": {
      "project_id": "proj_123456",
      "po_number": "PO-2025-1115"
    }
  }
}
```

## Payments

### Process Payment

**POST** `/billing/payments`

Process a payment for an invoice.

**Request:**
```json
{
  "payment": {
    "invoice_id": "inv_1234567890abcdef",
    "payment_method_id": "pm_1234567890abcdef",
    "amount": 10450,
    "currency": "USD",
    "confirm": true,
    "metadata": {
      "source": "customer_portal",
      "user_agent": "Mozilla/5.0..."
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "payment": {
      "id": "pay_1234567890abcdef",
      "invoice_id": "inv_1234567890abcdef",
      "amount": 10450,
      "currency": "USD",
      "status": "succeeded",
      "payment_method": {
        "id": "pm_1234567890abcdef",
        "type": "card",
        "brand": "visa",
        "last4": "4242"
      },
      "failure_code": null,
      "failure_message": null,
      "receipt_url": "https://your-mcp-platform.com/receipts/pay_1234567890abcdef",
      "created_at": "2025-11-30T15:30:00Z"
    }
  }
}
```

### Get Payment

**GET** `/billing/payments/{payment_id}`

Retrieve payment details.

**Response:**
```json
{
  "status": "success",
  "data": {
    "payment": {
      "id": "pay_1234567890abcdef",
      "invoice_id": "inv_1234567890abcdef",
      "amount": 10450,
      "currency": "USD",
      "status": "succeeded",
      "payment_method": {
        "id": "pm_1234567890abcdef",
        "type": "card",
        "brand": "visa",
        "last4": "4242",
        "exp_month": 12,
        "exp_year": 2025
      },
      "billing_details": {
        "name": "John Doe",
        "email": "customer@example.com",
        "address": {
          "line1": "123 Business St",
          "city": "San Francisco",
          "state": "CA",
          "postal_code": "94105",
          "country": "US"
        }
      },
      "metadata": {
        "source": "customer_portal"
      },
      "failure_code": null,
      "failure_message": null,
      "receipt_url": "https://your-mcp-platform.com/receipts/pay_1234567890abcdef",
      "created_at": "2025-11-30T15:30:00Z"
    }
  }
}
```

### Create Refund

**POST** `/billing/payments/{payment_id}/refunds`

Create a refund for a payment.

**Request:**
```json
{
  "refund": {
    "amount": 5000,
    "reason": "requested_by_customer",
    "metadata": {
      "customer_note": "Partial refund for unused feature",
      "internal_reason": "Customer requested refund for feature downgrade"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "refund": {
      "id": "re_1234567890abcdef",
      "payment_id": "pay_1234567890abcdef",
      "amount": 5000,
      "currency": "USD",
      "status": "succeeded",
      "reason": "requested_by_customer",
      "receipt_number": "1234-5678",
      "metadata": {
        "customer_note": "Partial refund for unused feature"
      },
      "created_at": "2025-11-30T16:00:00Z"
    }
  }
}
```

## Usage Tracking

### Record Usage

**POST** `/billing/usage`

Record usage for metered billing.

**Request:**
```json
{
  "usage": {
    "customer_id": "cus_1234567890abcdef",
    "subscription_id": "sub_1234567890abcdef",
    "metric": "api_calls",
    "quantity": 1250,
    "timestamp": "2025-11-24T10:00:00Z",
    "metadata": {
      "endpoint": "/data",
      "user_agent": "MCP-Client/1.0",
      "request_id": "req_1234567890abcdef"
    }
  }
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "usage": {
      "id": "usage_1234567890abcdef",
      "customer_id": "cus_1234567890abcdef",
      "subscription_id": "sub_1234567890abcdef",
      "metric": "api_calls",
      "quantity": 1250,
      "recorded_at": "2025-11-24T10:00:00Z",
      "metadata": {
        "endpoint": "/data",
        "user_agent": "MCP-Client/1.0",
        "request_id": "req_1234567890abcdef"
      }
    }
  }
}
```

### Get Usage Summary

**GET** `/billing/usage/{customer_id}`

Get usage summary for a customer.

**Query Parameters:**
- `subscription_id` (string, optional): Filter by subscription
- `metric` (string, optional): Filter by metric type
- `period` (string, optional): Time period (current_month, last_month, custom)
- `period_start` (string, optional): Custom period start (ISO 8601)
- `period_end` (string, optional): Custom period end (ISO 8601)

**Response:**
```json
{
  "status": "success",
  "data": {
    "usage": {
      "period_start": "2025-11-01T00:00:00Z",
      "period_end": "2025-11-24T23:59:59Z",
      "metrics": {
        "api_calls": {
          "total_quantity": 15420,
          "unit_price": 0.001,
          "included_quantity": 50000,
          "overage_quantity": 0,
          "cost": 0.00
        },
        "storage_gb": {
          "current_usage": 45.7,
          "unit_price": 0.10,
          "included_quantity": 100,
          "overage_quantity": 0,
          "cost": 0.00
        },
        "projects": {
          "current_usage": 12,
          "unit_price": 2.00,
          "included_quantity": 50,
          "overage_quantity": 0,
          "cost": 0.00
        }
      },
      "total_cost": 0.00,
      "projected_monthly_cost": 0.00,
      "updated_at": "2025-11-24T10:00:00Z"
    }
  }
}
```

## Error Codes Reference

### Validation Errors (400)

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_plan` | Plan ID invalid or not found | Verify plan exists and is active |
| `invalid_payment_method` | Payment method ID invalid | Verify payment method belongs to customer |
| `invalid_customer` | Customer ID invalid | Verify customer exists |
| `invalid_subscription` | Subscription ID invalid | Verify subscription exists |
| `missing_required_fields` | Required fields missing | Include all required fields in request |

### Authentication Errors (401)

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_api_key` | API key invalid or missing | Check API key format and validity |
| `expired_api_key` | API key has expired | Generate new API key |
| `insufficient_permissions` | API key lacks billing permissions | Add billing permissions to API key |

### Payment Processing Errors (402)

| Code | Description | Resolution |
|------|-------------|------------|
| `card_declined` | Card was declined | Customer should contact their bank |
| `insufficient_funds` | Insufficient funds on account | Customer should use different payment method |
| `expired_card` | Card has expired | Update payment method details |
| `invalid_cvc` | CVC code incorrect | Verify CVC code |
| `fraud_detected` | Transaction flagged as fraud | Verify customer identity and retry |

### Resource Errors (404)

| Code | Description | Resolution |
|------|-------------|------------|
| `plan_not_found` | Plan not found | Verify plan ID |
| `customer_not_found` | Customer not found | Verify customer ID |
| `subscription_not_found` | Subscription not found | Verify subscription ID |
| `invoice_not_found` | Invoice not found | Verify invoice ID |

### Conflict Errors (409)

| Code | Description | Resolution |
|------|-------------|------------|
| `subscription_exists` | Customer already has active subscription | Use existing subscription or cancel first |
| `plan_incompatible` | Plan not compatible with current subscription | Verify plan upgrade/downgrade rules |
| `payment_method_default` | Cannot delete default payment method | Set different default method first |

### Rate Limiting Errors (429)

| Code | Description | Resolution |
|------|-------------|------------|
| `too_many_requests` | API rate limit exceeded | Reduce request frequency |
| `payment_rate_limit` | Payment processing rate limit exceeded | Wait before retrying payment |

### Server Errors (500)

| Code | Description | Resolution |
|------|-------------|------------|
| `payment_gateway_error` | Payment provider error | Retry with exponential backoff |
| `database_error` | Database operation failed | Retry request or contact support |
| `tax_calculation_error` | Tax service unavailable | Contact support for manual processing |

## Rate Limits

| Endpoint | Rate Limit | Window |
|----------|------------|---------|
| Plan Management | 100 requests | per minute |
| Customer Management | 200 requests | per minute |
| Payment Methods | 100 requests | per minute |
| Subscriptions | 200 requests | per minute |
| Invoices | 300 requests | per minute |
| Payments | 100 requests | per minute |
| Usage Tracking | 1000 requests | per minute |

## Webhooks

### Payment Events

- `invoice.payment_succeeded` - Payment processed successfully
- `invoice.payment_failed` - Payment failed
- `invoice.created` - New invoice created
- `customer.subscription.created` - New subscription created
- `customer.subscription.deleted` - Subscription canceled

### Webhook Security

All webhook requests include:
- `X-Signature` header with HMAC signature
- Verify signature using your webhook secret
- Replay protection with unique event ID

---

**Related Documentation**: [Billing Overview](README.md) | [Multi-Tenancy Guide](../multi-tenancy/README.md) | [Developer Guide](../developers/README.md)