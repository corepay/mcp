# Stakeholder Guide: LLM Strategy

## Business Value

The Hybrid AI Strategy delivers significant business value by balancing cost,
performance, and reliability.

### 1. Cost Efficiency

By utilizing local models (Ollama) for routine tasks, we eliminate per-token API
costs for the vast majority of traffic. Cloud models (OpenRouter) are reserved
for complex edge cases, resulting in **estimated savings of 60-80%** compared to
a cloud-only approach.

### 2. Operational Reliability

Dependencies on external APIs introduce risks of downtime and latency spikes.
Our fallback mechanism ensures that even if the primary local model struggles,
the system automatically recovers using a secondary provider, ensuring
**business continuity** for critical underwriting workflows.

### 3. Scalable Intelligence

As open-source models improve, our local capabilities grow without increasing
costs. Simultaneously, we maintain access to the absolute best-in-class
proprietary models via OpenRouter for tasks requiring maximum reasoning
capability.

## Risk Mitigation

| Risk                    | Mitigation                                                                                               |
| :---------------------- | :------------------------------------------------------------------------------------------------------- |
| **Model Hallucination** | Confidence scoring and automatic fallback to more capable models reduces error rates.                    |
| **API Outages**         | Dual-provider strategy ensures no single point of failure for AI inference.                              |
| **Cost Spikes**         | Usage tracking provides real-time visibility into spend, allowing for rapid adjustment of routing rules. |

## Strategic Impact

This architecture positions the platform to be **vendor-agnostic**. We are not
locked into OpenAI, Anthropic, or any single provider. We can swap models and
providers at will to chase the best performance/price ratio.
