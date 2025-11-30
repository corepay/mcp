# Webhooks User Guide

## Overview

Webhooks allow your system to receive real-time updates from the MCP platform.
Instead of polling our API to check the status of an underwriting request, we
will send an HTTP POST request to a URL you provide as soon as the result is
ready.

## Getting Started

1. **Prepare your Endpoint**: Create an HTTPS endpoint on your server that can
   accept POST requests.
2. **Register the Webhook**: Use the Developer Portal or API to register your
   URL and select the events you want to receive.
3. **Verify Ownership**: We may send a test ping to verify the URL is active.
4. **Handle Requests**: Process the incoming JSON payloads.

## Best Practices

- **Verify Signatures**: Always verify the `X-Mcp-Signature` header to ensure
  the request originated from us.
- **Respond Quickly**: Return a 200 OK response immediately upon receiving the
  webhook. Process complex logic asynchronously to avoid timeouts.
- **Idempotency**: Ensure your handler can handle duplicate events gracefully
  (e.g., by checking the `X-Mcp-Delivery` ID).

## Troubleshooting

- **Retries**: If your server returns an error (5xx) or times out, we will retry
  delivery with exponential backoff for up to 24 hours.
- **Disabling**: If an endpoint fails consistently for an extended period, it
  may be automatically disabled.
