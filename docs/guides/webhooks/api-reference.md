# Webhooks API Reference

## Endpoints

### Create Webhook Endpoint

`POST /api/webhooks/endpoints`

Creates a new webhook subscription.

**Request Body:**

```json
{
    "url": "https://api.partner.com/webhooks",
    "events": ["underwriting.completed"],
    "secret": "optional-secret-or-generated"
}
```

**Response:**

```json
{
    "data": {
        "id": "uuid",
        "url": "https://api.partner.com/webhooks",
        "secret": "generated-secret-if-not-provided",
        "events": ["underwriting.completed"],
        "enabled": true
    }
}
```

### List Webhook Endpoints

`GET /api/webhooks/endpoints`

Returns all configured endpoints for the current tenant/merchant.

### Update Webhook Endpoint

`PATCH /api/webhooks/endpoints/:id`

Updates configuration (e.g., disabling an endpoint or changing events).

### Delete Webhook Endpoint

`DELETE /api/webhooks/endpoints/:id`

Removes the subscription.

## Payload Format

All webhooks are sent as `POST` requests with a JSON body.

```json
{
    "id": "delivery-uuid",
    "event": "underwriting.completed",
    "created_at": "2023-10-27T10:00:00Z",
    "data": {
        "execution_id": "exec-uuid",
        "status": "approved",
        "score": 85
    }
}
```

## Headers

- `Content-Type`: `application/json`
- `X-Mcp-Event`: The event name (e.g., `underwriting.completed`)
- `X-Mcp-Signature`: HMAC-SHA256 signature
- `X-Mcp-Delivery`: The delivery UUID
