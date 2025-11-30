# Stakeholder Guide: Specialty Agents

## Business Value

The Specialty Agents system transforms the platform from a static software
application into a **dynamic, intelligent workforce**.

### 1. Agility & Speed to Market

New underwriting rules or risk policies can be deployed instantly by updating an
`InstructionSet`. There is no need for a software release cycle, code review, or
deployment window. Business users can adjust risk tolerance in real-time.

### 2. Multi-Tenant Customization

We can serve diverse clients with a single platform. A "Conservative Bank"
tenant can have strict, document-heavy instructions, while a "Fintech Startup"
tenant can have streamlined, automated instructions—all using the same
underlying AI agents.

### 3. Auditability & Governance

Every agent configuration is stored as a database record. We can track exactly
_what_ instructions were active at the time of any decision. This provides a
clear audit trail for regulatory compliance, explaining _why_ an AI made a
specific decision.

## Use Cases

- **Policy Updates**: "Update the DTI threshold from 43% to 45% for Q4." (Done
  via Admin UI, instant effect).
- **New Products**: "Launch a 'Jumbo Loan' product with specialized risk
  checks." (Create new Instruction Set).
- **A/B Testing**: "Test a stricter fraud check on 50% of traffic." (Manage via
  Pipeline configuration).
