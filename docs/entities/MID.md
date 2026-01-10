# MID Entity

> **Last Updated**: 2026-01-10 | **Code Verified**: Yes

## Overview

A **MID** (Merchant Identification Number) represents a payment gateway account assigned to a merchant. Each MID contains the credentials and configuration needed to process transactions through a specific payment processor.

### Business Context

MIDs are the **connection to payment networks**. They are:
- Issued by acquiring banks or payment processors
- Required for card-present and card-not-present transactions
- Subject to volume limits, risk monitoring, and compliance requirements
- The source of merchant statements and settlement

### Key Characteristics

| Aspect | Implementation |
|--------|----------------|
| Scope | Tenant-scoped (via merchant) |
| Purpose | Gateway credentials + routing |
| Limits | Daily and monthly volume caps |
| Status | Active, suspended, or testing |

---

## Current State

### Data Model

**Resource**: `Mcp.Platform.MID`
**Table**: `mids` (tenant schema)
**Multitenancy**: ✅ Context strategy
**Archival**: ✅ Soft-delete enabled

#### Core Attributes

| Attribute | Type | Status | Description |
|-----------|------|--------|-------------|
| `id` | UUID | ✅ | Primary key |
| `mid_number` | String | ✅ | Processor-assigned MID number |
| `gateway_id` | UUID | ✅ | Reference to gateway catalog |
| `gateway_credentials` | Map | ✅ | API keys, tokens (encrypted) |
| `routing_rules` | Map | ✅ | Transaction routing logic |
| `status` | Atom | ✅ | `active`, `suspended`, `testing` |
| `is_primary` | Boolean | ✅ | Primary MID for merchant |
| `processor_name` | String | ✅ | Processor display name |
| `acquirer_name` | String | ✅ | Acquiring bank name |
| `batch_time` | Time | ✅ | Daily batch cutoff time |
| `supported_card_brands` | Array[String] | ✅ | Visa, MC, Amex, etc. |
| `currencies` | Array[String] | ✅ | Supported currencies |
| `fraud_settings` | Map | ✅ | Fraud prevention config |
| `daily_limit` | Decimal | ✅ | Daily processing limit |
| `monthly_limit` | Decimal | ✅ | Monthly processing limit |
| `total_volume` | Decimal | ✅ | Lifetime volume (default: 0) |
| `total_transactions` | Integer | ✅ | Lifetime count (default: 0) |
| `inserted_at` | DateTime | ✅ | Created timestamp |
| `updated_at` | DateTime | ✅ | Modified timestamp |

#### Relationships

| Relationship | Type | Target | Status |
|--------------|------|--------|--------|
| `merchant` | belongs_to | `Platform.Merchant` | ✅ |
| `account` | has_one | `Finance.Account` | ✅ |

#### Available Actions

| Action | Status | Description |
|--------|--------|-------------|
| `create` | ✅ | Create MID |
| `read` | ✅ | List/query MIDs |
| `update` | ✅ | Modify MID (credentials, limits, routing) |
| `destroy` | ✅ | Soft-delete MID |

### Portal / UI

**Dedicated UI**: None
**Access**: Via Merchant settings (when implemented)

| Feature | Status | Location |
|---------|--------|----------|
| MID List | 🚫 | Not implemented |
| MID Details | 🚫 | Not implemented |
| Credential Management | 🚫 | Not implemented |
| Volume Monitoring | 🚫 | Not implemented |

### API

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| JSON:API `/mid` | GET | ✅ | List MIDs |
| JSON:API `/mid/:id` | GET | ✅ | Get MID |
| JSON:API `/mid` | POST | ✅ | Create MID |
| JSON:API `/mid/:id` | PATCH | ✅ | Update MID |
| JSON:API `/mid/:id` | DELETE | ✅ | Archive MID |

### Tests

| Test File | Coverage |
|-----------|----------|
| No dedicated test file | ⚠️ Missing |

---

## Gaps

### Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| ⚠️ **No UI** | Cannot manage MIDs visually | High |
| ⚠️ **No Gateway Catalog** | `gateway_id` references nothing | High |
| ⚠️ **Volume Tracking** | Totals not updated from transactions | High |
| ⚠️ **Limit Enforcement** | No blocking when limits reached | Critical |
| ⚠️ **No Tests** | Zero test coverage | High |

### Missing Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Gateway Catalog | Shared catalog of supported gateways | Critical |
| MID Management UI | CRUD interface in merchant portal | High |
| Limit Enforcement | Block transactions at limit | Critical |
| Real-Time Volume | Live volume tracking | High |
| Credential Rotation | API key rotation workflow | Medium |
| Health Monitoring | Gateway availability checks | Medium |
| Routing Engine | Intelligent transaction routing | Medium |
| MID Application Flow | Request new MID from platform | Medium |
| Statement Integration | Pull processor statements | Low |
| Velocity Controls | Transaction rate limiting | Low |

---

## Recommendations

### Short-Term (0-30 days)

1. **Create Gateway Catalog**
   - Global resource for supported gateways
   - Gateway capabilities (card brands, currencies)
   - Credential schema per gateway
   - Health/status monitoring

2. **Implement Limit Enforcement**
   - Check limits before authorization
   - Daily reset logic
   - Monthly reset logic
   - Alerting when approaching limits

3. **Volume Tracking Integration**
   - Update `total_volume` on successful charges
   - Update `total_transactions` counter
   - Daily aggregation job

4. **Add Test Coverage**
   - CRUD operations
   - Limit enforcement
   - Credential encryption

### Medium-Term (30-90 days)

1. **MID Management UI**
   - List MIDs per merchant
   - Add/edit MID credentials
   - Set as primary
   - View volume stats

2. **Intelligent Routing**
   - Route by card brand
   - Route by amount
   - Route by success rate
   - Failover logic

3. **Health Monitoring**
   - Ping gateway endpoints
   - Track success rates
   - Automatic failover
   - Alert on degradation

### Long-Term (90+ days)

1. **MID Application Workflow**
   - Request new MID from portal
   - Underwriting integration
   - Automatic provisioning

2. **Multi-Currency Support**
   - Currency-specific MIDs
   - Dynamic currency conversion
   - FX rate management

3. **Advanced Fraud Tools**
   - Velocity rules
   - Geographic restrictions
   - BIN blocking
   - 3DS configuration

---

## Opportunities

### Revenue Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Gateway Markup** | Add margin to gateway fees | Built-in |
| **MID-as-a-Service** | Provision MIDs for smaller merchants | High |
| **Premium Routing** | Charge for intelligent routing | Medium |
| **Fraud Tools Premium** | Advanced fraud prevention add-on | Medium |

### Product Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Gateway Comparison** | Help merchants choose optimal gateway | Medium |
| **Automatic Optimization** | ML-based routing optimization | High |
| **Batch Processing** | File-based transaction uploads | Medium |
| **Reconciliation Tools** | Match transactions to statements | High |

### Technical Opportunities

| Opportunity | Description | Effort |
|-------------|-------------|--------|
| **Credential Vault** | HSM-backed credential storage | High |
| **Gateway SDK** | Abstraction layer for integrations | Medium |
| **Real-Time Analytics** | Live transaction stream | Medium |
| **Load Balancing** | Distribute across multiple MIDs | Medium |

---

## Gateway Architecture Notes

### Current State
- `gateway_id` attribute exists but no Gateway resource
- Credentials stored as encrypted JSON map
- Each payment adapter (Stripe, QorPay) has its own implementation

### Proposed Architecture
```
Gateways (Global Catalog)
    ├── Stripe
    ├── QorPay
    ├── Square
    └── ...

MID
    ├── gateway_id → Gateways.id
    ├── gateway_credentials (gateway-specific)
    └── routing_rules
```

---

## Related Entities

- **Merchant** - Parent business entity
- **Store** - Can reference primary MID
- **Finance.Account** - Settlement account
- **Payments.Charge** - Transactions processed

---

*Source: `lib/mcp/platform/mid.ex`, `lib/mcp/payments/`*
