# Feature Inventory: Online Application (OLA) Portal

This document lists the specific features required to implement the OLA Portal.

## 1. Authentication & Session Management

| ID       | Feature               | Description                                                            | Priority |
| :------- | :-------------------- | :--------------------------------------------------------------------- | :------- |
| **A-01** | **Registration Flow** | Sign-up form (Email, Password, Phone) with immediate session creation. | P0       |
| **A-02** | **Magic Link Resume** | "Save & Resume" functionality via email magic links.                   | P1       |
| **A-03** | **OAuth Support**     | Google/Microsoft sign-in for faster onboarding.                        | P2       |
| **A-04** | **Session Timeout**   | Secure timeout with auto-save before logout.                           | P1       |

## 2. The "Atlas" Conversational Interface

| ID       | Feature                | Description                                                                            | Priority |
| :------- | :--------------------- | :------------------------------------------------------------------------------------- | :------- |
| **C-01** | **Chat UI**            | Persistent chat sidebar/overlay capable of rendering text, rich cards, and actions.    | P0       |
| **C-02** | **Intent Recognition** | AI detects user intent (e.g., "Help me find my EIN") and routes to appropriate logic.  | P0       |
| **C-03** | **Auto-Fill Actions**  | AI triggers form updates based on chat input (e.g., user types address -> form fills). | P0       |
| **C-04** | **Document Analysis**  | Real-time OCR and validation of uploaded documents (e.g., blur detection).             | P1       |
| **C-05** | **Magic Camera**       | QR code generation and mobile web view for capturing photos that sync to desktop.      | P1       |
| **C-06** | **Contextual FAQ**     | AI answers field-specific questions using the Underwriting Knowledge Base.             | P1       |

## 3. Application Form & Data Entry

| ID       | Feature              | Description                                                             | Priority |
| :------- | :------------------- | :---------------------------------------------------------------------- | :------- |
| **F-01** | **Business Profile** | Fields for Legal Name, DBA, Address, Tax ID, Entity Type, MCC.          | P0       |
| **F-02** | **Ownership**        | Multi-entry section for Beneficial Owners (>25%) with ID upload.        | P0       |
| **F-03** | **Financials**       | Volume, Ticket Size, Delivery Timeframe inputs.                         | P0       |
| **F-04** | **Banking**          | Plaid Link integration or manual Account/Routing entry with validation. | P0       |
| **F-05** | **Smart Validation** | Real-time checks (USPS Address, EIN format, Routing Number checksum).   | P0       |
| **F-06** | **E-Signature**      | Digital signature capture for Terms & Conditions.                       | P0       |

## 4. The Applicant Dashboard

| ID       | Feature                 | Description                                                                 | Priority |
| :------- | :---------------------- | :-------------------------------------------------------------------------- | :------- |
| **D-01** | **Status Tracker**      | Visual progress bar showing application stage (Received, Review, Decision). | P0       |
| **D-02** | **Document Vault**      | List of uploaded documents with status (Pending, Accepted, Rejected).       | P1       |
| **D-03** | **Action Items**        | Prominent alerts for required user actions (e.g., "Upload Voided Check").   | P0       |
| **D-04** | **Human Chat**          | Option to escalate chat to a human underwriter (Tenant view).               | P2       |
| **D-05** | **Notification Center** | History of alerts and status updates.                                       | P2       |

## 5. Backend & Integrations

| ID       | Feature                  | Description                                                                | Priority |
| :------- | :----------------------- | :------------------------------------------------------------------------- | :------- |
| **B-01** | **Application Resource** | Ash resource `Mcp.Underwriting.Application` with JSONB `application_data`. | P0       |
| **B-02** | **Vendor Mapping**       | Mapper to convert internal schema to ComplyCube/Vendor API payloads.       | P0       |
| **B-03** | **Risk Engine**          | Logic to calculate internal `risk_score` based on inputs and vendor data.  | P1       |
| **B-04** | **Webhook Handler**      | Receiver for vendor status updates (e.g., KYC passed/failed).              | P1       |
| **B-05** | **Funnel Analytics**     | Tracking events for step completion and abandonment.                       | P2       |

## 6. UI/UX Requirements (For Specialty Agent)

| ID       | Feature                | Description                                                              | Priority |
| :------- | :--------------------- | :----------------------------------------------------------------------- | :------- |
| **U-01** | **Responsive Design**  | Mobile-first approach, critical for the "Magic Camera" flow.             | P0       |
| **U-02** | **Accessibility**      | WCAG 2.1 AA compliance (keyboard nav, screen readers).                   | P1       |
| **U-03** | **Micro-Interactions** | Subtle animations for success states (e.g., checkmarks, progress fills). | P2       |
| **U-04** | **Theme Support**      | Dark/Light mode support (using Tailwind v4).                             | P1       |
