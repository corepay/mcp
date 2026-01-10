# User Guide: Configuring AI Agents

## Overview

As a platform administrator or developer, you can configure how each AI Agent
behaves, specifically choosing which AI models it uses and how it handles
difficult tasks.

## Configuring Routing

You can adjust the `routing_config` for any Agent Blueprint to optimize for cost
or quality.

### Scenario A: Routine Tasks (Cost Optimized)

For simple tasks like data extraction or basic classification, use the default
local model.

- **Mode**: `Single`
- **Primary**: `Ollama` (Llama 3)
- **Fallback**: None

### Scenario B: Critical Decisions (Quality Optimized)

For final underwriting decisions where accuracy is paramount, use the Smart
Routing fallback.

- **Mode**: `Fallback`
- **Primary**: `Ollama`
- **Fallback**: `OpenRouter`
- **Min Confidence**: `0.9` (High threshold)

_This configuration attempts to use the free model first. If the model is less
than 90% confident, it automatically calls the premium model to ensure
accuracy._

## Monitoring Usage

You can view usage statistics in the **Admin Dashboard** under **AI Analytics**.

- **Total Cost**: Estimated spend for the selected period.
- **Token Usage**: Volume of text processed.
- **Fallback Rate**: Percentage of requests that required the premium model
  (useful for tuning your confidence thresholds).
