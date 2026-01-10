# AI API Reference

## Mcp.Ai.Document

### Actions

| Action | Type | Description |
| :--- | :--- | :--- |
| `create` | `create` | Creates a new document and generates its embedding. |
| `read` | `read` | Reads documents. |
| `update` | `update` | Updates content and regenerates embedding. |
| `destroy` | `destroy` | Soft deletes the document. |

### Attributes

| Attribute | Type | Description |
| :--- | :--- | :--- |
| `id` | `uuid` | Unique identifier. |
| `content` | `string` | The text content. |
| `embedding` | `vector` | The vector embedding. |
| `ref_id` | `uuid` | ID of the referenced entity. |
| `ref_type` | `string` | Type of the referenced entity. |

## Mcp.Ai Domain

### `generate_embedding/1`
Generates a vector embedding for the given text.

**Signature**: `generate_embedding(text :: String.t()) :: {:ok, list(float)} | {:error, term}`
