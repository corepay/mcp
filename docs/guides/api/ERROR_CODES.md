# Standard API Error Codes

This document lists the standard error codes returned by the MCP platform API.

## Common Error Codes

| Error Code              | HTTP Status | Description                                                                             |
| :---------------------- | :---------- | :-------------------------------------------------------------------------------------- |
| `validation_error`      | 422         | The request parameters failed validation. `details` will contain a map of field errors. |
| `invalid_request`       | 422         | The request was malformed or contained invalid logic (e.g., Ash action failure).        |
| `not_found`             | 404         | The requested resource could not be found.                                              |
| `unauthorized`          | 401         | Authentication is required or failed.                                                   |
| `forbidden`             | 403         | The authenticated user does not have permission to access the resource.                 |
| `internal_server_error` | 500         | An unexpected server error occurred.                                                    |
| `service_unavailable`   | 503         | A downstream service (e.g., LLM, Payment Gateway) is unavailable.                       |

## Domain-Specific Codes

### Underwriting

| Error Code          | HTTP Status | Description                                        |
| :------------------ | :---------- | :------------------------------------------------- |
| `blueprint_invalid` | 422         | The Agent Blueprint configuration is invalid.      |
| `execution_failed`  | 500         | The assessment execution failed during processing. |

### Payments

| Error Code         | HTTP Status | Description                                          |
| :----------------- | :---------- | :--------------------------------------------------- |
| `payment_declined` | 402         | The payment transaction was declined by the gateway. |
| `gateway_error`    | 502         | Error communicating with the payment provider.       |
