# 🤖 AGENT ALIGNMENT RECOMMENDATIONS

## 🎯 PROBLEM STATEMENT

The GDPR implementation required significant refactoring due to conflicting guidance in documentation files. AGENTS.md contained outdated Phoenix guidance that conflicted with the project's specific architecture requirements.

## ✅ FIXED CONFLICTS

### **1. DaisyUI Conflict Resolution**
**Before:** AGENTS.md said "Never use daisyUI for a unique, world-class design"
**After:** AGENTS.md now states "Use DaisyUI components as the core UI system with custom styling for unique design"

**Project Reality:**
- CLAUDE.md explicitly lists "DaisyUI + Tailwind CSS" as core frontend stack
- GDPR implementation successfully used `McpWeb.GdprComponents` with DaisyUI patterns
- Component-driven architecture achieved with DaisyUI + Phoenix.Component

### **2. Ash Framework Guidance**
**Before:** No specific Ash Framework guidance in AGENTS.md
**After:** Added comprehensive Ash Framework section emphasizing:
- Ash Framework is CORE and MANDATORY
- No Ecto patterns allowed
- Use Ash.Reactor for complex workflows
- Evidence-based development required

### **3. Handoff Template Enhancement**
**Before:** No reference to mandatory reading
**After:** Added mandatory reading section:
- CLAUDE.md (Primary guidelines)
- AGENTS.md (Phoenix/Ash patterns)
- Current Handoff (Implementation context)

## 🚀 RECOMMENDATIONS FOR AGENT ALIGNMENT

### **1. Documentation Hierarchy Establishment**
```
Priority 1: CLAUDE.md (Project-specific guidelines)
Priority 2: AGENTS.md (Technology-specific patterns)
Priority 3: Feature handoffs (Implementation context)
```

### **2. Pre-Session Checklist for Agents**
Before starting any development session, agents should:

```bash
# Step 1: Read mandatory documentation
cat CLAUDE.md
cat AGENTS.md
cat [current_handoff].md

# Step 2: Verify system state
mix compile
mix test

# Step 3: Confirm architecture compliance
# - Am I using Ash Framework patterns?
# - Am I using component-driven UI with DaisyUI?
# - Am I following evidence-based development?
```

### **3. Architecture Compliance Validation**
Add automated checks to prevent architectural violations:

**File:** `scripts/check_architecture_compliance.sh`
```bash
#!/bin/bash
echo "🔍 Checking Architecture Compliance..."

# Check for Ecto usage (should not exist in new code)
if git grep --cached "Ecto\." -- "lib/**/*.ex" | grep -v "mix.exs"; then
    echo "❌ Ecto patterns found - use Ash Framework instead"
    exit 1
fi

# Check for component-driven UI
if ! ls lib/mcp_web/components/*.ex 1> /dev/null 2>&1; then
    echo "⚠️  No components found - ensure component-driven architecture"
fi

# Check for Ash usage
if ! ls lib/mcp/**/resources/*.ex 1> /dev/null 2>&1; then
    echo "⚠️  No Ash resources found - use Ash Framework patterns"
fi

echo "✅ Architecture compliance check passed"
```

### **4. Enhanced Project Onboarding Process**

**For New Agent Sessions:**

1. **Mandatory Context Loading** (Add to handoff template):
```markdown
## 🎯 PROJECT ARCHITECTURE COMPLIANCE

### **Technology Stack (MANDATORY):**
- **Backend**: Ash Framework (NO Ecto patterns)
- **Frontend**: DaisyUI + Tailwind CSS v4 + Phoenix.Component
- **Workflows**: Ash.Reactor for complex processes
- **Database**: PostgreSQL with TimescaleDB, PostGIS, pgvector
- **Infrastructure**: Redis, MinIO, Oban, Vault

### **Forbidden Patterns:**
- ❌ Ecto schemas, queries, changesets
- ❌ Dashboard-style LiveViews
- ❌ Generic Reactor (use Ash.Reactor)
- ❌ Inline scripts in templates
- ❌ Stub implementations

### **Required Patterns:**
- ✅ Ash resources and domains
- ✅ Component-driven UI with DaisyUI
- ✅ Evidence-based development
- ✅ Proper authentication/authorization
- ✅ Comprehensive test coverage
```

2. **Architecture Verification Command:**
```bash
# Add to mix.exs as a custom task
defp aliases do
  [
    "check.architecture": &check_architecture/1
  ]
end

defp check_architecture(_args) do
  # Run architecture compliance checks
end
```

### **5. Documentation Synchronization Process**

**Weekly Documentation Review:**
- Check for new conflicts between CLAUDE.md and AGENTS.md
- Update handoff template with new patterns discovered
- Add new technology-specific guidance as stack evolves
- Remove outdated Phoenix/LiveView patterns that don't apply

**Monthly Architecture Review:**
- Verify actual implementation matches documented patterns
- Update examples with current working code
- Add new compliance checks based on discovered issues
- Train agents on any architecture updates

### **6. Quality Gates Integration**

**Pre-commit Hooks:**
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "🔍 Running Architecture Compliance Checks..."

# Check for forbidden patterns
mix check.architecture

# Run quality checks
mix compile
mix test --max-failures=1

# Check for evidence in commits
if git log -1 --pretty=%B | grep -E "(I think|probably|should be)"; then
    echo "❌ Remove speculative language from commit message"
    exit 1
fi

echo "✅ All compliance checks passed"
```

## 🎉 EXPECTED OUTCOMES

### **Immediate Benefits:**
- ✅ No more conflicting documentation guidance
- ✅ Clear technology stack hierarchy
- ✅ Mandatory reading for all agents
- ✅ Architecture compliance validation

### **Long-term Benefits:**
- ✅ Consistent implementation patterns
- ✅ Reduced refactoring cycles
- ✅ Faster agent onboarding
- ✅ Higher code quality
- ✅ Better alignment with project goals

## 📋 IMPLEMENTATION PLAN

1. **Week 1**: Deploy enhanced documentation and handoff template
2. **Week 2**: Create architecture compliance scripts
3. **Week 3**: Add pre-commit hooks and quality gates
4. **Week 4**: Train agents on new processes
5. **Month 2**: Measure impact and refine based on results

---

*Last Updated: 2025-11-23*
*Status: Ready for Implementation*
*Priority: HIGH*