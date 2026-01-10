# API Reference: Specialty Agents

## Resources

### Mcp.Underwriting.AgentBlueprint

Defines the identity and capabilities of an AI agent.

| Attribute        | Type        | Description                               |
| :--------------- | :---------- | :---------------------------------------- |
| `id`             | UUID        | Unique identifier                         |
| `name`           | String      | Human-readable name (e.g., "Underwriter") |
| `description`    | String      | Optional description of the agent's role  |
| `base_prompt`    | String      | The core system prompt (Persona)          |
| `tools`          | Array<Atom> | List of enabled tools                     |
| `routing_config` | Map         | Smart routing configuration               |

### Mcp.Underwriting.InstructionSet

Defines the specific rules and policies for an agent to follow.

| Attribute      | Type   | Description                             |
| :------------- | :----- | :-------------------------------------- |
| `id`           | UUID   | Unique identifier                       |
| `blueprint_id` | UUID   | Association to the parent Blueprint     |
| `tenant_id`    | UUID   | Optional association to a Tenant        |
| `instructions` | String | The specific task instructions (Policy) |

## JSON API Endpoints

These resources are exposed via the standard JSON API for management by the
Admin UI.

- `GET /api/agent_blueprints`
- `POST /api/agent_blueprints`
- `GET /api/instruction_sets`
- `POST /api/instruction_sets`

_Note: Access to these endpoints requires Admin privileges._
