# Vision: The Agentic Decision Platform

> **"Don't buy software. Hire Digital Underwriters."**

## 1. The Big Shift: From "Tools" to "Agents"

Traditional underwriting software (Salesforce, nCino) gives you **tools**:
forms, checkboxes, and workflow rules. You still need humans to read the
documents, interpret the grey areas, and make the decision.

We are building an **Agentic Platform**. We don't just give you a form; we give
you a **Digital Employee**.

### The Core Difference

- **Software**: "Here is a PDF. You read it."
- **Atlas**: "I read the PDF. The cash flow is strong, but there's a hidden loan
  payment to 'OnDeck Capital' on page 4. I recommend manual review."

## 2. The Product: "Specialty Agents on Demand"

We provide a marketplace of **Specialty Agents** that Tenants can "hire" and
"train".

### The "Core" Agents (What we build)

1. **The Extractor**: "I turn messy PDFs (Bank Statements, Tax Returns, IDs)
   into clean JSON."
2. **The Detective**: "I look for fraud patterns (Synthetic IDs, Shell
   Companies, Photoshop artifacts)."
3. **The Analyst**: "I calculate financial ratios (DSCR, DTI, Cash Flow) based
   on the extracted data."

### The "Instruction Set" (How Tenants "Train" them)

Tenants don't write code. They write **Instructions** (in plain English) to
overlay their specific risk policy.

- **Tenant A (Conservative Bank)**:
  > "Analyst, when calculating Debt-to-Income, include 100% of student loan
  > payments. Reject if DTI > 40%."
- **Tenant B (Fintech Startup)**:
  > "Analyst, ignore student loans for Medical Doctors. Focus on their future
  > earning potential."

## 3. The "Headless" Advantage

While we offer a beautiful UI (Ola), the real power is our **Headless API**.

- **Scenario**: A Mortgage Lender has their own custom portal.
- **Integration**: They send us the raw documents via API.
- **Execution**: Our Agents spin up, read the docs, apply the Lender's
  "Instruction Set", and return a **Decision Memo**.
- **Result**: The Lender gets the "Brain" of a Senior Underwriter without hiring
  one.

## 4. Strategic Goals

| Horizon   | Goal                        | Metric                                                                                      |
| :-------- | :-------------------------- | :------------------------------------------------------------------------------------------ |
| **Now**   | **Merchant Underwriting**   | Prove the "Digital Employee" concept with Merchant Accounts.                                |
| **Next**  | **Multi-Vertical**          | Expand to Mortgages, Auto Loans, and Rentals using the _same_ Agent Core.                   |
| **Later** | **The "Brain" Marketplace** | Allow 3rd party experts to sell "Instruction Sets" (e.g., "The Perfect Crypto Risk Model"). |
