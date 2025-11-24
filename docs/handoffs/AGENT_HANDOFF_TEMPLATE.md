# 🎯 AGENT HANDOFF TEMPLATE - Universal Implementation Guidelines

## 🚨 CRITICAL AGENT REQUIREMENTS

### **📖 MANDATORY READING BEFORE ANY CODING:**
1. **CLAUDE.md** - ✅ **ALWAYS READ FIRST** - Primary project guidelines, architecture, agent requirements
2. **AGENTS.md** - Phoenix/LiveView/Elixir/Ash Framework specific patterns and technology stack
3. **This Handoff** - Specific implementation context and current state

### **⚠️ ARCHITECTURE COMPLIANCE REQUIRED:**
- ✅ Ash Framework only (NEVER use Ecto patterns)
- ✅ Component-driven UI with DaisyUI (NEVER dashboard LiveViews)
- ✅ Evidence-based development (NEVER estimates or "I think")
- ✅ Follow project-specific technology stack exactly

---

## 📋 PURPOSE & USAGE

This template provides **mandatory guidelines, patterns, and quality requirements** for creating comprehensive agent handoff documents. Any AI agent receiving a handoff should be able to continue work seamlessly with complete context and clear objectives.

### **When to Use This Template:**
- Before ending any development session
- When handing off work to another AI agent
- When resuming work after a break
- For project milestone transitions
- For complex multi-phase implementations

---

## 🏗️ MANDATORY HANDOFF SECTIONS

### **1. IMPLEMENTATION STATUS SUMMARY**
*(Always start with this - provide evidence-based completion status)*

```markdown
## 🚀 CURRENT IMPLEMENTATION STATUS

**✅ Overall Completion: [X]% COMPLETE**

### **Successfully Delivered:**
- [ ] [Feature/Component 1] ✅
- [ ] [Feature/Component 2] ✅
- [ ] [Feature/Component 3] ✅

### **Partially Complete:**
- [ ] [Feature/Component] 🔄 ([X]% complete - specific work remaining)

### **Not Started:**
- [ ] [Feature/Component] ❌
```

**REQUIREMENTS:**
- Use evidence-based percentages (not estimates)
- List each deliverable with ✅/🔄/❌ status
- Include specific completion percentages for partial work
- Reference actual test results, compilation output, or working features

---

### **2. TECHNICAL INFRASTRUCTURE STATE**

```markdown
## 🛠️ CURRENT SYSTEM STATE

### **✅ Working Components:**
- **[Component Name]**: [Specific working status with evidence]
- **[Component Name]**: [Specific working status with evidence]
- **[Component Name]**: [Specific working status with evidence]

### **🎯 Architecture Ready:**
- **[Architecture Component]**: [What's ready for next phase]
- **[Architecture Component]**: [What's ready for next phase]

### **🔧 Key Files for Next Phase:**
- **[File Path]**: [Purpose and current state]
- **[File Path]**: [Purpose and current state]
- **[File Path]**: [Purpose and current state]
```

**REQUIREMENTS:**
- List only components with **verified working status**
- Include specific evidence (compilation success, test passes, etc.)
- Provide exact file paths with current state descriptions
- Mention any known limitations or issues

---

### **3. NEXT IMPLEMENTATION OBJECTIVES**

```markdown
## 📋 NEXT IMPLEMENTATION OBJECTIVES

### **Business Objectives:**
[Brief, clear business purpose of the next phase]

### **Key Implementation Stories:**

**Story [X.Y]: [Story Title]**
- [Specific requirement 1]
- [Specific requirement 2]
- [Specific requirement 3]

**Story [X.Y]: [Story Title]**
- [Specific requirement 1]
- [Specific requirement 2]
- [Specific requirement 3]

[Continue for all stories...]
```

**REQUIREMENTS:**
- Start with clear business objectives
- List all remaining stories/tasks with specific requirements
- Include story numbers and titles from project documentation
- Make requirements testable and specific

---

### **4. QUALITY VERIFICATION EVIDENCE**

```markdown
## ✅ QUALITY VERIFICATION EVIDENCE

### **Compilation Status:**
```
mix compile
# [Actual compilation output with success/failure evidence]
```

### **Test Results:**
```
mix test
# [Actual test output with pass/fail rates]
```

### **Database State:**
```
# [Migration status, table counts, key data]
```

### **Runtime Status:**
```
# [Application startup status, any errors]
```
```

