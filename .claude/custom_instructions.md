# Custom Instructions for Claude Code Agents

## Project Overview
This is a Phoenix/Elixir MCP (Model Context Protocol) server project with revolutionary BMAD + Ash + DaisyUI full-stack integration.

## Developer Experience (DX) Guidelines

### 1. Code Organization
- **All implementation code** goes in `lib/` following Phoenix conventions
- **Integration code** organized in `lib/bmad_integration/` with subdirectories:
  - `adapters/` - Pattern adapters (BMAD ↔ Ash ↔ DaisyUI)
  - `tools/` - MCP server extensions and generation tools
  - `core/` - Live development environment and workflows
  - `validators/` - Cross-stack consistency validators

### 2. Documentation Hygiene
- **UPDATE existing docs** before creating new ones
- **Primary documentation**: Update `README.md` for user-facing changes
- **Technical docs**: Update `docs/` directory for implementation details
- **Never create duplicate documentation** - consolidate and improve existing

### 3. Root Directory Cleanliness
- **Keep root minimal** - only essential project files
- **No feature-specific folders** at root level
- **Use proper Phoenix structure**: lib/, config/, test/, priv/
- **Clean up immediately** after any experiments or testing

### 4. BMAD-Ash-DaisyUI Integration
- **Pattern Language**: `ash://resource.action:modifier` ↔ `daisyui://component-part:modifier` ↔ `bmad://workflow.step:modifier`
- **Cross-Stack Validation**: Always validate consistency across all three layers
- **Theme Synchronization**: Ash colors ↔ DaisyUI themes must stay in sync
- **Zero Boilerplate**: Generate matching components automatically

### 5. MCP Server Integration
- **Primary MCP tools**: Located in `lib/bmad_integration/tools/`
- **Full-Stack Generation**: Tools generate Ash resources + DaisyUI components + BMAD workflows
- **Real-time Validation**: Live validation system monitors all layers
- **Quality Gates**: All layers must pass consistency checks

### 6. Development Workflow
1. **Make changes** in appropriate `lib/` subdirectory
2. **Run cross-stack validation**: `python3 lib/bmad_integration/validators/cross_stack_validator.py`
3. **Test MCP tools**: `python3 lib/bmad_integration/tools/full_stack_tools.py`
4. **Update documentation**: Modify existing files, don't create new ones
5. **Clean up**: Remove any temporary files or test artifacts

### 7. Phoenix/Elixir Specific
- **Mix tasks**: Add to `lib/mix/` for custom commands
- **Configuration**: Use `config/` directory following Phoenix conventions
- **Testing**: Place tests in `test/` with proper structure
- **Dependencies**: Add to `mix.exs` following Elixir conventions

### 8. Quality Standards
- **100% test coverage** for all integration code
- **Cross-stack consistency** must always pass validation
- **Documentation** must stay in sync with implementation
- **No unused imports** or dead code

### 9. File Naming Conventions
- **Elixir files**: snake_case (e.g., `resource_generator.ex`)
- **Python files**: snake_case (e.g., `cross_stack_validator.py`)
- **Config files**: kebab-case or snake_case depending on format
- **Documentation**: Use existing files, maintain consistent style

### 10. Error Handling
- **Graceful degradation** when components are missing
- **Clear error messages** for validation failures
- **Recovery procedures** documented in existing README.md
- **Logging** added to existing log systems, don't create new ones

## Available Tools
- **Full-Stack Generator**: Creates Ash + DaisyUI + BMAD artifacts simultaneously
- **Cross-Stack Validator**: Ensures consistency across all layers
- **Real-Time Validator**: Monitors project for consistency issues
- **Theme Synchronizer**: Keeps colors aligned across backend/frontend

## Quick Commands
```bash
# Validate full-stack consistency
python3 lib/bmad_integration/validators/cross_stack_validator.py

# Generate full-stack resources
python3 lib/bmad_integration/tools/full_stack_tools.py

# Start real-time validation
python3 lib/bmad_integration/core/live-validation/realtime_validator.py
```

## Remember
- **Less documentation, more working code**
- **Clean up after yourself immediately**
- **Update existing files before creating new ones**
- **Test everything before claiming it works**
- **Keep the root directory clean**