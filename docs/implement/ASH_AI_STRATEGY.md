# AshAi & AI Integration Strategy

## Overview

Strategy for leveraging AI capabilities within the MCP platform. The goal is to
make AI a **first-class citizen** across all portal experiences while
maintaining tenant isolation and data privacy.

## Current Implementation

### ✅ Built & Working

| Component | Description | Location |
|-----------|-------------|----------|
| **Mcp.Ai.Chat** | Simple AshAi prompt action | `lib/mcp/ai/chat.ex` |
| **Mcp.Ai.Document** | Vector storage with pgvector | `lib/mcp/ai/document.ex` |
| **Mcp.Ai.KnowledgeBase** | Multi-scope KB management | `lib/mcp/ai/resources/knowledge_base.ex` |
| **Mcp.Ai.EmbeddingService** | Ollama + OpenRouter embeddings | `lib/mcp/ai/embedding_service.ex` |
| **Mcp.Chat Domain** | Full conversation system | `lib/mcp/chat/` |
| **LangChain Integration** | Tool calling, streaming | `lib/mcp/chat/message/changes/respond.ex` |
| **Chat LiveView** | Real-time chat UI | `lib/mcp_web/live/chat_live.ex` |
| **Graph.TenantContext** | Apache AGE isolation | `lib/mcp/graph/tenant_context.ex` |
| **Platform.Graph** | Cypher query execution | `lib/mcp/platform/graph.ex` |
| **VectorStore** | pgvector operations | `lib/mcp/ai/vector_store.ex` |

### 🚧 Planned / Not Started

| Feature | Priority | Description |
|---------|----------|-------------|
| **Portal AI Integration** | HIGH | AI in Merchant/Store dashboards |
| **Command Palette (⌘K)** | HIGH | Universal AI search/actions |
| **NL → Ash Filters** | MEDIUM | "Show high-risk merchants" → query |
| **GraphRAG Fusion** | MEDIUM | Vector + Graph combined search |
| **Proactive Insights** | MEDIUM | AI-generated alerts and recommendations |
| **MCP Server** | LOW | Expose resources as MCP tools |

## AI-First Portal Vision

### Three Modes of AI Interaction

1. **Invisible Enhancement**
   - Smart search across all data
   - Auto-categorization of transactions
   - Anomaly detection in background
   - Semantic caching of common queries

2. **Assistant Copilot (⌘K)**
   - Natural language queries: "Show me failed transactions today"
   - Action execution: "Create an invoice for John Smith"
   - Context-aware help based on current screen
   - Tool calling for complex operations

3. **Proactive Intelligence**
   - Dashboard insights: "Revenue down 15% - top 3 reasons"
   - Risk alerts: "Customer X payment pattern changed"
   - Recommendations: "Consider offering discount to retain this customer"
   - Automated compliance checks

### Portal-Specific AI Features

| Portal | AI Features |
|--------|-------------|
| **Merchant** | Business insights, trend analysis, NL queries across stores |
| **Store** | Quick customer lookup, transaction assistance, shift summaries |
| **Platform** | Tenant analytics, risk scoring, compliance automation |

## Technical Strategy

### LLM Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  Application Layer                                               │
│  └── AshAi + LangChain orchestration                            │
├─────────────────────────────────────────────────────────────────┤
│  Inference Layer                                                 │
│  ├── Ollama (local, privacy-first)                              │
│  └── OpenRouter (fallback, embeddings)                          │
├─────────────────────────────────────────────────────────────────┤
│  Storage Layer                                                   │
│  ├── pgvector (embeddings, similarity search)                   │
│  └── Apache AGE (graph relationships)                           │
└─────────────────────────────────────────────────────────────────┘
```

### Models in Use

| Purpose | Model | Provider | Dimensions |
|---------|-------|----------|------------|
| Chat/Reasoning | llama3 | Ollama | - |
| Embeddings | text-embedding-3-small | OpenRouter | 1536 |
| (Planned) Local Embeddings | nomic-embed-text | Ollama | 768 |

### Tool Calling

Current tools in `Changes.Respond`:
- `AnalyzeDocument` - Document analysis
- `ConsultExpert` - Expert consultation routing

Planned tools:
- `SearchTransactions` - NL transaction queries
- `CreateInvoice` - Invoice generation
- `LookupCustomer` - Customer search
- `GetMerchantInsights` - Business analytics

## Implementation Roadmap

### Phase 1: Portal AI Foundation (Next)
- [ ] Add ⌘K command palette to Merchant/Store shells
- [ ] Create portal-specific AI context (merchant, store, user)
- [ ] Wire Chat domain to portal contexts
- [ ] Add "Ask AI" entry point in dashboards

### Phase 2: Intelligent Search
- [ ] Implement NL → Ash filter translation
- [ ] Add semantic search across transactions, customers, products
- [ ] Create search results ranking with AI explanations

### Phase 3: Proactive Features
- [ ] Dashboard insight generation (Oban jobs)
- [ ] Anomaly detection alerts
- [ ] AI-powered "Needs Attention" section

### Phase 4: GraphRAG
- [ ] Combine vector search with graph traversal
- [ ] Relationship-aware recommendations
- [ ] Cross-entity insights

## Privacy & Security

- **Local First**: Ollama for all chat/reasoning (no external API)
- **Tenant Isolation**: All AI queries scoped to tenant context
- **Audit Trail**: LlmUsage resource tracks all AI interactions
- **Policy Enforcement**: Ash policies apply to AI actions

## Related Docs

- [AI README](../features/ai/README.md)
- [RAG README](../features/rag/README.md)
- [Graph RAG Implementation](graph/graph-rag-implementation.md)
