# User Guide: Underwriting Engine

## Getting Started

This guide covers the day-to-day use of the MCP Underwriting Engine for
processing applications, reviewing decisions, and managing verification
workflows.

## Application Workflow

### Application Lifecycle

```
Draft → Submitted → In Review → [Approved | Rejected]
```

1. **Draft**: Application created, data being collected
2. **Submitted**: Ready for automated processing
3. **In Review**: Verification checks in progress
4. **Approved/Rejected**: Final decision rendered

### Creating an Application

Applications are created when a subject (individual or business) begins the
onboarding process:

```elixir
# Via API
POST /api/applications
{
  "subject_id": "merchant-uuid",
  "subject_type": "merchant",
  "application_data": {
    "business_name": "Acme Corp",
    "legal_structure": "llc",
    "owners": [
      {"first_name": "John", "last_name": "Doe", "email": "john@acme.com"}
    ]
  }
}

# Via Elixir
{:ok, app} = Ash.create(Application, %{
  subject_id: merchant_id,
  subject_type: :merchant,
  application_data: data
}, tenant: tenant_schema)
```

### Submitting for Review

Once application data is complete:

```elixir
# Update status to submitted
Ash.update!(application, %{status: :submitted}, tenant: tenant)
```

### Running Verification

Trigger the full screening process:

```elixir
{:ok, risk_score} = Gateway.screen_application(application.id, tenant: tenant)
```

This automatically:
1. Runs KYB verification on the business
2. Runs KYC verification on each owner
3. Screens against watchlists
4. Calculates risk score
5. Updates application status

## Verification Types

### KYC (Know Your Customer)

Identity verification for individuals:

| Check Type | Description |
|------------|-------------|
| Identity | Name, DOB, SSN validation |
| Address | Residence verification |
| Document | ID document authenticity |
| Biometric | Facial recognition match |

### KYB (Know Your Business)

Business verification:

| Check Type | Description |
|------------|-------------|
| Registration | Business registration validation |
| EIN | Tax ID verification |
| Ownership | UBO (Ultimate Beneficial Owner) identification |
| Address | Business address verification |

### Watchlist Screening

AML/Compliance checks:

| List Type | Description |
|-----------|-------------|
| PEP | Politically Exposed Persons |
| Sanctions | OFAC, UN, EU sanctions lists |
| Adverse Media | Negative news screening |
| Criminal | Criminal database checks |

## Reviewing Results

### Check Status

Each verification check has a status:

- **Pending**: Check initiated, awaiting results
- **Complete**: Results received
- **Failed**: Check could not be completed

### Check Outcomes

Completed checks have an outcome:

- **Clear**: Verification passed
- **Review**: Requires manual review
- **Alert**: Potential issue detected
- **Fail**: Verification failed

### Viewing Check Results

```elixir
# Get all checks for a client
checks = Check.list_by_client(client_id, tenant: tenant)

# Get latest check of a specific type
check = Check.get_latest_by_type(client_id, :identity, tenant: tenant)

# View raw result from vendor
check.raw_result
```

## Risk Assessment

### Risk Score

Applications receive a risk score from 0-100:

| Score Range | Risk Level | Typical Action |
|-------------|------------|----------------|
| 0-30 | Low | Auto-approve |
| 31-60 | Medium | Standard review |
| 61-80 | High | Enhanced review |
| 81-100 | Critical | Manual review required |

### Risk Factors

The assessment includes factor breakdown:

```elixir
assessment = RiskAssessment
  |> Ash.Query.filter(application_id == ^app.id)
  |> Ash.read_one!(tenant: tenant)

# Example factors
assessment.factors
# => %{
#   "identity_score" => 95,
#   "address_match" => true,
#   "watchlist_hits" => 0,
#   "document_quality" => "high",
#   "business_age_months" => 24
# }
```

### Recommendations

The system provides a recommendation:

- **Approve**: Application meets criteria
- **Reject**: Application fails criteria
- **Manual Review**: Requires human decision

## Activity Log

### Viewing Activities

All actions are logged for audit purposes:

```elixir
activities = Activity
  |> Ash.Query.filter(application_id == ^app.id)
  |> Ash.Query.sort(inserted_at: :desc)
  |> Ash.read!(tenant: tenant)
```

