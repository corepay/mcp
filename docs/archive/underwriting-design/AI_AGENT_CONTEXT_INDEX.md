# AI Agent Context Index: Merchant Underwriting & Payfac

> **System Note**: This document serves as the **Single Source of Truth** for
> the AI Agent. It indexes all strategic decisions, business models, and design
> patterns agreed upon. **Always read this first** before making architectural
> decisions.

## 1. Strategic Core

| Document                                               | Purpose       | Key Decisions                                                                                                                                                                                                                                   |
| :----------------------------------------------------- | :------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [**Business Model**](UNDERWRITING_BUSINESS_MODEL.md)   | **The "Why"** | • **Gateway Pattern**: Buy wholesale ($2), sell retail ($5).<br>• **Hybrid Strategy**: Bridge between Payfac & Retail.<br>• **Lost Revenue Report**: Upsell tool for Payfac-as-a-Service.<br>• **BYOK**: Enterprise orchestration fee ($1/app). |
| [**Vendor Strategy**](UNDERWRITING_VENDOR_STRATEGY.md) | **The "Who"** | • **Adapter Pattern**: Abstract vendors behind `Mcp.Underwriting.Adapter`.<br>• **Primary**: ComplyCube (for now).<br>• **Future**: Smart Routing based on cost/region.                                                                         |

## 2. Product & Design

| Document                                                   | Purpose        | Key Decisions                                                                                                                                                                     |
| :--------------------------------------------------------- | :------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [**Applicant UX**](APPLICANT_PORTAL_UX.md)                 | **The "How"**  | • **"Atlas" Concierge**: Conversational UI, not a form.<br>• **Magic Camera**: Mobile handoff for ID scan.<br>• **Best Offer Screen**: Dynamic upsell/downsell before submission. |
| [**Pipeline Design**](PIPELINE_MANAGEMENT_DESIGN.md)       | **The "Flow"** | • **Kanban**: Leads -> Draft -> Underwriting -> Approved.<br>• **Deal Room**: Collaboration for large deals.<br>• **SLA Timer**: "Ticking clock" for reviews.                     |
| [**Data Requirements**](UNDERWRITING_DATA_REQUIREMENTS.md) | **The "What"** | • **Schema**: `merchant`, `owners` (JSONB).<br>• **Mapping**: Maps internal fields to ComplyCube `POST /checks`.<br>• **Risk Score**: Weighted algo (30% ID, 20% Credit, etc.).   |

## 3. Technical Architecture (The "Build")

### 3.1. Domain Structure

- **Domain**: `Mcp.Underwriting` (NOT `Mcp.Merchants`).
- **Resources**:
  - `Application`: The core aggregate. Stores state and JSON payload.
  - `Review`: The decision record (Human or AI).
  - `RiskAssessment`: The raw data from vendors (ComplyCube).

### 3.2. The "Gateway" Pattern

We do not couple code to ComplyCube.

- **Behaviour**: `Mcp.Underwriting.Adapter` (verify_identity, screen_business).
- **Implementation**: `Mcp.Underwriting.Adapters.ComplyCube`.
- **Factory**: `Mcp.Underwriting.Factory.get_adapter(tenant_config)`.

### 3.3. AI "Expert Assist"

- **Tier 1**: Local LLM (Ollama) for basic parsing.
- **Tier 2**: Frontier Model (Gemini/GPT-4) for "Senior Analyst" advice and
  "Lost Revenue" reports.

## 4. Implementation Roadmap

1. **Foundation**: Create Domain & Resources.
2. **Gateway**: Implement `MockAdapter` (for testing) and `ComplyCubeAdapter`.
3. **Orchestration**: Build the `Application` state machine (Draft -> Submitted
   -> Review).
4. **UX**: Build the "Atlas" API and React Frontend.
5. **Intelligence**: Wire up the Risk Scoring and Expert AI.
