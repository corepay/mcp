# LLM Strategy & Smart Routing

## Overview

The MCP platform employs a **Hybrid AI Strategy** that combines the
cost-efficiency and privacy of local models (Ollama) with the advanced
capabilities of cloud-based models (OpenRouter). This approach ensures optimal
performance, cost management, and reliability for all AI-driven underwriting
tasks.

## Key Capabilities

- **Hybrid Intelligence**: Seamlessly switches between local Llama 3 models and
  cloud-based GPT-4/Claude 3 models.
- **Smart Routing**: Automatically routes requests based on agent confidence
  scores and error rates.
- **Cost Optimization**: Prioritizes free local inference for routine tasks,
  using paid cloud inference only when necessary.
- **Usage Tracking**: Comprehensive tracking of token consumption, costs, and
  latency for every execution.

## Quick Start

1. **Configure Providers**: Ensure `OLLAMA_BASE_URL` and `OPENROUTER_API_KEY`
   are set in your environment.
2. **Define Blueprints**: Create `AgentBlueprint` resources with
   `routing_config` to specify primary and fallback providers.
3. **Run Agents**: The `Orchestrator` and `AgentRunner` handle the rest,
   automatically managing fallbacks and tracking usage.

## Benefits

- **Reduced Costs**: drastically lower API bills by offloading 80%+ of traffic
  to local models.
- **High Reliability**: Automatic fallback ensures tasks complete even if one
  provider fails or struggles.
- **Data Privacy**: Sensitive initial processing happens locally within your
  infrastructure.
