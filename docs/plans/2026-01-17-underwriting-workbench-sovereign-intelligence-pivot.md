# Underwriting Workbench: Sovereign Intelligence & Stack Pivot
**Date**: 2026-01-17
**Status**: Validated Design / Ready for Implementation

## Overview
This document captures the transition from the high-fidelity "Noir" Underwriting Dashboard prototype to a functional, real-world implementation within the MCP Elixir/Ash stack. It defines the strategic pivot toward a multi-service "Intelligence Layer" and the "Sovereign Workbench" UI architecture.

## 1. Vision & UI Standards
- **Noir Aesthetic**: The application will adopt the "Forensic Dark OLED" style defined in the `dashboard.html` mock.
- **Sovereign Workbench**: Refactor the Underwriting LiveView into a 3-column layout:
    - **Queue (Left)**: Real-time, score-sorted application stream.
    - **Canvas (Center)**: Forensic evidence container with tabbed sub-navigation (Healed Application, Evidence, KYB, Financials).
    - **Sovereign Brief (Right)**: Atlas Copilot (Signals), Risk Score (Progress Ring), and Decision Action Bar.
- **Healed Fields**: UI will display normalized/corrected data ("Healed") with visual attribution to AI agents where they differ from merchant input.

## 2. Backend Orchestration (The Factory)
- **Reactor Engine**: Implementation of `Mcp.Underwriting.AnalyzeApplication` Reactor.
    - **Phase 1: Harvest**: Concurrent calls to KYC/KYB adapters and forensic sidecars.
    - **Phase 2: Search**: Graph RAG lookup against the underwriter precedent graph.
    - **Phase 3: Decide**: AI Agent evaluation based on active Playbook guidelines.
- **Async Execution**: Oban will trigger the Reactor on application submission to ensure zero-latency analysis for the underwriter.
- **Decision Lineage**: Every `RiskAssessment` will lock its `Playbook` version via SHA-256 hash to ensure immutable reasoning records.

## 3. Stack Expansion (@apps)
We are expanding the sidecar architecture to separate document intelligence from web forensics.
- **`the_eye` (Existing - Python/Docling)**: Focused on high-fidelity document parsing (Bank Statements, Merchant IDs, Tax Docs).
- **`the_inspector` (New - Node.js/Playwright)**: Focused on digital and physical forensics:
    - Automated website snapshots and "stealth" web scraping.
    - Street view / Map discrepancy detection.
    - Domain age and security footprint verification.

## 4. Data Model Strategy
- **`RiskAssessment`**: Primary context record for an analysis run.
- **`RiskSignal`**: Granular "Signal Chips" (e.g., `:forensic_mismatch`, `:identity_verified`).
- **`RiskFactor`**: Metadata for specific signals (Score impact, Observation text).

## 5. Next Steps
1.  **Seed Intelligence**: Populate `Mcp.Underwriting.Playbook` with demo profiles (SAAS_LITE_V4, etc.).
2.  **Service Scaffold**: Create the `@the_inspector` workspace and base API.
3.  **UI Refactor**: Implement the 3-column Workbench layout in `McpWeb.Tenant.Underwriting.WorkbenchLive`.