**REQUIREMENTS:**
- Include **actual command output** (not summaries)
- Provide exact error messages or success indicators
- Show pass/fail rates with numbers
- Include timestamps where relevant

---

### **5. TECHNICAL DEBT & KNOWN ISSUES**

```markdown
## ⚠️ TECHNICAL DEBT & KNOWN ISSUES

### **High Priority:**
- **[Issue Title]**: [Description + Impact + Suggested Fix]

### **Medium Priority:**
- **[Issue Title]**: [Description + Impact + Suggested Fix]

### **Low Priority:**
- **[Issue Title]**: [Description + Impact + Suggested Fix]
```

**REQUIREMENTS:**
- Categorize issues by priority (High/Medium/Low)
- Include impact assessment for each issue
- Provide actionable fix suggestions
- Only include verified issues (not speculation)

---

### **6. ENVIRONMENT & DEPENDENCIES**

```markdown
## 🔧 ENVIRONMENT & DEPENDENCIES

### **Development Environment:**
- **Elixir Version**: [version]
- **Phoenix Version**: [version]
- **Database**: [type + version + connection status]
- **Cache**: [type + connection status]
- **Storage**: [type + configuration status]

### **Key Dependencies:**
- **[Package]**: [version + status]
- **[Package]**: [version + status]
- **[Package]**: [version + status]

### **Configuration Files:**
- **[Config File]**: [Key settings + status]
- **[Config File]**: [Key settings + status]
```

**REQUIREMENTS:**
- List exact versions of all major dependencies
- Include connection/operational status
- Reference specific configuration files and key settings
- Note any environment-specific requirements

---

## 🎪 COLLABORATIVE AGENT ACTIVATION

### **For New AI Agent Session:**

**🚨 CRITICAL - READ BEFORE ANY CODING:**

**1. Mandatory Reading (REQUIRED BEFORE ANY CODE CHANGES):**
- **CLAUDE.md**: ✅ **ALWAYS READ FIRST** - Primary project guidelines, architecture, and agent requirements
- **AGENTS.md**: Phoenix/LiveView/Elixir/Ash Framework specific patterns and technology requirements
- **Current Handoff**: This document for specific implementation context

**2. Architecture Compliance Verification:**
Before writing any code, confirm understanding:
- ✅ Ash Framework only (NO Ecto patterns)
- ✅ Component-driven UI with DaisyUI (NO dashboard LiveViews)
- ✅ Evidence-based development (NO estimates or "I think")
- ✅ Project-specific technology stack compliance

**3. Context Loading:**
```markdown
I've read CLAUDE.md and AGENTS.md and understand the project architecture requirements:
- ✅ Ash Framework only (no Ecto patterns)
- ✅ Component-driven UI with DaisyUI (no dashboard LiveViews)
- ✅ Evidence-based development (no estimates)

I'm continuing [Feature Name] implementation after successfully completing [Previous Phase].
[Previous Phase] is [X]% complete with [brief summary of achievements].

Ready to begin [Next Phase]: [Phase Title] with [number] stories covering [brief story overview].

The foundation is solid with [key foundation elements ready].
```

**4. System State Verification:**
```bash
# Always run these verification commands first:
mix compile
mix test
mix ecto.migrate
mix phx.server
```

**5. Quality Standards Compliance:**
- **Verification Before Completion**: Run verification commands before claiming success
- **Evidence-Based Claims**: Provide actual command output for all claims
- **TDD Principles**: Write tests before implementation when applicable
- **Code Quality**: Follow project-specific coding standards

**6. Project Architecture Compliance:**
- **Ash Framework Only**: Never use Ecto patterns - always use Ash resources and domains
- **Component-Driven UI**: Use DaisyUI components in `lib/mcp_web/components/`, never dashboard LiveViews
- **BMAD Integration**: Follow unified pattern language across Ash ↔ DaisyUI ↔ BMAD layers
- **Ash.Reactor**: Use `use Ash.Reactor` for complex workflows, not generic Reactor
- **No Stubs/Regressions**: Never create stub implementations or break existing functionality

---

## 📊 MANDATORY QUALITY CHECKS

### **Pre-Handoff Verification Checklist:**
- [ ] All code compiles without errors (`mix compile`)
- [ ] All tests pass (`mix test`)
- [ ] Database migrations are up to date (`mix ecto.migrate`)
- [ ] Application starts successfully
- [ ] No critical security vulnerabilities
- [ ] Documentation is updated
- [ ] Git status is clean (all changes committed)

