# Applicant Portal UX & Workflow Design

## 1. The "Atlas" Conversational Flow

The application is not a form; it is a **Structured Interview**.

### 1.1. The "Handshake" (Registration)

- **Goal**: Create the account and capture intent.
- **Data**: Name, Email, Password, Phone (2FA).
- **AI Action**: "Hi [Name], I'm Atlas. I'll help you get approved. First, tell
  me a bit about your business so I can tailor the questions."

### 1.2. Business Profile (The "Entity")

- **Input**: "We are a coffee shop in Seattle."
- **AI Action**:
  - _Auto-Fill_: Looks up "Coffee Shops in Seattle" via Google Places API.
  - _Confirm_: "Are you 'Seattle Best Coffee' at 123 Pike St?"
- **Data Points**:
  - Legal Name & DBA
  - Address (Physical & Mailing)
  - Tax ID (EIN)
  - Business Type (LLC, Sole Prop, etc.)
  - Website / Social URL
  - Date Established

### 1.3. Ownership (The "Humans")

- **Requirement**: Beneficial Owners (>25% equity).
- **UX**: "Who owns the business?"
- **Data Points**:
  - Full Name
  - Home Address
  - SSN (Last 4 or Full for Credit Check)
  - Date of Birth
  - % Ownership
  - **Document**: Photo ID (Driver's License / Passport) - _Upload or Mobile
    Handoff_.

### 1.4. Financial Profile (The "Risk")

- **UX**: "How do you take payments?"
- **Data Points**:
  - Estimated Annual Volume ($)
  - Average Ticket Size ($)
  - Max Ticket Size ($)
  - Delivery Timeframe (0 days, 7 days, 30 days)
  - MCC (Merchant Category Code) - _AI suggests this based on description_.

### 1.5. Banking (The "Payouts")

- **UX**: "Where should we send your money?"
- **Method**: Plaid Link (Preferred) or Manual Entry.
- **Data Points**:
  - Bank Name
  - Routing Number
  - Account Number
  - **Document**: Voided Check or Bank Letter (if Plaid fails).

## 2. The "Smart" Features

### 2.1. Real-Time Validation

- **Address**: Validated against USPS/Google Maps.
- **EIN**: Validated against IRS format.
- **Bank**: Validated via Routing Number checksum.

### 2.2. The "Magic Camera" (Mobile Handoff)

1. Desktop shows QR Code: "Scan to upload ID".
2. User scans with phone.
3. Phone opens secure camera web-app.
4. User snaps ID.
5. Desktop auto-refreshes: "Got it! Analyzing..."

### 2.3. "Save & Resume"

- User drops off at "Banking".
- Atlas sends email: "We saved your spot. Click here to finish."
- Link is a magic link (no login required for 24 hours).

## 3. The "Best Offer" Screen (The Pivot)

Before the final review, the AI analyzes the profile and presents the optimal
account type. _(Note: This screen only appears if the Tenant has enabled
**Hybrid Boarding**)._

### 3.1. Scenario A: The "Graduation Offer" (Payfac -> Retail)

- **AI Insight**: "Your volume ($100k/yr) and Credit (780) qualify you for lower
  rates."
- **UI**: "🎉 **Upgrade Available**: You applied for Standard (2.9%), but you
  qualify for **Pro Direct** (IC + 0.20%). You'll save ~$800/year. Switch now?"

### 3.2. Scenario B: The "Path to Yes" (Retail -> Payfac)

- **AI Insight**: "Your business is too new for a Direct MID."
- **UI**: "⚠️ **Not Ready for Direct... Yet**: We can't approve a Direct MID
  today. **However**, we have pre-approved you for a **Starter Account**. Start
  processing today, and we'll review you for an upgrade in 3 months."

## 4. The "Review" Step

- **Summary Screen**: AI summarizes the application.
- **Terms & Conditions**: "Click to Sign" (E-Signature).
- **Submission**: "Submitting to Underwriting..." -> "Received! Atlas is
  reviewing your file."
