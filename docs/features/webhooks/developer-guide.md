# Webhooks Developer Guide

## Implementation Details

The Webhooks system is implemented using the `Mcp.Webhooks` domain and `AshOban`
for job processing.

### Resources

#### `Mcp.Webhooks.Endpoint`

Stores configuration for a webhook destination.

- `url`: The HTTPS URL to send the POST request to.
- `secret`: Shared secret for HMAC signing.
- `events`: List of event types to subscribe to.
- `tenant_id` / `merchant_id`: Scoping fields.

#### `Mcp.Webhooks.Delivery`

Represents a single delivery attempt.

- `endpoint_id`: The destination.
- `payload`: The JSON payload.
- `status`: `:pending`, `:success`, `:failure`, `:retrying`.
- `response_code`: HTTP status code from the destination.

### Adding New Events

To trigger a webhook for a new event type:

1. **Define the Event**: Ensure the event name follows the `domain.action`
   pattern (e.g., `underwriting.completed`).
2. **Create Delivery**: Use the `Mcp.Webhooks.Delivery` resource to create a
   delivery record.

```elixir
Mcp.Webhooks.Delivery.create!(%{
  endpoint_id: endpoint.id,
  event: "underwriting.completed",
  payload: %{
    execution_id: execution.id,
    status: "approved"
  }
})
```

`AshOban` will automatically pick up the created record and attempt delivery.

### Security

#### Signature Verification

All webhook requests include an `X-Mcp-Signature` header. This is an HMAC-SHA256
hash of the request body, signed with the endpoint's `secret`.

**Verification Example (Elixir):**

```elixir
signature = "sha256=" <> Base.encode16(:crypto.mac(:hmac, :sha256, secret, body), case: :lower)
Plug.Conn.get_req_header(conn, "x-mcp-signature") == [signature]
```