### **Handoff Document Quality Checklist:**
- [ ] Evidence-based completion percentages provided
- [ ] Actual command output included (not summaries)
- [ ] Specific file paths and current states documented
- [ ] Known issues with impact assessments listed
- [ ] Next objectives are clear and actionable
- [ ] Environment and dependencies properly documented

### **Post-Handoff Verification Checklist:**
- [ ] New agent can compile the project
- [ ] New agent can run tests successfully
- [ ] New agent understands current system state
- [ ] New agent can identify next implementation steps
- [ ] All critical documentation is accessible

---

## 🚨 CRITICAL SUCCESS FACTORS

### **What Makes a Handoff SUCCESSFUL:**
✅ **Evidence-Based**: All claims backed by actual command output
✅ **Reproducible**: New agent can replicate current state
✅ **Complete**: No missing critical information
✅ **Actionable**: Clear next steps with specific requirements
✅ **Verified**: All quality checks pass before handoff

### **What Makes a Handoff FAIL:**
❌ **Estimates**: No "I think", "should be", or "probably"
❌ **Missing Context**: Incomplete system state description
❌ **No Evidence**: Claims without command output verification
❌ **Vague Objectives**: Unclear next implementation steps
❌ **Undocumented Dependencies**: Missing environment/dependency info

---

## 🎯 TEMPLATING PATTERNS

### **Evidence Pattern:**
```markdown
**Verification Evidence:**
- ✅ COMPILATION SUCCESS: `Generated mcp app` - All modules compile successfully
- ✅ MIGRATION COMPLETE: `== Migrated 20251123000001 in 0.0s` - Database schema updated
- ✅ TESTS PASSING: `29 doctests, 0 failures, 5 skipped` - Quality gates passed
```

### **Next Steps Pattern:**
```markdown
### **For New Agent Session:**
1. **Start new terminal** and navigate to project
2. **Run verification**: `mix compile && mix test`
3. **Load context**: "I'm continuing [feature] after [previous phase] completion"
4. **Begin with**: First story/iteration in the remaining work
```

### **Technical Architecture Pattern:**
```markdown
### **🏗️ Architecture Delivered:**
- **Database**: [schema changes, tables, indexes] - PostgreSQL with TimescaleDB, PostGIS, pgvector
- **Business Logic**: [Ash resources, domains, Reactor workflows] - Use Ash Framework ONLY
- **API Layer**: [controllers, routes, responses] - Phoenix controllers with proper authentication
- **UI Components**: [DaisyUI + Tailwind CSS Component-driven architecture]
  - **STACK**: DaisyUI components + Tailwind CSS v4 + Phoenix.Component
  - **Directory**: `lib/mcp_web/components/` for all reusable components
  - **Domain Components**: Feature-specific components (e.g., `McpWeb.GdprComponents`)
  - **Core Components**: Reuse `McpWeb.CoreComponents` (icon, flash, button, etc.)
  - **LiveView Composition**: Build interfaces from reusable components
  - **AVOID**: Monolithic dashboard-style LiveViews
- **Workflows**: [Ash.Reactor for complex workflows] - Use Reactor for GDPR, user lifecycle, etc.
- **Security**: [authentication, authorization, validation] - Proper Phoenix auth plugs
- **Infrastructure**: [Redis caching, MinIO storage, Oban jobs, Vault secrets]
```

---

## 📝 HANDOFF DOCUMENTATION STANDARDS

### **File Naming Convention:**
- `[FEATURE]_HANDOFF.md` - For feature-specific handoffs
- `[PHASE]_HANDOFF.md` - For phase-specific handoffs
- `[EPIC]_HANDOFF.md` - For epic-level handoffs

### **Storage Location:**
- **Primary**: `docs/` directory
- **Template**: `docs/implement/` directory
- **Archive**: `docs/handoffs/` directory (for historical tracking)

### **Version Control:**
- **Commit**: Always commit handoff documents before session end
- **Branch**: Use feature branches for complex implementations
- **Tag**: Use tags for major milestone completions

---

*Handoff Template Version: 1.0*
*Last Updated: 2025-11-23*
*Quality Standard: Evidence-Based Development*
*Verification Required: Yes*