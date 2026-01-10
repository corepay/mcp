# User Guide: Managing Agents

## Overview

The **Agent Management** section of the Admin Dashboard allows you to configure
your digital workforce.

## Managing Blueprints (Personas)

Blueprints represent the "Job Roles" in your system.

1. Navigate to **Admin > Agents > Blueprints**.
2. Click **Create New Blueprint**.
3. **Name**: Give the agent a role name (e.g., "Income Verifier").
4. **Base Prompt**: Describe who the agent is. _Tip: Be specific about their
   expertise._
   > "You are an expert income verification specialist with 20 years of
   > experience..."
5. **Tools**: Select any tools the agent needs (e.g., "Calculator", "OCR").
6. **Routing**: Choose "Cost Optimized" (Ollama) or "Quality Optimized" (Smart
   Routing).

## Managing Instructions (Policies)

Instructions represent the "Employee Handbook" for your agents.

1. Navigate to **Admin > Agents > Instructions**.
2. Select the **Blueprint** you want to instruct.
3. (Optional) Select a **Tenant** to apply this rule only to them.
4. **Instructions**: Write the specific rules.
   > "1. Check paystubs for the last 30 days. 2. Calculate monthly gross income.
   > 3. If income < $3000, mark as 'High Risk'."
5. Save the record.

## Best Practices

- **Keep Blueprints Generic**: "Underwriter", "Auditor", "Support Agent".
- **Use Specialty Agents**: Leverage the pre-built agents
  (`MortgageUnderwriter`, `AutoLoanUnderwriter`) for specific verticals instead
  of building from scratch.
- **Keep Instructions Specific**: Put the detailed business logic here.
- **Keep Instructions Specific**: Put the detailed business logic here.
- **Test Changes**: Always test new instructions on a staging tenant before
  rolling out to production.
