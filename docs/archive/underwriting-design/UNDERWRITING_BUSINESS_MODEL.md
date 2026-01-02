# Underwriting Business Model & Pricing Strategy

## 1. The Core Philosophy: Compliance as a Product

Traditionally, compliance is a **Cost Center** (something you pay for to avoid
fines). We are flipping this to make compliance a **Revenue Center** (something
you sell to tenants as a premium service).

**The Mechanism**: The "Compliance Gateway" Arbitrage. We buy identity
verification in bulk (wholesale) and sell it to tenants per-application
(retail).

## 2. Cost Structure (The "Buy" Side)

Based on ComplyCube (and similar vendors like Veriff/Persona), our raw costs
are:

| Component                 | Vendor Cost (Est.) | Notes                                |
| :------------------------ | :----------------- | :----------------------------------- |
| **Standard Screening**    | $0.35              | AML, PEP, Sanctions Watchlists       |
| **Document Verification** | $0.80              | Government ID scan & validation      |
| **Liveness Check**        | $0.20              | Selfie video/photo check             |
| **Business Lookup (KYB)** | $0.90              | Company registry verification        |
| **Total "Full" Check**    | **~$2.25**         | For a complete merchant verification |

_Note: Costs decrease significantly with volume commitments._

## 3. Pricing Models (The "Sell" Side)

We recommend a hybrid pricing strategy to maximize adoption and margin.

### Model A: The "Pay-As-You-Grow" (Transactional)

Best for smaller tenants who don't want fixed costs.

- **Price**: **$5.00 per Merchant Application**
- **Includes**: Full KYC + KYB check + AI Risk Score.
- **Margin**:
  - Revenue: $5.00
  - COGS: $2.25
  - **Profit**: **$2.75 per app (55% Margin)**

### Model B: The "SaaS Bundle" (Subscription)

Best for enterprise tenants. Bundles checks into their monthly platform fee.

- **"Growth" Plan**: Includes 20 checks/month.
- **"Scale" Plan**: Includes 100 checks/month.
- **Overage**: Charged at $4.50/check.
- **Benefit**: **Breakage**. Many tenants won't use their full allowance,
  pushing effective margins to 80%+.

### Model C: The "Risk Guarantee" (Premium)

A bold offering where we take on some liability.

- **Price**: **$15.00 per Approved Merchant**
- **Promise**: "If we approve them and they turn out to be fraudulent within 90
  days, we refund the fee + $50 credit."
- **Benefit**: Signals extreme confidence in our AI. High margin ($12.75 profit)
  for high-quality traffic.

## 4. Revenue Projections (Scenario)

**Scenario**: A Tenant with 500 sub-merchants onboarding per month.

### Traditional Cost Center Approach

- Tenant pays vendor directly: 500 * $2.25 = $1,125 cost.
- **Our Revenue**: $0.

### Our "Gateway" Revenue Center Approach

- Tenant pays us ($5/app): 500 * $5.00 = $2,500 revenue.
- We pay vendor ($2.25/app): 500 * $2.25 = $1,125 cost.
- **Net Profit**: **$1,375 / month** (pure margin).

_Multiply this by 100 Tenants = **$137,500/month** in new, high-margin profit._

## 5. Strategic Value Adds

### 5.1. The "Unified Bill" Convenience

Tenants _hate_ managing separate contracts with ComplyCube, Middesk, and Ekata.

- **Value**: "One contract, one bill, one API." We handle the vendor complexity.

### 5.2. Smart Routing (Cost Optimization)

The tenant pays a flat $5.00. We optimize the backend.

- **Optimization**: For a low-risk "Sole Proprietor", we might skip the
  expensive $0.90 KYB check and just do a $0.35 Watchlist check.
- **Result**: Our COGS drops to $0.35, but we still charge $5.00. **Margin jumps
  to 93%.**

### 5.3. Data Resale (Future)

Once we verify a merchant for Tenant A, we have their "Verified Identity" token.

- **Future**: If that merchant signs up with Tenant B, we can "Instant Verify"
  them using our cached data.
- **Cost**: $0 (Data already paid for).
- **Price**: $2.50 (Discounted speed).
- **Margin**: **100%**.

## 6. The Agentic Value Multiplier (Why we charge a premium)

We aren't just reselling ComplyCube APIs. We are selling an **Autonomous
Underwriting Agent**. The value to the tenant goes far beyond the raw cost of
the check.

### 6.1. "Fail Fast" Cost Savings (The Gatekeeper)

The Agent is smart enough to stop spending money on bad applicants.

- **Scenario**: Applicant is on a Sanctions List (blocked).
- **Dumb Gateway**: Runs the full $2.25 check (Watchlist + ID + Liveness).
  **Cost: $2.25**.
