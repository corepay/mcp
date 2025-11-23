# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An AI-powered MSP (Managed Service Provider) platform built with:
- **Phoenix/Elixir** - Web framework and backend
- **Ash Framework** - Resource-based backend architecture with declarative domain modeling
- **DaisyUI + Tailwind CSS** - Frontend component library
- **BMAD (Build, Manage, Automate, Deploy)** - Workflow orchestration system
- **PostgreSQL** with advanced extensions (TimescaleDB, PostGIS, pgvector, Apache AGE)
- **Redis** - Caching layer
- **MinIO** - S3-compatible object storage
- **Vault** - Secrets management

The unique aspect of this project is the unified pattern language across all three layers (BMAD, Ash, DaisyUI) enabling automatic cross-stack validation and code generation.

## Common Development Commands

### Setup and Dependencies
```bash
# Initial setup (dependencies, database, assets)
mix setup

# Install dependencies only
mix deps.get

# Database setup
mix ecto.setup           # Create, migrate, seed
mix ecto.reset           # Drop, recreate, migrate, seed
mix ecto.create          # Create database
mix ecto.migrate         # Run migrations
mix ecto.rollback        # Rollback last migration
```

### Development Server
```bash
# Start Phoenix server
mix phx.server

# Start with IEx console
iex -S mix phx.server

# Start infrastructure (Postgres, Redis, MinIO, Vault)
docker-compose up -d
docker-compose down
```

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test_file.exs

# Run specific test by line number
mix test test/path/to/test_file.exs:42

# Run previously failed tests only
mix test --failed

# Run tests with coverage
mix test --cover
```

### Code Quality
```bash
# Pre-commit checks (compile, credo, format check, unused deps, test)
mix precommit

# Quality checks (compile, credo, dialyzer)
mix quality

# Full check suite (compile, credo, dialyzer, test)
mix check

# Format code
mix format

# Check formatting without changes
mix format --check-formatted

# Run Credo linter
mix credo
mix credo --strict

# Run Dialyzer type checker (first run is slow)
mix dialyzer
```

### Asset Pipeline
```bash
# Setup assets (install Tailwind and esbuild)
mix assets.setup

# Build assets for development
mix assets.build

# Build and minify assets for production
mix assets.deploy
```

### BMAD Integration Tools
```bash
# Validate cross-stack consistency (Ash ↔ DaisyUI ↔ BMAD)
python3 lib/bmad_integration/validators/cross_stack_validator.py

# Generate full-stack resources
python3 lib/bmad_integration/tools/full_stack_tools.py

# Real-time validation monitoring
python3 lib/bmad_integration/core/live-validation/realtime_validator.py
```

## Architecture

### Domain Structure
The application follows Phoenix conventions with domain-driven modules in `lib/mcp/`:

- **`core/`** - Core domain logic, Ecto repo, telemetry
- **`cache/`** - Redis-based caching (supervisor, cache manager, session store)
- **`secrets/`** - Vault integration (credential manager, encryption service)
- **`storage/`** - S3/MinIO object storage client
- **`communication/`** - Messaging and notifications

Web layer is in `lib/mcp_web/` following standard Phoenix structure.


### Database Architecture
**Repo**: `Mcp.Core.Repo` with advanced PostgreSQL features:
- **Multi-tenancy**: Schema-based isolation with `with_tenant_schema/2`
- **TimescaleDB**: Time-series data with hypertables via `create_hypertable/3`
- **PostGIS**: Geospatial queries
- **pgvector**: Vector similarity search for AI/ML
- **Apache AGE**: Graph database capabilities

Search path organization: `acq_{tenant} → public → platform → shared → ag_catalog`

### BMAD Integration Pattern
Unified syntax across all layers enables automatic validation:

```
ash://resource.action:modifier       # Backend (Ash)
daisyui://component-part:modifier    # Frontend (DaisyUI)
bmad://workflow.step:modifier        # Process (BMAD)
```

**Example mapping**:
- Ash: `UserResource` → DaisyUI: `user-card` → BMAD: `user_lifecycle`

Configuration in `lib/bmad_integration/adapters/config.yaml` defines cross-stack mappings.

### Configuration
- **Development**: `config/dev.exs` - Phoenix server on port 4000
- **Runtime**: `config/runtime.exs` - Environment-based configuration
- **Test**: `config/test.exs` - Test environment with SQL sandbox
- **Database**: Environment variables loaded at runtime via `Mcp.Core.Repo.init/2`

Environment variables (see `.env` file):
- `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- `REDIS_PORT`, `MINIO_PORT`, `VAULT_PORT`
- `VAULT_DEV_ROOT_TOKEN_ID`

### Frontend Architecture
- **Tailwind CSS v4** with new import syntax (no `tailwind.config.js`)
- **DaisyUI components** for UI patterns
- **Phoenix LiveView** for real-time interactions
- **Component-Driven Architecture**: Reusable components in `lib/mcp_web/components/`
- **esbuild** for JS bundling (ES2022 target)

Asset source paths configured in `config/config.exs`:
```elixir
@source "../css"
@source "../js"
@source "../../lib/mcp_web"
```

#### Component-Driven UI Development
**PREFERRED APPROACH**: Always create reusable components rather than dashboard-style LiveViews.

- **Components Directory**: `lib/mcp_web/components/` - Contains all reusable UI components
- **Core Components**: `McpWeb.CoreComponents` - Base components (buttons, forms, flash, icons)
- **Domain Components**: Domain-specific components (e.g., `McpWeb.GdprComponents`)
- **LiveView Composition**: Use components to build interfaces, not monolithic dashboard views

**Component Creation Guidelines**:
1. Create domain-specific component modules for complex features
2. Use Phoenix.Component with proper attrs and slots
3. Import/reuse CoreComponents functions (icon, flash, etc.)
4. Keep components focused and composable
5. Use proper assigns documentation with @doc and @attr

## Project-Specific Guidelines

### Quality Standards
- **100% test pass rate required** - No exceptions. Never propose moving forward with failing tests.
- Always run `mix precommit` before claiming work is complete.
- Use `mix test --failed` to quickly iterate on failing tests.

### Code Organization
- Keep root directory clean - features go in domain subdirectories under `lib/mcp/`
- Follow Phoenix conventions for web layer in `lib/mcp_web/`
- BMAD integration code lives in `lib/bmad_integration/`

### Documentation
- Minimize documentation files - prefer self-documenting code and terminal output
- Update existing docs rather than creating new ones
- Don't create README files proactively

### HTTP Requests
Use `:req` (Req) library for all HTTP requests - already included as dependency. Avoid `:httpoison`, `:tesla`, `:httpc`.

### Cross-Stack Validation
When working across Ash resources and DaisyUI components:
1. Check pattern mappings in `lib/bmad_integration/adapters/config.yaml`
2. Run cross-stack validator to ensure consistency
3. Verify theme synchronization between layers

### Context Awareness
Always warn when context is running low before starting new tasks. If insufficient context remains, ask user to:
- Use compact mode, or
- Create agent handoff document for remaining tasks

### Agent Reading Requirements
**MANDATORY READING BEFORE ANY CODING TASKS:**
- **CLAUDE.md**: This file - Primary project guidelines and architecture
- **AGENTS.md**: Phoenix/LiveView/Elixir/Ash Framework specific patterns and technology stack requirements

All agents MUST read both files before starting any development work to ensure compliance with project architecture and prevent conflicting implementations.
