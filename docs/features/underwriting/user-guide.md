# User Guide: Operating the Sovereign Engine

## 🤵 The Merchant Atlas Concierge

Atlas is a proactive assistant that lives on the merchant-facing application. As an underwriter, you benefit from the "cleaned" data Atlas produces, but you can also monitor its interactions.

### 1. Intelligent Intake Workflow
- **Proactive Help**: Atlas watches for "idle" time on difficult fields (like EIN or SSN). It interjects with friendly guidance before the user gives up.
- **Suggestion Mode**: If a merchant enters a vague business description (e.g. "I sell stuff"), Atlas suggests a more detailed entry (e.g. "Tell us about your products and target market") to help the deal pass the automated risk filters.
- **Encouragement**: Atlas provides positive reinforcement as the user completes sections, maintaining high conversion velocity.

## 🌉 The "Amber Zone" (Cognitive Resolution)

Not every deal is a clear "Approve" or "Reject". Complex deals enter the **Amber Zone**, where AI-Human collaboration takes place.

### 2. The Sovereign Brief
When a deal enters the Amber Zone, the system generates a **Sovereign Brief** for you to review.
- **Decision Lineage**: View the exact Playbook rules that flagged the deal.
- **The Evidence Vault**: Click any risk factor to see the supporting evidence (website snapshots, raw KYB results, or OCR-extracted document data).

### 3. Atlas "Healing" Chat (Autonomous Negotiation)
While you review the brief, Atlas is already working on your behalf.
- **Data Collection**: If a document is blurry or an address doesn't match, Atlas asks the merchant for a new version or clarification.
- **Chat History**: You can view the full transcript of Atlas's negotiation with the merchant inside the Underwriting Dashboard.
- **Manual Intervention**: You only step in if Atlas's autonomous "Healing" fails to resolve the data gap.

## 💰 Managing Bank Placements

The engine suggests the "Best Match" for every application through the **Profit-Aware Router**.

### 4. Why was this Bank chosen?
Click the **Rationale** icon to see the logic.
- **Regional Match**: Verify that the processor's supported countries cover the merchant's location.
- **Risk Weighting**: See how the application's score (e.g. 85) aligns with the bank's appetite rule (e.g. min score 80).
- **Yield Potential**: The system prioritizes the most profitable bank that is compatible with the merchant's risk profile.

## 🖥️ Underwriting Dashboard Operations

### 5. Managing Playbooks (Your Policy Engine)
Playbooks are where you define the platform's risk appetite.
- **Writing Rules**: Use natural language in Markdown. (e.g., `* Reject if industry is 'gambling'.`)
- **Versioning**: Every change to a Playbook generates a new SHA-256 hash. This hash is permanently stamped on every decision made while that version was active.
- **Simulation**: Use the **Playbook Concierge** to test new rules against historical applications before making them active.

## 🆘 Troubleshooting Boarding Failures

If a boarding record transitions to `:failed`:
1. Open the **Audit Log Side Drawer**.
2. Examine the **Error Metadata**: This contains the raw response from the processor API (e.g., "Invalid Business License").
3. **Correct & Retry**: Fix the data on the Application resource and click **Retry Boarding**.

## 📅 Best Practices for Underwriters
- **Audit your Playbooks quarterly** to ensure rules match the current economic climate.
- **Review Atlas transcripts** periodically to identify common merchant pain points.
- **Monitor the SLAs**: Ensure `pending` boardings are synced if they exceed the 24-hour mark.
