# API Examples

This document provides concrete examples of interacting with the MCP platform's
specialty agents via the API.

## Underwriting Assessment

Trigger a new underwriting assessment using a specific pipeline of agents.

### Request

**Endpoint**: `POST /api/assessments` **Headers**:

- `Content-Type`: `application/json`
- `API-Version`: `2024-01-01`

**Body**:

```json
{
    "pipeline_id": "123e4567-e89b-12d3-a456-426614174000",
    "subject_id": "987fcdeb-51a2-43d7-9012-345678901234",
    "subject_type": "individual",
    "context": {
        "annual_income": 120000,
        "total_debt": 35000,
        "credit_score": 750
    }
}
```

### Response

**Status**: `201 Created`

**Body**:

```json
{
    "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "status": "completed",
        "subject_id": "987fcdeb-51a2-43d7-9012-345678901234",
        "subject_type": "individual",
        "results": {
            "FinancialAnalyst": {
                "decision": "approve",
                "dti": 0.29,
                "reasoning": "Debt-to-Income ratio is 29%, which is well below the 43% threshold. Credit score indicates strong repayment history."
            },
            "RiskAssessor": {
                "risk_level": "low",
                "confidence": 0.95
            }
        },
        "inserted_at": "2024-01-01T12:00:00.000000Z",
        "updated_at": "2024-01-01T12:00:05.000000Z"
    }
}
```

## Retrieve Assessment

Get the status and results of an existing assessment.

### Request

**Endpoint**: `GET /api/assessments/550e8400-e29b-41d4-a716-446655440000`
**Headers**:

- `API-Version`: `2024-01-01`

### Response

**Status**: `200 OK`

**Body**:

```json
{
    "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "status": "completed",
        "results": {
            "FinancialAnalyst": {
                "decision": "approve",
                "dti": 0.29
            }
        }
    }
}
```
