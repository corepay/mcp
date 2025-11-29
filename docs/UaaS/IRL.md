# IRL: Real World Scenarios for Agentic Underwriting

> **"Every industry has a 'Risk Decision' problem. We solve it."**

This document outlines how the **Agentic UaaS Platform** applies to diverse
real-world verticals.

## 1. The Core Scenarios

### Scenario A: The Merchant Acquirer (Current)

- **The Client**: A Payment Processor (ISO).
- **The Problem**: Onboarding 500 merchants/month manually. High fraud risk.
- **The Agents**:
  - `KycAgent`: Verifies Driver's License & EIN.
  - `WebCrawler`: Checks if the business website is real and matches the MCC.
  - `FraudDetective`: Checks for "Shell Company" patterns (residential address,
    generic website).
- **The Instruction**: "Reject if website is offline. Flag for review if
  business address is a UPS Store."

### Scenario B: The Mortgage Lender

- **The Client**: A regional bank or digital lender.
- **The Problem**: Underwriters spend 4 hours per loan calculating DTI
  (Debt-to-Income) from messy bank statements.
- **The Agents**:
  - `DocExtractor`: Reads 12 months of bank statements (PDF).
  - `FinancialAnalyst`: Categorizes every transaction (Income, Debt,
    Discretionary). Calculates DTI.
  - `PolicyChecker`: Compares DTI against Fannie Mae guidelines.
- **The Instruction**: "Ignore student loan debt if the applicant is a Resident
  Physician (MD). Count 75% of rental income."

### Scenario C: The Auto Dealership

- **The Client**: A "Buy Here Pay Here" dealership chain.
- **The Problem**: Need to approve loans in 15 minutes while the customer is on
  the lot.
- **The Agents**:
  - `IncomeVerifier`: Reads the last 2 paystubs (photo from phone).
  - `IdentityCheck`: Matches FaceID to Driver's License.
- **The Instruction**: "Approve if monthly income > 3x car payment. Reject if
  any repossession in last 2 years."

### Scenario D: The Property Manager (Rentals)

- **The Client**: A large apartment complex management firm.
- **The Problem**: Screening 50 applicants for 1 unit.
- **The Agents**:
  - `BackgroundCheck`: Criminal & Eviction history.
  - `IncomeVerifier`: Verifies employment via email or paystub.
- **The Instruction**: "Strictly reject any prior evictions. Require 3x rent in
  gross income. Allow co-signers."

### Scenario E: The Business Lender (SBA Loans)

- **The Client**: A fintech lending platform.
- **The Problem**: Assessing the health of a small business.
- **The Agents**:
  - `CashFlowAnalyst`: Connects to Plaid/Bank Feed. Calculates DSCR (Debt
    Service Coverage Ratio).
  - `UccSearch`: Checks for existing liens on business assets.
- **The Instruction**: "Approve if DSCR > 1.25. Reject if any tax liens exist."

## 2. Industry Verticals (The Total Addressable Market)

Any industry that requires **Identity Verification + Document Analysis + Risk
Decision** is a target.

1. **Fintech**: Neobanks, Crypto Exchanges, Wallets.
2. **Insurance**: Life, Auto, Home (Underwriting policies).
3. **Real Estate**: Tenant Screening, Commercial Leasing.
4. **Gig Economy**: Driver/Worker onboarding (Uber, DoorDash style).
5. **Legal**: Client intake & conflict checks.
6. **Healthcare**: Patient insurance verification.
7. **Government**: Benefit eligibility (SNAP, Unemployment).
8. **Education**: Student loan & grant applications.