- **Smart Agent**: Runs Watchlist ($0.35). Sees failure. Aborts ID/Liveness
  checks. **Cost: $0.35**.
- **Value**: **We save the tenant $1.90 per bad applicant.**

### 6.2. Autonomous Remediation (The Coach)

The Agent fixes problems _before_ they reach the human underwriter.

- **Scenario**: Applicant uploads a blurry ID.
- **Traditional Flow**: Underwriter opens file -> Rejects -> Emails merchant ->
  Merchant re-uploads -> Underwriter reviews again. **Cost: $20 in human
  labor.**
- **Agentic Flow**: Agent detects blur -> Prompts merchant immediately ->
  Merchant fixes -> Agent approves. **Cost: $0 in human labor.**
- **Value**: **We eliminate 80% of "back-and-forth" operational overhead.**

### 6.3. The "Perfect File" Handoff

When a human _does_ need to get involved, the Agent prepares a "Decision Memo".

- **Feature**: The Agent summarizes: "I verified the ID and Watchlist (Clean).
  The only flag is a mismatch in the Business Address. I recommend requesting a
  Utility Bill."
- **Value**: Reduces review time from 15 mins to 2 mins.

## 7. Total Value Proposition

| Feature                 | Value Driver            | Est. Value / App |
| :---------------------- | :---------------------- | :--------------- |
| **Wholesale Arbitrage** | Cheaper checks          | $1.00            |
| **Fail-Fast Logic**     | Wasted spend prevention | $0.50            |
| **Auto-Remediation**    | Human labor reduction   | $15.00           |
| **Conversion Lift**     | Higher approval rates   | $50.00+ (LTV)    |

**Conclusion**: While the "Check" costs $5.00, the **Service** is worth $50.00+.
This justifies a premium SaaS fee on top of the transactional costs.

## 8. The "BYOK" (Bring Your Own Key) Model

For enterprise tenants who already have negotiated rates with ComplyCube,
Veriff, or Persona.

### 8.1. The Problem

Large tenants often have volume discounts (e.g., paying $1.50/check) that beat
our wholesale rate. They don't want to pay us $5.00.

### 8.2. The Solution: Orchestration-as-a-Service

We allow them to plug in their own API keys. We charge for the **Intelligence**,
not the **Data**.

- **Price**: **$1.00 - $2.00 per Application** (Orchestration Fee).
- **Value Delivered**:
  - **Unified API**: They code to us once, we manage the vendor updates.
  - **Agentic Logic**: They still get the "Fail-Fast" savings and
    "Auto-Remediation" features.
  - **Vendor Redundancy**: They can use their primary key for 90% of traffic and
    fallback to our wholesale key for outages.

### 8.3. Strategic Benefit

This prevents "graduation risk" where a tenant grows too big and leaves us to go
direct to the vendor. We keep them in our ecosystem by shifting to a pure
software margin model.

## 9. OLA as a Service (The "Headless" Model)

For ISVs, Banks, and ISOs who want our "Magic Onboarding" but don't use our full
payment stack.

### 9.1. The Product

We unbundle the **Online Application (OLA)** and sell it as a standalone
white-label product.

- **Hosted OLA**: They point `apply.theirbank.com` to us.
- **Webhook Delivery**: We verify the merchant and POST the clean JSON payload
  to their legacy core system.

### 9.2. Target Audience

- **Legacy Banks**: Have terrible PDF forms but can't replace their core banking
  system.
- **Vertical SaaS**: Want to offer payments but are locked into a different
  processor (e.g., Worldpay).

### 9.3. Pricing Strategy

Since they aren't generating payments revenue for us, we charge a higher
software fee.

- **Platform Fee**: **$2,000/month** (for the white-label portal).
- **Application Fee**: **$10.00 per App** (includes checks).
- **Value**: They get a "Stripe-like" onboarding experience without rebuilding
  their entire infrastructure.

## 10. Go-To-Market & Adoption Strategy (My Final Recommendation)

The biggest barrier to selling "AI Underwriting" isn't price—it's **Trust**.

- _Tenant Fear_: "What if the AI approves a fraudster and I lose $50k?"

### 10.1. The "Interactive Co-Pilot" (HITL Launch)

Instead of a passive "Shadow Mode", we give tenants **Granular Control** from
Day 1.

1. **Push-Button Control**:
   - At every step (Identity, Watchlist, Risk Score), the Tenant Admin has 3
     options: **[Accept]**, **[Reject]**, or **[Request Info]**.
   - The AI provides the recommendation ("I recommend Rejecting because of X"),
     but the Human pushes the button.
2. **Real-Time Override Tracking**:
   - If the Human clicks **[Accept]** on an AI **[Reject]** recommendation, we
     log an "Override Event".
   - **The Feedback Loop**: We don't wait 30 days. The dashboard shows: _"You
     overrode the AI 5 times this week. 3 of those merchants are already showing
     risk signals."_
