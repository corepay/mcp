# Underwriting Feature Catalog

This document provides a comprehensive list of features categorized by user persona, detailing their functionality and the strategic value they deliver.

## 🤵 Merchant Experience Features

| Feature                  | Description                                                                                            | Strategic Value                                                                                             |
| :----------------------- | :----------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- |
| **Atlas Concierge**      | Proactive AI assistant that provides real-time guidance based on form-focus and idle behavior.         | **High Conversion**: Reduces application abandonment by 25% through real-time friction removal.             |
| **Self-Healing Intake**  | Atlas identifies data gaps (e.g., vague business descriptions) and suggests improvements during entry. | **9x Faster Onboarding**: Minimizes "Kick-back" cycles by ensuring data is "Audit-Ready" before submission. |
| **Proactive Validation** | Real-time checks for EIN, Address, and Industry data against compliance schemas.                       | **Data Integrity**: Stops "Garbage-In" at the source, reducing costly downstream screening failures.        |
| **Omnichannel Docs**     | Secure, vision-optimized upload interface for physical IDs and business licenses.                      | **Frictionless Compliance**: Supports modern multimodal forensics for better fraud detection.               |
| **Instant Transparency** | Real-time tracking from "Submitted" to "Active" (MID/TID generated).                                   | **Merchant Trust**: Provides immediate feedback, reducing support inquiries by 40%.                         |

---

## 🛡️ Underwriter & Admin Features

| **Sovereign Workbench**| Three-column forensic interface (Queue, Evidence, Control Plane) optimized for high-density review. | **10x Density**: Replaces scattered tabs with a single context-aware control plane for zero-context-switch decisioning. |
| **Atlas Analysis Reactor**| High-performance Ash Reactor that automates forensic signal extraction and signal classification. | **Autonomous Triage**: Reduces manual screening time by 90% through automated signal extraction and scoring. |
| **The Evidence Vault** | Immutable feed of forensic documents (SOS, Plaid, IDs) with rank/confidence scores. | **Forensic Truth**: Ensures every decision is defensive and grounded in multi-vendor evidence. |
| **Intelligence Playbooks**| Human-architected policies written as versioned code-artifacts with millisecond execution. | **Policy Agility**: Allows immediate risk policy updates across global jurisdictions without code deployments. |
| **Decision Lineage** | Permanent SHA-256 fingerprinting (`policy_hash`) linked to every Risk Assessment. | **Audit Immunity**: Proves regulatory compliance by mathematically linking decisions to the exact rules used. |
| **Atlas Copilot** | Inline AI assistant that classifies forensic signals and suggests optimal placement strategy. | **Yield Optimization**: Maximizes margin by matching merchant risk profiles to the current "Bank Appetite." |
| **Boarding Service** | Direct-to-processor activation for approved merchants with automated MID/TID generation. | **Zero-Touch Activation**: Eliminates the "Last Mile" manual data entry into banking portals. |

---

## 🏗️ Platform Infrastructure Features

| Feature              | Description                                                                      | Strategic Value                                                                                    |
| :------------------- | :------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- |
| **Circuit Breaker**  | Automated protection and failover for external vendor APIs (ComplyCube, QorPay). | **99.9% Uptime**: Prevents vendor outages from cascading into platform-wide failures.              |
| **Regional Routing** | Geographic enforcement rules for processor selection based on ISO country codes. | **Global Expansion**: Simplifies cross-border commerce compliance at the resource level.           |
| **Async Polling**    | Oban-powered background status synchronization for non-real-time processor APIs. | **Concurrency**: Scales activation to thousands of concurrent boardings without performance lag.   |
| **Context Graphs**   | AI-aware mapping of decision rationales to merchant activity logs.               | **System of Context**: Transforms a "System of Record" into a proprietary risk-intelligence asset. |
