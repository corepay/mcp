# Sovereign Underwriting UI/UX Architecture

## 1. The Merchant Experience: "Active Interceptor"

_Goal: High-touch guidance to "Heal" data at the source._

### Interaction Model

- **Default State**: Minimal, seamless form. "Noir" aesthetic (Dark mode, high contrast).
- **The Trigger**: Field-level validation or "Idle" detection (user stuck for >10s).
- **The Interception**:
  - **Visual**: The form field glows Amber.
  - **Action**: Atlas expands _inline_ (accordion style) below the field.
  - **Content**: "It looks like your description is a bit vague. Banks generally prefer 2-3 sentences about your target market. Here is a suggestion based on your industry..."
  - **Resolution**: User accepts suggestion (auto-fill) or types a better answer. Field turns Emerald (Green).

### Key Components

1.  **Atlas Widget**: Floating "orb" that tracks progress.
2.  **Inline Healer**: The expansion panel for corrections.
3.  **Omnichannel Uploader**: Drag-and-drop zone that accepts CamScanner/Mobile photos directly.

---

## 2. The Underwriter Experience: "Context-Aware Panopticon"

_Goal: High-density, single-screen decisioning with zero context switching._

### Layout Architecture (The Sovereign Workbench)

#### Column 1: The Intelligence Queue (20%)

- **Function**: Triage & Navigation.
- **Aesthetic**: `bg-base-200` with `border-base-300` (OLED Surface).
- **Content**:
  - List of active applications triaged by the Atlas Reactor.
  - Live indicators of assessment status (Submitted, Verified, Rejection Pending).
  - High-contrast OLED focus for selected items.

#### Column 2: The Evidence Canvas (50%)

- **Function**: Truth Verification (The Multimodal Input).
- **Aesthetic**: `bg-base-100` (Deep OLED focus).
- **Content**: A vertical feeding of forensic signals and source documents.
  - **Application Data**: Business and processing profiles in `glass-panel` containers.
  - **Forensic Documents**: Interactive PDF/ID viewports with confidence scores.
  - **Registry Data**: SOS state records and "Raw Payload" deep-dives.
  - **Financials**: 90-day liquidity signals (NSF, Chargeback ratio) and risk열 heatmaps.

#### Column 3: The Sovereign Control Plane (30%)

- **Function**: Decision & Governance (The Output Factory).
- **Aesthetic**: `bg-base-200` with fixed/sticky positioning.
- **Content**:
  - **Sovereign Score**: Color-coded risk meter (0-100) linked to `active-emerald/amber/crimson` logic.
  - **Atlas Copilot**: AI commentary on identified signals and placement strategies.
  - **Decision Lineage**: Immutable SHA-256 fingerprinting of the active Playbook.
  - **Action Drawer**: Semantic-mapped actions: `[Approve]` (Primary), `[Reject]` (Error), `[Request Info]` (Base-300).

---

## 3. Visual Language ("Noir v2 - Semantic")

- **Philosophy**: Extreme density, forensic clarity, and OLED battery efficiency.
- **Theme**: `noir` via DaisyUI.
- **Surface Palette**:
  - `base-100`: Primary backgrounds (Deep Black).
  - `base-200`: Secondary surfaces (OLED Grey).
  - `base-300`: Elevated components and dividers.
- **Signal Palette** (Semantic Mappings):
  - **Primary (#10b981)**: Verified, Approved, Safe, Profitable (Success).
  - **Warning (#f59e0b)**: Manual Review, Missing Evidence, Potential Risk.
  - **Error (#ef4444)**: Rejection, Fraud Detection, Signal Mismatch (Crimson).
  - **Accent (#6366f1)**: Intelligence Scans, AI Insights, Active Processing.
- **Typography**: `Inter` for interface-level labels; `JetBrains Mono` for all raw data and hashes.
