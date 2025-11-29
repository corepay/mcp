# Agentic UaaS API Reference

## 1. Configuring Agents (The "Training" API)

Tenants use this API to configure how the generic agents behave for their
specific needs.

### Create Instruction Set

`POST /api/v1/instruction_sets`

**Request:**

```json
{
    "blueprint_name": "FinancialAnalyst",
    "name": "Conservative Mortgage Policy",
    "instructions": "When calculating DTI, include 100% of student loan debt. Reject if DTI > 43%. Ignore rental income unless 2 years of history is provided."
}
```

**Response:**

```json
{
    "id": "inst_123",
    "status": "active"
}
```

## 2. Running Assessments (The "Headless" API)

This is the main entry point for 3rd party integrations (Mortgage Lenders, Auto
Dealers).

### Start Assessment

`POST /api/v1/assessments`

**Request:**

```json
{
    "subject_type": "individual",
    "pipeline_id": "pipe_mortgage_v1",
    "documents": [
        { "type": "bank_statement", "url": "https://.../stmt1.pdf" },
        { "type": "paystub", "url": "https://.../stub1.pdf" }
    ],
    "context": {
        "loan_amount": 500000,
        "property_value": 600000
    }
}
```

**Response:**

```json
{
    "id": "exec_456",
    "status": "processing",
    "eta_seconds": 120
}
```

## 3. Retrieving Results

### Get Assessment Result

`GET /api/v1/assessments/exec_456`

**Response:**

```json
{
    "id": "exec_456",
    "status": "completed",
    "decision": "approved",
    "score": 92,
    "memo": "# Approval Memo\n\nBased on the 'Conservative Mortgage Policy', the applicant is approved.\n\n- **DTI**: 32% (Passes < 43% rule)\n- **Income**: Verified $12k/mo via Paystubs.\n- **Notes**: Student loans were included in DTI calculation as requested.",
    "breakdown": [
        {
            "agent": "FinancialAnalyst",
            "output": { "dti": 0.32, "monthly_income": 12000 }
        }
    ]
}
```

## 4. Webhooks

- `assessment.completed`: Fired when the entire pipeline finishes.
- `agent.flagged`: Fired if a specific agent raises a critical flag (e.g.,
  "Fraud Detected").
