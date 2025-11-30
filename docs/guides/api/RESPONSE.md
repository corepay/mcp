# API Response Format

All internal APIs in the MCP platform follow a strict JSON response standard.
This ensures consistency for frontend consumers and external integrations.

## Success Response

Successful requests return a `2xx` HTTP status code and a JSON object containing
a `data` key. The value of `data` is the requested resource or result.

**Format:**

```json
{
  "data": <Resource | List<Resource> | Map>
}
```

**Example (Single Resource):**

```json
{
    "data": {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "status": "active",
        "name": "John Doe"
    }
}
```

**Example (List):**

```json
{
    "data": [
        { "id": "1", "name": "Item A" },
        { "id": "2", "name": "Item B" }
    ]
}
```

## Error Response

Failed requests return a `4xx` or `5xx` HTTP status code and a JSON object
containing an `error` key.

**Format:**

```json
{
  "error": {
    "code": "<string_error_code>",
    "message": "<human_readable_message>",
    "details": <Map | List | String | null>
  }
}
```

### Fields

- **code**: A stable, machine-readable string indicating the error type (e.g.,
  `validation_error`, `not_found`). See [Error Codes](./ERROR_CODES.md).
- **message**: A human-readable description of the error, suitable for logging
  or developer debugging.
- **details**: Optional structured data providing more context (e.g., validation
  failures by field).

**Example (Validation Error):**

```json
{
    "error": {
        "code": "validation_error",
        "message": "Validation failed",
        "details": {
            "email": ["has already been taken"],
            "password": ["is too short"]
        }
    }
}
```

**Example (Not Found):**

```json
{
    "error": {
        "code": "not_found",
        "message": "Resource not found",
        "details": null
    }
}
```
