# Retrieval-Augmented Generation (RAG)

## Overview

Retrieval-Augmented Generation (RAG) is a technique that enhances the accuracy
and reliability of Generative AI models with facts fetched from external
sources. In the MCP Platform, RAG allows agents to access domain-specific
knowledge (e.g., underwriting guidelines, policy manuals) that is not part of
the LLM's training data.

## Key Capabilities

- **Knowledge Bases**: Organize documents into logical collections (e.g.,
  "Mortgage Policies", "Compliance Rules").
- **Granular Scoping**: Limit knowledge access to specific Tenants, Merchants,
  or Resellers.
- **Vector Search**: Use semantic search to find the most relevant document
  chunks based on meaning, not just keywords.
- **Graph Database (Apache AGE)**: Leverage structured relationship data (e.g.,
  Merchant connections, transaction flows) for "GraphRAG" capabilities.
- **Automatic Context Injection**: The `AgentRunner` automatically retrieves
  relevant information and injects it into the agent's prompt.

## Quick Start

### 1. Create a Knowledge Base

```elixir
kb = Mcp.Ai.KnowledgeBase.create!(%{
  name: "Underwriting Guidelines",
  description: "Standard operating procedures for risk assessment",
  tenant_id: tenant_id
})
```

### 2. Add Documents

```elixir
Mcp.Ai.Document.create!(%{
  content: "The maximum debt-to-income ratio for FHA loans is 43%.",
  knowledge_base_id: kb.id,
  tenant_id: tenant_id
})
```

### 3. Configure an Agent

Update your `AgentBlueprint` to include the Knowledge Base ID:

```elixir
Mcp.Underwriting.AgentBlueprint.update!(blueprint, %{
  knowledge_base_ids: [kb.id]
})
```

## Related Resources

- **[Developer Guide](developer-guide.md)**: Technical implementation details.
- **[API Reference](api-reference.md)**: Resource definitions for KnowledgeBase
  and Document.
- **[Agents](../agents/README.md)**: How to use RAG with Agents.
