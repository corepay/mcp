# Feature Brief: Online Application (OLA) Portal

## 1. Executive Summary

The **Online Application (OLA)** is a dedicated portal for merchants to apply
for payment processing. Unlike traditional static forms, the OLA is a
**conversational, AI-driven experience** ("Atlas") designed to reduce
abandonment, automate data entry, and provide real-time feedback.

It transitions the application process from a "guest checkout" model to a
**Registration-First** model, ensuring data persistence and enabling long-term
engagement through a "Merchant Dashboard" that serves as the single source of
truth for the application status.

## 2. Core Philosophy: The "Anti-Form"

- **Conversational**: The primary interface is a chat with "Atlas", an AI agent
  that conducts a structured interview.
- **Proactive**: Atlas validates data in real-time (e.g., "That ID is blurry")
  and suggests improvements (e.g., "Be more specific with your business
  description").
- **Registration-First**: Users create an account immediately, allowing for
  "Save & Resume" and secure document storage.
- **Transparent**: The "Pizza Tracker" status bar eliminates the "black hole"
  anxiety of underwriting.

## 3. Key Components

### 3.1. The "Atlas" Interview

A split-screen interface where the AI chat (left/right) guides the user through
the form (center).

- **Auto-Fill**: Atlas uses public APIs (Google Places, SOS) to fill fields
  based on simple inputs (e.g., "I'm Acme Coffee in Seattle").
- **Magic Camera**: A QR code handoff allows users to seamlessly upload
  documents via their mobile phone camera without installing an app.
- **Contextual Help**: The AI explains _why_ data is needed (e.g., "We need your
  SSN for a soft credit check, it won't affect your score").

### 3.2. The Applicant Dashboard

Once the initial interview is complete, the user lands on a dashboard.

- **Status Tracker**: Visual progress bar (Received -> Risk Check -> Bank
  Verification -> Decision).
- **Document Vault**: Secure area to view, upload, and manage required
  documents.
- **Notification Hub**: Alerts for required actions (e.g., "Sign the updated
  agreement").
- **Human Escalation**: Direct line to a human underwriter if the AI cannot
  resolve an issue.

### 3.3. The "Best Offer" Engine

(For Payfac-as-a-Service Tenants)

- **Dynamic Upsell**: If a merchant qualifies for better rates (e.g., Retail
  ISO), the system proactively offers an upgrade.
- **Downsell/Save**: If a merchant fails standard underwriting, they are offered
  a "Starter Account" (Payfac) instead of a hard rejection.

## 4. User Journey

1. **Landing**: Marketing-style page explaining benefits.
2. **Registration**: Email/Password creation (or OAuth).
3. **The Interview**:
   - **Business Profile**: Entity, Address, Tax ID.
   - **Ownership**: Beneficial Owners, IDs.
   - **Financials**: Volume, Ticket Size, Banking (Plaid).
4. **Review & Sign**: E-Signature of terms.
5. **Dashboard**: Post-submission tracking and remediation.
6. **Approval**: Transition to the full Merchant Portal.

## 5. Technical Strategy

- **Endpoint**: `/ola` (Promoted from `/online-application`).
- **Stack**: Phoenix LiveView for real-time interactivity.
- **AI**: "Atlas" (LLM-driven) for chat and data extraction.
- **Storage**: Encrypted `application_data` (JSONB) and S3 for documents.
- **Integration**: ComplyCube (KYC/KYB), Plaid (Banking), Experian (Credit).
