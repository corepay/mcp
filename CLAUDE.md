# DaisyUI Knowledge Base

## Component Library (50+ Components)
- **Form Controls**: button, input, textarea, select, checkbox, radio, toggle, range, file input
- **Navigation**: navbar, sidebar, breadcrumbs, pagination, tabs, steps
- **Data Display**: card, alert, badge, avatar, divider, collapse, accordion, timeline
- **Feedback**: loading, spinner, progress, toast, modal, drawer, dropdown, tooltip
- **Layout**: container, hero, footer, stats, stack
- **Interactive**: swap, countdown, timer, countdown timer
- **Advanced**: join, artboard, phone mockup, mockup code, mockup browser

## DaisyUI Pattern System
### Component Structure: {component} {part} {modifier}
- **Components**: card, btn, modal, input, etc.
- **Parts**: body, title, content, actions, etc.
- **Modifiers**: primary, secondary, success, warning, error, info, ghost, link

### Size Modifiers
- btn-xs, btn-sm, btn-md, btn-lg, btn-xl
- Same pattern applies to other components

### Color System (Semantic Names)
- **primary**: Main brand color
- **secondary**: Secondary accent
- **accent**: Highlight color
- **neutral**: Gray scale
- **base**: Background colors
- **info**: Blue tones
- **success**: Green tones
- **warning**: Yellow/amber tones
- **error**: Red tones

### State Modifiers
- **disabled**: Disabled state
- **loading**: Loading state
- **active**: Active/selected state
- **focus**: Focus state
- **hover**: Hover state

### Animation & Effects
- **hover-**: hover effects (hover:hover, hover:bg-primary, etc.)
- **group-**: group hover states
- **transition-**: smooth transitions
- **swap**: component swapping animations

## Responsive Design Patterns
- Mobile-first approach
- Responsive modifiers built into Tailwind
- Collapse/expand patterns for mobile

## Theme System
### Light/Dark Mode
- Automatic theme switching
- Custom theme configuration
- CSS custom properties for colors

### Custom Themes
- Define custom color schemes
- Override default DaisyUI themes
- Component-specific theming

## Best Practices
- Use semantic color names (primary, success) over literal colors
- Leverage component variants for consistency
- Combine with Tailwind utilities for custom styling
- Maintain accessibility with proper contrast ratios

---

# Ash Framework Knowledge Base

## Core Concepts
- **Resources**: Domain models with actions, attributes, and validations
- **Actions**: CRUD operations (create, read, update, destroy) + custom actions
- **Attributes**: Data fields with types, validations, and constraints
- **Relationships**: belongs_to, has_one, has_many, many_to_many
- **Policies**: Authorization and access control
- **Changesets**: Data transformation pipelines

## Resource Definition Pattern
```elixir
defmodule MyApp.Resources.User do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :email, :string, allow_nil?: false
  end

  relationships do
    has_many :posts, MyApp.Resources.Post
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

## Action Types
- **Read**: show, list, read
- **Create**: create
- **Update**: update
- **Destroy**: destroy
- **Generic**: Custom business logic actions

## Usage Rules System
- **usage-rules.md**: Auto-generated documentation per package
- **Rule combining**: Multiple rule sets can be combined
- **Validation**: Enforces best practices and constraints
- **Documentation**: Self-documenting system

## Extensions & Integrations
- **AshPostgres**: PostgreSQL data layer
- **AshJsonApi**: JSON:API API layer
- **AshGraphql**: GraphQL API layer
- **AshAdmin**: Admin interface generation
- **AshArchival**: Soft deletion
- **AshPaperTrail**: Audit trails

## Code Generation
- **Generators**: Resource, domain, API scaffolding
- **Templates**: Customizable code templates
- **Migrations**: Database schema management

---

# BMAD Integration Patterns

## Unified Syntax
```
ash://resource.action:modifier
daisyui://component-part:modifier
bmad://workflow.step:modifier
```

## Cross-Stack Mapping
| Ash Resource | DaisyUI Component | BMAD Workflow |
|-------------|------------------|---------------|
| UserResource | user-card | user_lifecycle |
| PostResource | post-card | post_lifecycle |
| CommentResource | comment-thread | comment_lifecycle |

## Integration Commands
```bash
# Validate cross-stack consistency
python3 lib/bmad_integration/validators/cross_stack_validator.py

# Generate full-stack resources
python3 lib/bmad_integration/tools/full_stack_tools.py

# Real-time validation monitoring
python3 lib/bmad_integration/core/live-validation/realtime_validator.py
```

---

## Project-Specific Rules
- always warn about the context remaining and before starting a new task make sure there the remaining context in the session is enough to complete the next task.  If not enough context, ask the user to use compact or create a new agent handoff doc for the remaning tasks
- Anything less than a 100% passing test rate for any implementation is unacceptable.  Assume this requirement and do not ask for confiration or propose moving on or alternatives.
- Minimize documentation - prefer terminal output and self-documenting code
- Do not lie
- Maintain doc hygiene - update existing docs rather than creating new ones
- Keep root directory clean - organize features in appropriate subdirectories
- Use lib/ directory for all implementation code following Phoenix conventions
- Test actual functionality before claiming features work
- Clean up temporary files and testing artifacts immediately