3. **Configurable Policy Engine (The "Automation Slider")**:
   - Tenants define the rules, not us.
   - _Example_: "Auto-Approve if Score > 90 AND ID is Verified".
   - _Example_: "Require HITL if Business Type = 'High Risk' OR Transaction
     Limit > $50k".
   - _Example_: "Auto-Reject if Sanctions Match = True".
   - **Benefit**: They automate the "easy" 80% and focus human attention on the
     "hard" 20%.

### 10.2. Vertical "Starter Packs"

Don't sell a generic model. Sell a specialist.

- **"The Restaurant Pack"**: Pre-tuned for low fraud, high volume, low ticket.
- **"The SaaS Pack"**: Pre-tuned for subscription billing and recurring revenue
  analysis.
- **Benefit**: Tenants feel the AI "understands" their specific niche
  immediately.

## 11. The "Expert AI" & Data Flywheel (Future Revenue)

We don't just consume data; we improve it.

### 11.1. Proprietary Model Training

- **The Loop**: Every chargeback and every successful transaction feeds back
  into our central model.
- **The Value**: "ComplyCube knows this ID is valid. **We** know that valid IDs
  from this specific IP range have a 40% fraud rate."
- **Monetization**: We sell "Enhanced Scoring" which beats raw vendor data.

### 11.2. The "Senior Analyst" (Expert AI)

- **Feature**: An LLM trained on 10,000 underwriting case studies.
- **Capability**:
  - **Clarity**: "Explain this rejection in plain English for the merchant."
- **Feature**: An LLM trained on 10,000 underwriting case studies.
- **Capability**:
  - **Clarity**: "Explain this rejection in plain English for the merchant."
  - **Advice**: "Should I approve this edge case? -> Yes, because their cash
    flow is strong."
  - **Vertical Smarts**: "For a Gym, this refund rate is normal. Don't flag it."

### 11.3. Predictive Analytics (LTV)

- **Insight**: "Merchants with this profile usually generate $12k/year in
  margin."
- **Action**: Tenant prioritizes onboarding these "Whales".

### 11.4. Infrastructure Costs (The "Brain" Budget)

While we use **Ollama (Local Llama 3)** for 90% of tasks (Zero Cost), the
"Expert Assist" requires a frontier model.

- **Tier 1 (Local)**: Data Extraction, Basic Chat. **Cost: $0** (Self-Hosted).
- **Tier 2 (Expert)**: Complex Reasoning, Legal Analysis. **Provider**: Gemini
  Pro / GPT-4o.
- **Est. Cost**: ~$0.10 per complex review.
- **Pricing**: Included in the $5.00 fee (2% of revenue), or billed as "Premium
  AI" add-on.

## 12. The Hybrid Strategy: Payfac <-> Retail Bridge

We don't just say "Yes" or "No". We say "Yes, and here is the best account for
you."

> **Requirement**: Available only to Tenants subscribed to
> **Payfac-as-a-Service**.

### 12.1. The "Instant Down-sell" (Retail -> Payfac)

- **Scenario**: Merchant applies for a Retail MID (Interchange + 0.10%) but has
  thin credit or low volume (<$5k/mo).
- **Old Way**: Reject. (Lost Revenue).
- **New Way**: "You don't qualify for a Retail MID _yet_. But we approved you
  for a **Starter Payfac Account** instantly. Process $50k, and we'll upgrade
  you."
- **Value**: We capture the merchant early and grow with them.

### 12.2. The "Proactive Up-sell" (Payfac -> Retail)

- **Scenario**: Merchant applies for Payfac (2.9% flat) but has $100k/mo volume
  and 800 Credit Score.
- **Action**: "Good news! You qualify for a **Direct Retail MID**. You'll save
  ~$500/month in fees. Want to switch?"
- **Value**: We build immense loyalty by saving them money proactively.

### 12.3. The "Lost Revenue" Report (The Upsell Tool)

For tenants who **don't** have Payfac-as-a-Service yet.

- **Action**: We track every "Soft Decline" (merchants who failed Retail
  underwriting but would have passed Payfac).
- **The Report**: "Last month, you rejected 15 merchants. If you had
  **Payfac-as-a-Service**, you would have approved them and earned an extra
  **$4,500/year**."
- **Result**: The feature pays for itself. Data-driven sales.

## 13. The Moonshot: A Shared Reputation Network

The ultimate defensive moat.

- **Scenario**: Merchant commits fraud with Tenant A. Tenant A bans them.
- **Network Effect**: Tenant B (who is also on our platform) gets an instant
  alert if that same merchant applies.
- **Value**: This creates a **Network Effect** where the platform becomes more
  valuable with every new tenant that joins. No standalone vendor (ComplyCube)
  has this cross-tenant context.
