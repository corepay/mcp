# Portal Components - Responsive Breakpoints Quick Reference

## At-a-Glance Grid

```
┌─────────────────────────────────────────────────────────────────────┐
│                     RESPONSIVE BEHAVIOR MATRIX                      │
├──────────────┬──────────────┬─────────────────┬─────────────────────┤
│  Component   │ Mobile       │ Tablet          │ Desktop             │
│              │ (<768px)     │ (768-1023px)    │ (≥1024px)          │
├──────────────┼──────────────┼─────────────────┼─────────────────────┤
│ StatsRow     │  ┌──┬──┐    │  ┌──┬──┬──┬──┐  │  ┌──┬──┬──┬──┐     │
│              │  ├──┼──┤    │  └──┴──┴──┴──┘  │  └──┴──┴──┴──┘     │
│              │  └──┴──┘    │                 │                     │
│  Classes:    │ grid-cols-2  │  md:grid-cols-4 │  md:grid-cols-4    │
├──────────────┼──────────────┼─────────────────┼─────────────────────┤
│ PageLayout   │  ┌────────┐  │  ┌────────┐     │  ┌──────┬───┐      │
│ (list/detail)│  │Content │  │  │Content │     │  │ 2/3  │1/3│      │
│              │  └────────┘  │  └────────┘     │  │      │   │      │
│              │  ┌────────┐  │  ┌────────┐     │  │      │   │      │
│              │  │Sidebar │  │  │Sidebar │     │  └──────┴───┘      │
│              │  └────────┘  │  └────────┘     │                     │
│  Classes:    │ grid-cols-1  │  grid-cols-1    │  lg:grid-cols-3    │
├──────────────┼──────────────┼─────────────────┼─────────────────────┤
│ ActionSidebar│  Below       │  Below          │  Right Column       │
│              │  content     │  content        │  (w-72 = 288px)     │
│  Classes:    │ w-72         │  w-72           │  w-72 sticky        │
├──────────────┼──────────────┼─────────────────┼─────────────────────┤
│ DataTable    │  ← scroll →  │  ← scroll →     │  Full table         │
│              │  (if wide)   │  (if wide)      │  (scroll if needed) │
│  Classes:    │overflow-x-auto│overflow-x-auto  │overflow-x-auto     │
├──────────────┼──────────────┼─────────────────┼─────────────────────┤
│ FocusedLayout│  ┌────────┐  │  ┌─────┬────┐   │  ┌─────┬────┐      │
│ (two_panel)  │  │  Left  │  │  │ 60% │40% │   │  │ 60% │40% │      │
│              │  ├────────┤  │  │     │    │   │  │     │    │      │
│              │  │ Right  │  │  └─────┴────┘   │  └─────┴────┘      │
│              │  └────────┘  │                 │                     │
│  Classes:    │  flex-col    │  w-3/5 + w-2/5  │  w-3/5 + w-2/5     │
├──────────────┼──────────────┼─────────────────┼─────────────────────┤
│ FocusedLayout│              │                 │                     │
│ (centered)   │  ┌────────┐  │  ┌─────────┐    │    ┌─────────┐     │
│              │  │ Max    │  │  │ Max-2xl │    │    │ Max-2xl │     │
│              │  │ Width  │  │  │ 672px   │    │    │ 672px   │     │
│              │  └────────┘  │  └─────────┘    │    └─────────┘     │
│  Classes:    │  max-w-2xl   │  max-w-2xl      │  max-w-2xl         │
└──────────────┴──────────────┴─────────────────┴─────────────────────┘
```

## Tailwind Breakpoints

```
    0px         640px        768px        1024px       1280px      1536px
    │            │            │            │            │            │
    ├────────────┼────────────┼────────────┼────────────┼────────────┤
    │   mobile   │     sm:    │     md:    │     lg:    │     xl:    │  2xl:
    │   (base)   │            │            │            │            │
    └────────────┴────────────┴────────────┴────────────┴────────────┘
                              ▲            ▲
                              │            │
                    Most components    PageLayout
                    use this break     sidebar break
```

## Component Classes Cheat Sheet

```elixir
# StatsRow
"grid grid-cols-2 md:grid-cols-4 gap-4"
#     │           └─ 4 cols @ 768px+
#     └─ 2 cols base (mobile)

# PageLayout (list/detail)
"grid grid-cols-1 lg:grid-cols-3 gap-6"
#     │           └─ 2/3+1/3 @ 1024px+
#     └─ 1 col base (stacked)

# ActionSidebar
"w-72 sticky top-20"
# │    │      └─ Sticky offset
# │    └─ Stick to viewport when scrolling
# └─ Fixed width 288px (18rem)

# DataTable
"overflow-x-auto"
# └─ Horizontal scroll on overflow

# FocusedLayout (two_panel)
"w-3/5" + "w-2/5"  # Left: 60%, Right: 40%

# FocusedLayout (centered/wizard)
"max-w-2xl mx-auto"  # Max width 672px, centered
```

## Testing Viewports

```
Device           Width × Height    Breakpoint
─────────────────────────────────────────────────
iPhone SE        375  × 667        Mobile
iPhone 12 Pro    390  × 844        Mobile
iPad Mini        768  × 1024       Tablet (md:)
iPad Air         820  × 1180       Tablet (md:)
MacBook Air      1440 × 900        Desktop (lg:)
Desktop HD       1920 × 1080       Desktop (lg:)
```

## Common Patterns

### Mobile-First CSS
```elixir
# ❌ Don't: Desktop-first
"grid-cols-4 md:grid-cols-2"

# ✅ Do: Mobile-first
"grid-cols-2 md:grid-cols-4"
```

### Responsive Gaps
```elixir
"gap-4 md:gap-6 lg:gap-8"
#  │     │        └─ 32px @ 1024px+
#  │     └─ 24px @ 768px+
#  └─ 16px base
```

### Responsive Padding
```elixir
"p-4 md:p-6 lg:p-8"
#  │    │      └─ 32px @ 1024px+
#  │    └─ 24px @ 768px+
#  └─ 16px base
```

## Quick Checks

### Is your component responsive?
- [ ] Uses mobile-first approach (base → md: → lg:)
- [ ] Tested at 375px, 768px, 1024px widths
- [ ] No horizontal scroll on mobile (unless intentional)
- [ ] Touch targets ≥44×44px on mobile
- [ ] Text remains readable at all sizes

### Common Issues
| Issue | Fix |
|-------|-----|
| Table too wide on mobile | Add `overflow-x-auto` wrapper |
| Stats cramped on mobile | Use `grid-cols-2 md:grid-cols-4` |
| Sidebar overlaps content | Use `grid-cols-1 lg:grid-cols-3` |
| Text too small on mobile | Minimum `text-base` (16px) |
| Buttons too small to tap | Minimum `h-11` (44px) on mobile |

## Dev Page Access

**URL:** `http://localhost:4000/dev/portal-components`

Use the dev page to:
- ✅ See all components with live examples
- ✅ Test responsive behavior in real-time
- ✅ Reference component usage patterns
- ✅ Verify design consistency

---

**See also:**
- Full guide: `/docs/portal_components_responsive_guide.md`
- Component source: `/lib/mcp_web/components/portal/`
- Dev page: `/lib/mcp_web/live/dev/portal_components_live.ex`
