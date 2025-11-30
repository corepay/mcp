# Webhooks

The MCP Webhooks system provides a reliable, asynchronous mechanism for
notifying external systems about platform events. Built on `AshOban`, it ensures
guaranteed delivery with configurable retries.

## Key Capabilities

- **Reliable Delivery**: Uses persistent job queues to ensure webhooks are
  delivered even if the destination is temporarily down.
- **Event Filtering**: Endpoints can subscribe to specific events (e.g.,
  `underwriting.completed`, `document.processed`).
- **Security**: All webhook payloads are signed with a shared secret using
  HMAC-SHA256.
- **Multi-Tenancy**: Webhooks are scoped to specific Tenants or Merchants.

## Architecture

1. **Event Trigger**: An action (e.g., underwriting completion) triggers a
   webhook event.
2. **Job Creation**: `AshOban` creates a `Mcp.Webhooks.Delivery` record and
   schedules a delivery job.
3. **Dispatch**: The background worker attempts to send the payload to the
   configured `Mcp.Webhooks.Endpoint`.
4. **Retry Logic**: On failure (non-2xx response or timeout), the job is retried
   with exponential backoff.

## Quick Links

- [User Guide](user-guide.md): How to configure and manage webhooks.
- [Developer Guide](developer-guide.md): Implementation details and adding new
  events.
- [API Reference](api-reference.md): API endpoints for managing webhooks.
- [Stakeholder Guide](stakeholder-guide.md): Business value and reliability
  guarantees.
