# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

An AI-powered MSP (Managed Service Provider) platform built with:
- **Phoenix/Elixir** - Web framework and backend
- **Ash Framework** - Resource-based backend architecture
- **DaisyUI + Tailwind CSS v4** - Frontend component library
- **PostgreSQL** - With TimescaleDB, PostGIS, pgvector, and Apache AGE extensions
- **AI Stack** - **Ollama** (LLM inference), **Open WebUI** (Chat interface), **AshAi** (Orchestration)
- **Redis** - Caching and session storage
- **MinIO** - S3-compatible object storage
- **Meilisearch** - Full-text search engine

## Agent Reading Requirements
**MANDATORY READING BEFORE ANY CODING TASKS:**
- **CLAUDE.md**: This file - Primary project guidelines and architecture
- **AGENTS.md**: Phoenix/LiveView/Elixir/Ash Framework specific patterns
- **.rules**: Critical usage rules for specific packages (e.g., ash_typescript)
- **docs/DESIGN_GUIDE.md**: UI Component architecture, Design Tokens, and Folder Structure standards
- **docs/guides/README.md**: Index of all available developer guides

## Common Development Commands

### Setup and Dependencies
```bash
mix setup              # Initial setup (deps, db, assets)
mix deps.get           # Get dependencies
mix ecto.setup         # Create, migrate, seed database
mix ecto.reset         # Drop, recreate, migrate, seed
```

### Development Server
```bash
mix phx.server         # Start Phoenix server
iex -S mix phx.server  # Start with IEx console
```

### Infrastructure (Docker)
```bash
docker-compose up -d   # Start Postgres, Redis, MinIO, Meilisearch, Ollama, Open WebUI
docker-compose down    # Stop all services
```

### Testing & Quality
```bash
mix test               # Run all tests
mix test --failed      # Run only failed tests
mix precommit          # Run full pre-commit check (compile, format, credo, test)
mix quality            # Run quality checks (credo, dialyzer)
mix format             # Format code
```

### Asset Pipeline
```bash
mix assets.setup       # Install Tailwind and esbuild
mix assets.build       # Build assets for dev
mix assets.deploy      # Build/minify for prod
```

## Architecture

### Domain Structure (`lib/mcp/`)
- **`core/`**: Core domain logic, Repo, Telemetry
- **`accounts/`**: User management, Authentication (AshAuthentication)
- **`platform/`**: Multi-tenancy (Tenants, Merchants, Stores)
- **`ai/`**: AI orchestration and logic
- **`secrets/`**: Encryption and credential management (Cloak/Vaultex)

### Database Architecture
**Repo**: `Mcp.Repo`
- **Multi-tenancy**: Schema-based isolation (`acq_{uuid}`)
- **Extensions**: TimescaleDB (metrics), PostGIS (geo), pgvector (embeddings)

### Frontend Architecture (`lib/mcp_web/`)
- **Stack**: Phoenix LiveView, Tailwind CSS v4, DaisyUI
- **Design Guide**: See `docs/DESIGN_GUIDE.md` for strict component rules.
- **Theme**: Dynamic theming via `ThemePlug` and CSS variables.

### AI Integration
- **Ollama**: Local LLM inference (Port: `${OLLAMA_PORT}`)
- **Open WebUI**: User interface for chat (Port: `${OPEN_WEBUI_PORT}`)
- **AshAi**: Elixir library for integrating LLMs with Ash resources

## Project Guidelines

### Quality Standards
- **100% Test Pass Rate**: No exceptions.
- **Pre-commit**: Always run `mix precommit` before finishing a task.
- **No Raw HTML**: Use `CoreComponents` (DaisyUI wrappers) for all UI.

### Configuration & Ports
- **NO HARDCODED PORTS**: Always use `System.get_env/2` with a fallback.
- **Source of Truth**: The `.env` file is the authority for port assignments. **DO NOT WRITE TO .ENV - READ ONLY.**
- **Verification**: Check `.env` before adding new services to ensure no conflicts.
- **Dynamic Ports**:
    - Postgres: `${POSTGRES_PORT}`
    - Redis: `${REDIS_PORT}`
    - MinIO: `${MINIO_PORT}`
    - Meilisearch: `${MEILISEARCH_PORT}`
    - Ollama: `${OLLAMA_PORT}`
    - Open WebUI: `${OPEN_WEBUI_PORT}`

### Documentation
- Update existing docs (`docs/`) rather than creating new root-level files.
- Keep `task.md` updated with progress.

### Context Awareness
- If context is low, ask the user to use compact mode or create a handoff document.
