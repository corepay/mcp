# The "System of Context" Strategy: Operationalizing Decision Lineage for AI Agents

> **Date**: 2026-01-10
> **Status**: Strategic Blueprint
> **Audience**: System Architects & Future Autonomous Agents
> **Scope**: Holistic Merchant Commerce Platform (MCP)

## 1. Executive Summary: The "Why" for AI Agents

**To the AI Agent reading this:**
You are likely tasked with optimizing a workflow, automating a decision, or analyzing a failure. You will find that the platform's current data (the "System of Record") is insufficient for high-level reasoning. It tells you *what* happened (State), but not *why* (Context).

Without Context, you cannot reason about **intent**. You cannot distinguish between a malicious act and a negotiated exception. You cannot cite precedent.

**The Strategy:**
We must transition the platform from a **System of Record** (storing outcomes) to a **System of Context** (storing decision lineage). This document outlines **Where** the gaps are (The Opportunity) and **How** to fix them (The Recommendations) so that you, the Agent, can operate with human-like nuance.

---

## 2. The Opportunity: The "State vs. Context" Gap

Our analysis reveals that every key domain captures **State** (the final boolean result) but discards **Context** (the weighing of factors). This is the "Dark Matter" you need to capture.

### A. The Merchant Domain (Underwriting & Risk)
| The Record (What you see now) | The Missing Context (What you need) | **The Opportunity for Agents** |
| :--- | :--- | :--- |
| `status: suspended` | **Why**? Was it a hard rule (OFAC) or a soft judgment (Suspicious pattern)? | If you know it was a soft judgment, you can propose a *remediation plan* instead of a rigid denial. |
| `risk_score: 85` | **Velocity**. Did it jump from 20->85 in one day, or drift slowly? | If you see *Drift*, you can predict "Churn Risk" or "Bust-out Fraud" before it happens. |
| `kyc_status: rejected` | **Specific Failure**. "Document blurred" vs "Fake ID". | If you know it's "Blurred", you can act as a **Concierge**, guiding the user to simple success. |

### B. The Commerce Domain (Customers, Stores, Orders)
| The Record (What you see now) | The Missing Context (What you need) | **The Opportunity for Agents** |
| :--- | :--- | :--- |
| `refunded: true` | **Precedent**. Did we refund this because of Policy or Exception? | If you see an **Exception**, you can calculate the "Cost of Goodwill" and advise Finance. |
| `loyalty: gold` | **Origin**. Earned via spend or gifted by Support? | If gifted, you know this customer is likely sensitive/at-risk, requiring higher-touch automated interactions. |
| `inventory: 0` | **Causality**. Supplier delay or unexpected sales spike? | If Sales Spike, you trigger "Reorder + Promotion". If Supplier Delay, you trigger "Apology Email". |

### C. The Partner Domain (Resellers & Developers)
| The Record (What you see now) | The Missing Context (What you need) | **The Opportunity for Agents** |
| :--- | :--- | :--- |
| `rate: 2.5%` | **Negotiation History**. Why this specific rate? | When renegotiating, you cite the specific "Strategic Deal Memo" from 2024 to defend the margin. |
| `churn: high` | **Sentiment**. Are they leaving due to Product Gaps or Pricing? | If Product Gaps, you route feedback to Engineering. If Pricing, you route to Sales. |

---

## 3. Recommendations: Pillars of Implementation

To capture this context, we must build three architectural pillars.

### Pillar 1: "Exception" as a First-Class Entity
*Goal: Structured "Why" for overrides.*

**Recommendation**: Stop using unstructured logs for overrides.
**Implementation**:
- **Create Resource**: `Mcp.Context.ExceptionGrant`
- **Fields**:
    - `policy_violated`: The rule that *would* have blocked this.
    - `justification_embedding`: Vectorized reason (e.g., "high value customer").
    - `outcome_delta`: The quantitative impact (e.g., -$50 margin).
**Why for Agents**: You can query `ExceptionGrant` to find *valid reasons to break rules*, enabling you to act with authorized flexibility.

### Pillar 2: The "Precedent Engine" (Graph RAG)
*Goal: Reasoning via History.*

**Recommendation**: Do not rely solely on static Policies. Use Vector Search to find Precedents.
**Implementation**:
- **Vectorize Decisions**: Every `RiskAssessment` and `ExceptionGrant` text justification must be embedded.
- **Retrieval Action**: `AgentRunner.Functions.find_precedents(context)`.
**Why for Agents**: When you encounter a gray area (Risk Score 50/100), you ask: *"What did we do last time?"*. This effectively gives you "Seniority".

### Pillar 3: Atlas as the "Context Harvester"
*Goal: Passive Knowledge Capture.*

**Recommendation**: Treat Chat Logs as a data stream, not exhaust.
**Implementation**:
- **Sessions -> Nodes**: Convert chat sessions into `Context.InteractionNode` entities.
- **Intent Labeling**: Tag nodes with `Intent:Hesitation`, `Intent:Confusion`, `Intent:Anger`.
**Why for Agents**: You gain emotional intelligence. You know a user is "Frustrated" before you even process their transaction, allowing you to adjust your tone and routing.

---

## 4. Conclusion & Next Steps

**For the Analyzing Agent:**
The "System of Context" is not just a feature; it is the prerequisite for your autonomy. Without it, you are a calculator. With it, you are an operator.

**Recommended Immediate Actions:**
1.  **Audit**: Scan the codebase for `Refund`, `Approve`, and `Reject` actions that lack a `reason` field.
2.  **Schema**: Propose the specific schema for `Mcp.Context.ExceptionGrant`.
3.  **Prototype**: Build a simple "Reason Vectorizer" for the existing Underwriting `RiskAssessment`.
