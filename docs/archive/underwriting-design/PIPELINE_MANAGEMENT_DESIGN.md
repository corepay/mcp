# Merchant Pipeline & Funnel Management Design

## 1. Overview

This system acts as a **Specialized CRM** for merchant acquisition. It manages
the lifecycle from the moment a prospect registers (Lead) to when they process
their first transaction (Active Merchant).

**Users**:

1. **Tenants**: Manage the entire underwriting and boarding process.
2. **Resellers (ISOs/Partners)**: Manage their specific portfolio of referrals.

## 2. The Tenant Pipeline (The "Command Center")

### 2.1. Visual Kanban Board

A drag-and-drop interface tracking the merchant journey.

**Columns**:

1. **Leads (Registered)**: Created account but haven't started application.
   - _Action_: Send "Welcome" drip campaign.
2. **In Progress (Draft)**: Started application but stalled.
   - _Indicator_: "Stuck at 60% (Docs Upload)".
   - _Action_: "Nudge" button.
3. **Submitted (Underwriting)**:
   - _Sub-Status_: "AI Reviewing", "Manual Review Required", "Pending Info".
4. **Approved (Boarding)**:
   - _Action_: Provision MID, Send Welcome Kit.
5. **Active (Transacting)**:
   - _Goal_: First transaction processed.

### 2.2. The "Application Detail" View (The 360 View)

When a Tenant clicks a card, they see:

- **Timeline**: Every event (Registered -> Uploaded ID -> AI Flagged ->
  Approved).
- **Communication Log**: Chat history with "Atlas" (AI) and any human
  emails/notes.
- **Risk Dossier**: The compiled risk report (Score, Flags, Vendor Data).
- **Action Bar**: [Approve], [Reject], [Request Info], [Override AI].

## 3. The Reseller Portal (Partner Enablement)

Resellers drive volume. They need tools to close deals, not just a passive
report.

### 3.1. "My Portfolio" Dashboard

- **Pipeline View**: "You have 5 merchants in 'Draft' and 2 in 'Underwriting'."
- **Commission Tracker**: "Estimated Commission this month: $450."

### 3.2. Intervention Tools (The "Nudge")

Resellers often know the merchant personally.

- **Feature**: "Stalled Application Alert".
- **Action**: Reseller clicks **[Send Magic Link]**.
- **Result**: Reseller gets a pre-generated link to SMS to the merchant: _"Hey
  Bob, finish your app here so I can get you approved today: [link]"_.

### 3.3. Attribution & Campaign Management

- **referral_links**: Generate unique links for different campaigns (e.g.,
  "Facebook Ad", "Email Blast").
- **Analytics**: "Your 'Facebook Ad' link has a 5% conversion rate, but 'Email
  Blast' has 20%."

## 4. Reporting & Analytics (The "Funnel Health" Check)

### 4.1. Conversion Funnel

Visualizing the drop-off points.

- _Registered_: 100%
- _Started App_: 80%
- _Submitted_: 60% (**Drop-off: 20% at Docs Upload**) -> _Insight: Improve Doc
  Upload UX._
- _Approved_: 55%
- _Transacting_: 50%

### 4.2. Operational Metrics

- **Time-to-Decision**: "Average: 4 hours." (Goal: < 10 mins).
- **Auto-Approval Rate**: "Current: 45%." (Goal: > 70%).
- **Reseller Performance**: Leaderboard of top performing partners.

## 5. Automation Tools

### 5.1. Drip Campaigns (Email/SMS)

- **Trigger**: Merchant registers but doesn't submit within 24 hours.
- **Content**: "Did you get stuck? Here is a guide to the documents you need."

### 5.2. Task Assignment

- **Scenario**: Application flagged for "High Volume".
- **Action**: System auto-assigns "Review Task" to "Senior Underwriter" and sets
  due date +4 hours.

## 6. Advanced Pipeline Features (Enterprise Grade)

### 6.1. The "Deal Room" (Collaboration)

For larger merchants, approval isn't a solo sport.

- **Feature**: A shared workspace on the Application.
- **Interaction**: Sales tags Underwriting: _"@Sarah, this is a VIP client. Can
  we expedite?"_
- **Interaction**: Underwriting tags Legal: _"@Legal, please review the custom
  terms in the contract."_

### 6.2. SLA Management (The "Ticking Clock")

- **Feature**: Visual countdown timers on cards.
- **Rule**: "New Applications must be reviewed within 4 hours."
- **Escalation**: If timer < 30 mins, alert the Team Lead.
- **Benefit**: Ensures the "Speed as a Feature" promise is kept.

### 6.3. Predictive Lead Scoring

- **Feature**: AI analyzes the lead _before_ they finish the app.
- **Signal**: "They uploaded a high-res logo, used a corporate email, and
  clicked the 'Pricing' page 5 times."
- **Score**: "High Intent (90%)".
- **Action**: Move to "Priority Queue" for sales outreach.
