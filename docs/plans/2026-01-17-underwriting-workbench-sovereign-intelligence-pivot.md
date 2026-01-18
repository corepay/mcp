# Underwriting Workbench: Sovereign Intelligence & Stack Pivot
**Date**: 2026-01-17
**Status**: Validated Design / Ready for Implementation

## Overview
This document captures the transition from the high-fidelity "Noir" Underwriting Dashboard prototype to a functional, real-world implementation within the MCP Elixir/Ash stack. It defines the strategic pivot toward a native, high-performance Intelligence Layer.

## 1. Vision & UI Standards
- **Noir Aesthetic**: The application will adopt the "Forensic Dark OLED" style defined in the `dashboard.html` mock.
- **Sovereign Workbench**: Refactor the Underwriting LiveView into a 3-column layout:
    - **Queue (Left)**: Real-time, score-sorted application stream.
    - **Canvas (Center)**: Forensic evidence container with tabbed sub-navigation (Healed Application, Evidence, KYB, Financials).
    - **Sovereign Brief (Right)**: Atlas Copilot (Signals), Risk Score (Progress Ring), and Decision Action Bar.
- **Healed Fields**: UI will display normalized/corrected data ("Healed") with visual attribution to AI agents where they differ from merchant input.

## 2. Forensic Stack Expansion (The Intelligence Layer)
We are moving away from heavy Python/Node.js dependencies to a native Rust/Elixir stack for maximum efficiency and "Sovereign Intelligence."

- **`@the_eye` (Kreuzberg - Rust/Elixir NIF)**:
    - **Role**: High-fidelity document parsing.
    - **Primary Tool**: `kreuzberg` Elixir package.
    - **Capability**: Handles 56+ formats (PDFs, Bank Statements, IDs) with native Rust performance and zero Python overhead.
    - **Tables**: Optimized for cell-level extraction of financial grids.
- **`@the_inspector` (Spider-rs - Rustler)**:
    - **Role**: Digital and physical forensics.
    - **Primary Tool**: `spider-rs` via Rustler.
    - **Capability**: High-speed, stealth web scraping and site snapshots (replacing Playwright).
    - **Features**: Social presence verification, domain intelligence, and Street View triangulation.
- **`@the_cortex` (Ollama - Local LLM)**:
    - **Role**: Fact extraction and triage.
    - **Primary Tool**: Mistral/Llama-3 (8B) via local Ollama sidecar.
    - **Capability**: Fast fact extraction from scraped web data (via Firecrawl-to-Markdown) before cascading to high-cost APIs.

## 3. Backend Orchestration (The Factory)
- **AnalyzeApplication Reactor**: Implementation of `Mcp.Underwriting.AnalyzeApplication` Reactor that orchestrates:
    - **Phase 1: Harvest**: Parallel calls to KYC Adapters, `@the_inspector`, and `@the_eye`.
    - **Phase 2: Triage**: Local LLM signal extraction and fact normalization.
    - **Phase 3: Decide**: Playbook-driven evaluation of the refined signals.
- **Async Execution**: Oban will trigger the Reactor on application submission to ensure zero-latency analysis for the underwriter.
- **Decision Lineage**: Every `RiskAssessment` will lock its `Playbook` version via SHA-256 hash to ensure immutable reasoning records.

## 4. Implementation Plan

#### Phase 1: The Forensic Core (`@the_inspector`)
*   **Infrastructure**: Initialize the Rustler bridge for `spider-rs`.
*   **Snapshots**: Implement the "Evidence Snapshot" worker for automated site auditing.

#### Phase 2: Extraction & Triage (`@the_eye` & Signal Extraction)
*   **Kreuzberg Integration**: Add the `kreuzberg` dependency and configure NIF paths.
*   **Firecrawl Sidecar**: Deploy self-hosted Firecrawl instance for web-to-markdown conversion.
*   **Ollama Triage**: Implement the "Facts Extractor" worker using the local LLM sidecar.

#### Phase 3: The Intelligence Factory (Reactor & Oban)
*   **Reactor Build**: Stitch the services together into a single Ash Reactor.
*   **DeviceProfiler**: Implement the frontend fingerprinting collector (Canvas, AudioContext, WebGL signals) and backend profile matching.

#### Phase 4: The Noir Workbench (LiveView)
*   **Workbench Refactor**: Implement the 3-column layout and "Healed" field components.
*   **Decision Bar**: Build the status transitions and Playbook execution UI.

## 5. Next Steps
1.  **Seed Playbook**: Populate `Mcp.Underwriting.Playbook` with demo profiles.
2.  **Scaffold Inspector**: Create the Rustler bridge for the forensics engine.
3.  **UI Workbench**: Implement the base 3-column layout in `WorkbenchLive`.
