# Atlas AI: The Intelligent Core of MCP

**Atlas** is not just a chatbot; it is the intelligent substrate of the MCP
platform, designed to augment both Merchants and Underwriters.

## 1. Core Architecture

Atlas is built on a "Tri-Brain" architecture:

### 👁️ The Eye (Vision)

- **Service**: `apps/the_eye` (Python/FastAPI)
- **Engine**: `marker` (PDF/Tables) + `chandra` (OCR/Forms)
- **Capability**: Reads complex documents (Bank Statements, Tax Returns, IDs)
  with high fidelity. It doesn't just "extract text"; it understands **layout**
  and **structure** (e.g., converting a PDF bank statement into a structured
  Markdown table).

### 🧠 The Brain (Reasoning)

- **Tier 1 (Reflex)**: Local Llama 3 (Ollama). Fast, free, privacy-first.
  Handles basic routing, classification, and simple extraction.
- **Tier 2 (Expert)**: Claude 3.5 Sonnet (via OpenRouter). Deep reasoning,
  financial analysis, and complex decision-making.

### 🗣️ The Mouth (Interaction)

- **Merchant Portal**: Embedded chat assistant to guide applicants.
- **Admin Portal**: "Co-Pilot" sidebar for Underwriters to collaborate with the
  AI.

---

## 2. Capabilities & Opportunities

### For the Merchant (The Applicant)

- **"Zero-Entry" Applications**:
  - _Capability_: Merchant uploads a PDF Bank Statement.
  - _Opportunity_: Atlas extracts Business Name, Address, Volume, and Account
    Numbers automatically. The form fills itself.
- **Instant Feedback (Auto-Remediation)**:
  - _Capability_: Atlas checks documents _before_ submission.
  - _Opportunity_: "Hey, this ID is blurry. Can you retake it?" prevents days of
    back-and-forth delays.
- **Pre-Qualification**:
  - _Capability_: Atlas analyzes cash flow in real-time.
  - _Opportunity_: "Based on your $50k monthly volume, you qualify for our
    Premium Rate of 2.1%."

### For the Underwriter (The Risk Officer)

- **Autonomous Financial Analysis**:
  - _Capability_: "Analyze this 50-page statement."
  - _Opportunity_: Atlas calculates Average Daily Balance, NSF counts, and
    Debt-to-Income ratio in seconds.
- **Risk Scoring**:
  - _Capability_: Cross-reference application data with document data.
  - _Opportunity_: "The application says $1M volume, but bank statements show
    $200k. Flagged for review."
- **The Co-Pilot**:
  - _Capability_: Interactive chat sidebar.
  - _Opportunity_: Underwriter asks, "Does this business have any undisclosed
    loans?" Atlas scans the transaction history for "Kabbage" or "OnDeck"
    withdrawals.

## 3. The "Graph RAG" Advantage

Atlas isn't just reading text; it's traversing a **Knowledge Graph**. We combine
**Vector Search** (Semantic) with **Graph Database** (Structural) to achieve
"Graph-Augmented RAG".

### The Problem with Standard RAG

Standard RAG (Vector Search) is good at finding _similar text_.

- _Query_: "Has this applicant committed fraud?"
- _Vector Result_: Finds documents containing the word "fraud" (likely none).
  **Misses the risk.**

### The Solution: Graph + Vector

We use `AshGraph` to map relationships and `pgvector` to understand content.

#### 1. Entity Resolution (The "Who")

- **Graph Query**:
  `Merchant -> Owner (John Doe) -> Previous_Merchant (Failed Biz LLC) -> Risk_Flag (Chargeback Spike)`
- **Insight**: Atlas sees that John Doe, who is applying now, owned a business
  that collapsed due to fraud 3 years ago. Vector search would never find this
  connection because the _names_ of the businesses are different.

#### 2. Network Analysis (The "Web")

- **Graph Query**: `Merchant -> Address -> Other_Merchants_At_Same_Address`
- **Insight**: "Warning: 15 other LLCs are registered at this exact residential
  address. High probability of a 'Shell Company' farm."

#### 3. Holistic Risk Profile (The "Synthesis")

Atlas combines these signals into a single reasoning context:

> "While the bank statements look clean (Vector Analysis), the Graph reveals
> this applicant is linked to a known fraud ring via a shared beneficial owner
> (Graph Analysis). Recommendation: **Reject**."

## 4. Technical Stack

| Component       | Technology             | Purpose                                               |
| :-------------- | :--------------------- | :---------------------------------------------------- |
| **Sidecar**     | Python / FastAPI       | Hosting AI models (The Eye)                           |
| **LLM Gateway** | LangChain / OpenRouter | Routing prompts to the right model                    |
| **Vector DB**   | pgvector               | Long-term memory and document search                  |
| **Graph DB**    | AshGraph / Postgres    | Modeling complex relationships (Owner -> Biz -> Risk) |
| **Backend**     | Elixir / Ash           | Orchestration and Business Logic                      |
| **Frontend**    | Phoenix LiveView       | Real-time Chat & Co-Pilot UI                          |

## 5. Future Frontiers: The Long Game

Building the Graph is a long-term strategy. While Year 1 focuses on efficiency
(RAG/OCR), Year 3 unlocks "Pre-Cognition" capabilities that create a massive
data moat.

### Frontier #1: The Federated Reputation System (Cross-Tenant Intelligence)

- **Concept**: A "Global Blocklist" shared across all Tenants (ISOs) without
  sharing PII.
- **Value**: If a fraudster burns Tenant A, Tenant B automatically rejects them
  minutes later because the Graph sees the shared digital fingerprint (device
  ID, IP subnet, or beneficial owner).
- **Result**: MCP becomes the "Credit Bureau" of Merchant Acquiring.

### Frontier #2: Supply Chain Risk (B2B Graphs)

- **Concept**: Underwriting the merchant's _ecosystem_ by mapping their vendors
  via bank statement analysis.
- **Value**: "This construction company is paying a lumber supplier that went
  bankrupt last week." -> **Predictive Default**.
- **Result**: Detecting upstream risks before they impact the merchant's ability
  to pay.

### Frontier #3: Temporal Graphs (Time-Travel)

- **Concept**: Analyzing "What changed?" rather than just "What exists now."
- **Value**: Detecting "Bust-Out Fraud" patterns, such as a merchant slowly
  shifting inventory from "Office Supplies" to "Crypto Mining Equipment" over 6
  months.
- **Result**: Identifying "drift" in risk profiles that snapshot analysis
  misses.
