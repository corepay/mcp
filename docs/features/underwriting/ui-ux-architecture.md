# Sovereign Underwriting UI/UX Architecture

## 1. The Merchant Experience: "Active Interceptor"
*Goal: High-touch guidance to "Heal" data at the source.*

### Interaction Model
*   **Default State**: Minimal, seamless form. "Noir" aesthetic (Dark mode, high contrast).
*   **The Trigger**: Field-level validation or "Idle" detection (user stuck for >10s).
*   **The Interception**:
    *   **Visual**: The form field glows Amber.
    *   **Action**: Atlas expands *inline* (accordion style) below the field.
    *   **Content**: "It looks like your description is a bit vague. Banks generally prefer 2-3 sentences about your target market. Here is a suggestion based on your industry..."
    *   **Resolution**: User accepts suggestion (auto-fill) or types a better answer. Field turns Emerald (Green).

### Key Components
1.  **Atlas Widget**: Floating "orb" that tracks progress.
2.  **Inline Healer**: The expansion panel for corrections.
3.  **Omnichannel Uploader**: Drag-and-drop zone that accepts CamScanner/Mobile photos directly.

---

## 2. The Underwriter Experience: "Context-Aware Panopticon"
*Goal: High-density, single-screen decisioning.*

### Layout Architecture (3-Column)

#### Column 1: The Queue (20%)
*   **Function**: Triage & Navigation.
*   **Content**:
    *   List of "Amber Zone" applications.
    *   Sorted by SLA urgency (Timer counting down).
    *   Visual "Badges" for primary risk factor (e.g., "High Vol", "IP Mismatch").

#### Column 2: The Evidence Canvas (50%)
*   **Function**: Truth Verification (The Input).
*   **Content**: A vertical scrolling feed of rich media.
    *   **Card 1**: Business Entity (SOS Filing PDF + KYB JSON summary).
    *   **Card 2**: "The Eye" Result (Storefront Street View + Deep Learning confidence score).
    *   **Card 3**: Financials (Plaid/Stripe avg daily balance charts).
    *   **Card 4**: Atlas Transcript (Full chat log of the "Healing" session).

#### Column 3: The Sovereign Control Plane (30%)
*   **Function**: Decision & Governance (The Output).
*   **Position**: Sticky/Fixed (Never scrolls).
*   **Content**:
    *   **Risk Score**: Large, color-coded integer (0-100).
    *   **Lineage**: SHA-256 Hash of the active Playbook.
    *   **Precedent**: "94% similar to [Approved Case #123]".
    *   **Profit-Aware Routing**: "Recommended: QorPay (2.4% yield)".
    *   **Actions**: [Approve], [Request Info], [Reject].

---

## 3. Visual Language ("Noir")
*   **Background**: `#0a0a0a` (OLED Black).
*   **Surface**: `#141414` (Dark Grey).
*   **Accents**:
    *   **Emerald (#2ecc71)**: Verified, Safe, Profitable, Active.
    *   **Amber (#f39c12)**: Warning, Healing Required, Manual Review.
    *   **Crimson (#e74c3c)**: Fraud, Rejected, Critical Failure.
*   **Typography**: `Inter` for UI, `JetBrains Mono` for Data/Hashes.