### Activity Types

| Type | Description |
|------|-------------|
| `status_change` | Application status updated |
| `document_upload` | Document added to application |
| `kyc_initiated` | KYC check started |
| `kyc_completed` | KYC check finished |
| `kyc_success` | KYC passed |
| `kyc_failure` | KYC failed |
| `watchlist_hit` | Watchlist match found |
| `watchlist_clear` | No watchlist matches |
| `risk_calculated` | Risk score computed |
| `decision_made` | Final decision rendered |

### Activity Details

Each activity includes metadata:

```elixir
# Status change activity
%{
  type: :status_change,
  metadata: %{
    "from" => "submitted",
    "to" => "approved",
    "reason" => "auto_approved"
  },
  actor_id: system_user_id
}

# KYC failure activity
%{
  type: :kyc_failure,
  metadata: %{
    "owner_email" => "john@example.com",
    "reason" => "document_expired"
  }
}
```

## Manual Review Workflow

### When Manual Review is Required

- Risk score exceeds threshold
- Watchlist match detected
- Document quality issues
- Conflicting information
- Agent confidence below threshold

### Performing Manual Review

1. **Review Application Data**
   ```elixir
   app = Application.get_by_id!(app_id, tenant: tenant)
   ```

2. **Review Verification Results**
   ```elixir
   checks = Check.list_by_client(client_id, tenant: tenant)
   ```

3. **Review Risk Assessment**
   ```elixir
   assessment = RiskAssessment
     |> Ash.Query.filter(application_id == ^app_id)
     |> Ash.read_one!(tenant: tenant)
   ```

4. **Make Decision**
   ```elixir
   Ash.update!(app, %{status: :approved}, tenant: tenant)
   # or
   Ash.update!(app, %{status: :rejected}, tenant: tenant)
   ```

5. **Log Decision**
   ```elixir
   Ash.create!(Activity, %{
     application_id: app.id,
     type: :decision_made,
     metadata: %{"decision" => "approved", "reviewer" => user_id},
     actor_id: user_id
   }, tenant: tenant)
   ```

## Troubleshooting

### Common Issues

#### Application Stuck in "In Review"

**Cause**: Verification check failed or timed out.

**Solution**:
1. Check activity log for errors
2. Review check status for failed checks
3. Retry failed checks or proceed with manual review

#### KYC Failure

**Cause**: Identity verification could not be completed.

**Solution**:
1. Review the specific failure reason in activity log
2. Request updated documents from applicant
3. Retry verification with new information

#### Watchlist Hit

**Cause**: Name matches a watchlist entry.

**Solution**:
1. Review the match details in check results
2. Determine if it's a true match or false positive
3. Document your decision in the activity log
4. Proceed with appropriate action

#### High Risk Score

**Cause**: Multiple risk factors combined.

**Solution**:
1. Review individual risk factors
2. Determine which factors are most concerning
3. Request additional documentation if needed
4. Make informed approval/rejection decision

### Error Messages

| Error | Cause | Resolution |
|-------|-------|------------|
| `tenant_required` | No tenant context | Ensure tenant is passed to all operations |
| `kyc_failed` | KYC verification error | Check activity log for details |
| `circuit_open` | Vendor unavailable | System will auto-recover; wait and retry |
| `rate_limit_exceeded` | Too many requests | Wait for rate limit window to reset |

## Best Practices

### Data Quality

- Ensure complete application data before submission
- Validate email addresses and phone numbers
- Use standardized address formats
- Include all required owner information

### Review Efficiency

- Set up notification webhooks for status changes
- Use batch processing for multiple applications
- Configure auto-approval thresholds appropriately
- Document all manual review decisions

### Compliance

- Review activity logs regularly
- Export audit data for compliance reports
- Keep instruction sets up to date with regulations
- Test with sample applications before policy changes

## Support

For technical issues:
- Check the activity log for error details
- Review the developer guide for integration help
- Contact technical support with application ID and error details

For policy questions:
- Review the stakeholder guide for business requirements
- Consult with compliance team for regulatory questions
- Request instruction set updates through proper channels
