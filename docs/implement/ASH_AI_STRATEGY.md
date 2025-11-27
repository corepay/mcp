# AshAi & AshMCP Strategy

## Overview

This document outlines the strategy for leveraging `AshAi` and `AshMCP` within
the Core Foundation. The goal is to enhance the platform with intelligent
capabilities while maintaining strict architectural boundaries and data privacy.

## AshAi Opportunities

### 1. Intelligent Search & Filtering

- **Concept**: Use `AshAi` to interpret natural language queries and convert
  them into Ash filters.
- **Implementation**: Use `AshAi.Filter` (if available) or prompt-backed actions
  to generate filter structs.
- **Use Case**: "Show me all high-risk merchants from last week" ->
  `Ash.Query.filter(Merchant, risk_level == :high and inserted_at > ago(7, :day))`

### 2. Automated Compliance Audits

- **Concept**: Analyze audit logs and merchant data for compliance violations
  using LLMs.
- **Implementation**: A background job (Oban) that feeds batched data to an
  `AshAi` action for analysis.
- **Use Case**: "Review this merchant's transaction history for potential money
  laundering patterns."

### 3. Smart Data Generation

- **Concept**: Generate realistic seed data for testing and development.
- **Implementation**: Use `AshAi` to generate valid, context-aware data for
  complex resources.

## AshMCP Server Opportunities

### 1. Context-Aware Coding Assistant

- **Concept**: Expose the codebase structure and documentation via an MCP server
  to local LLMs.
- **Implementation**: Use `AshMCP` to expose resources as MCP tools.
- **Benefit**: Allows the coding assistant (like the one you are using) to "see"
  the domain logic more clearly.

### 2. Operational Dashboard

- **Concept**: Create an MCP server that allows authorized LLMs to perform
  operational tasks.
- **Implementation**: Expose specific actions (e.g., `Merchant.approve`,
  `Refund.process`) as MCP tools.
- **Security**: Strictly controlled via Ash policies and authentication.

## Local LLM Strategy (Ollama)

- **Stack**: Ollama + Open WebUI (Dockerized).
- **Integration**: `AshAi` configured to use OpenAI adapter pointing to local
  Ollama instance.
- **Model**: `llama3` or `mistral` for general tasks; specialized models for
  code analysis.
- **Privacy**: All data remains local; no external API calls.

## Roadmap

1. **Phase 1 (Current)**: Basic `AshAi` integration and `Chat` resource.
2. **Phase 2**: Implement "Intelligent Search" for Merchants.
3. **Phase 3**: Prototype `AshMCP` server for operational tasks.
