# API Versioning

The MCP platform uses **Header-Based Versioning** for all internal APIs. This
approach keeps URLs clean and allows clients to explicitly request specific API
versions without changing endpoint paths.

## Versioning Strategy

- **Header Name**: `API-Version` (or `Accept` header with vendor mime type)
- **Format**: `YYYY-MM-DD`
- **Default**: If no version is specified, the API defaults to the latest stable
  version.

### Request Header Example

To request a specific version, include the `API-Version` header in your request:

```http
GET /api/assessments/123 HTTP/1.1
Host: api.example.com
API-Version: 2024-01-01
Authorization: Bearer <token>
```

Alternatively, you can use the `Accept` header (if supported by the specific
endpoint):

```http
GET /api/assessments/123 HTTP/1.1
Host: api.example.com
Accept: application/vnd.mcp.v1+json
```

## Why Header-Based?

1. **Clean URLs**: Resource paths (`/api/assessments`) remain stable and
   semantic.
2. **Explicit Control**: Clients explicitly opt-in to newer versions, preventing
   breaking changes from affecting existing integrations.
3. **Flexible Evolution**: The backend can support multiple versions of a
   resource representation simultaneously.

## Deprecation Policy

- **Notice Period**: We provide at least 6 months notice before deprecating an
  API version.
- **Sunset Header**: Deprecated responses may include a `Sunset` header
  indicating the date when the version will no longer be supported.
