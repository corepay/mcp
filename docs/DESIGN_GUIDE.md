# MCP UI Design & Implementation Guide

This document outlines the architectural standards, design patterns, and implementation guidelines for the MCP frontend. It serves as the source of truth for all UI development.

## 1. Core Philosophy

- **Strict Separation of Concerns**: We strictly separate "Pure" UI components (visuals only) from "Business" components (logic & data).

## 2. Design System: DaisyUI + Tailwind v4

- **Framework**: [DaisyUI](https://daisyui.com) (Component Classes) + [Tailwind CSS v4](https://tailwindcss.com) (Utilities).
- **Reference**: Use [https://daisyui.com/llms.txt](https://daisyui.com/llms.txt) for context-optimized component documentation.
- **Theme**: "noir" (OLED Black - Default for Expert Tools), "dark" (Legacy Dark), and "light".
- **Design Tokens**: All theming is driven by CSS variables in `app.css`. **HARDCODED HEX VALUES ARE STRICTLY FORBIDDEN**. Agents must use semantic classes:
  - `bg-base-100`: Deepest background (OLED True Black).
  - `bg-base-200`: Secondary surfaces/sidebars (High contrast).
  - `bg-base-300`: Cards, dividers, and elevated surfaces.
  - `text-base-content`: Primary text (with `/40`, `/60`, `/80` opacity modifiers for hierarchy).
- **Multi-Tenancy First**: UI decisions must account for portal contexts (Admin, Tenant, Merchant, Reseller).
- **Noir Aesthetic**: For analytical and expert-grade interfaces (like the Intelligence Plane), target high-density, low-clutter, and high-contrast "Noir" OLED layouts.

## 3. Agent & AI Guidelines

> [!IMPORTANT]
> **To all Agents and AI Assistants:** You must follow these rules strictly. Failure to do so results in broken UI and dissatisfied users.

1.  **Golden Rule**: **NEVER** write raw HTML for standard elements. ALWAYS use `McpWeb.Core.CoreComponents`.
    - ❌ `<button class="btn btn-primary">Save</button>`
    - ✅ `<.button variant="primary">Save</.button>`
2.  **No Magic Values**: Never use arbitrary pixel values like `w-[350px]` or colors like `bg-[#1a2b3c]`. ALWAYS use semantic tokens: `w-96` or `bg-primary`.
3.  **Motion by Default**: UI elements should feel alive.
    - Use `phx-click-loading` on all action buttons.
    - Use transitions for showing/hiding elements.
4.  **Alpine JS**: Use Alpine (`x-data`) _only_ for purely client-side interactivity that does not require server roundtrips (e.g., toggling a dropdown menu, local tab switching). For everything else, use LiveView.

## 4. Layout Patterns: The "Panopticon" Standard

For expert tools and high-density portfolios (Underwriting, Risk, Multi-Merchant Management), use the **Three-Column Panopticon** layout:

1.  **Column 1: Intelligence Queue (20%)**: Navigation and triage. Fixed width or adaptive. Usually `bg-base-200`.
2.  **Column 2: Evidence Canvas (50%)**: The primary work area. High-density cards or feeds. Usually `bg-base-100`.
3.  **Column 3: Control Plane (30%)**: Sticky/Fixed action area. High-level metrics (Scores, Lineage). Usually `bg-base-200`.

### UI Component standards:

- **Glass Panels**: Use `.glass-panel` for elevated contrast over true black backgrounds.
- **Micro-Badges**: Use `badge-sm` or `badge-xs` with `font-bold` and semantic statuses:
  - `primary`: Success / Verified / Safe.
  - `warning`: Amber / Manual Review needed / Caution.
  - `error`: Crimson / Fraud / Rejected / Critical.
  - `accent`: Intelligence scans / AI insights / Secondary actions.

## 5. Typography Standards

- **Standard UI**: `Inter` (Sans-serif) for all labels, buttons, and navigation.
- **Forensic Data**: `JetBrains Mono` (Monospace) for all raw data, hashes, amounts, and forensic signals.
- **Weights**: Use `font-black` or `font-bold` for status metrics, `font-medium` for labels.

## 6. Interaction Design

- **Loading States**: All async actions must have a visible loading state.
  - Buttons: `icon="hero-arrow-path" class="animate-spin"`
  - Containers: `<.skeleton>`
- **Transitions**:
  - Modals: Scale in/out.
  - Drawers: Slide in/out.
  - Alerts: Fade in/out.
- **Feedback**: Every successful action needs a `put_flash(:info, ...)` or visible UI update. Every error needs a `put_flash(:error, ...)` or inline form error.

## 7. Architecture & Directory Structure

We organize `lib/mcp_web` to strictly separate concerns:

```text
lib/mcp_web/
├── components/
│   ├── core/           # [PURE] Generic DaisyUI wrappers. NO business logic.
│   │   ├── core_components.ex  # Button, Input, Modal, Table, etc.
│   │   ├── icons.ex            # SVG icon definitions
│   │   └── ...
│   ├── layouts/        # [PURE] Layout templates.
│   │   ├── app_shell.html.heex # Standard sidebar + navbar layout
│   │   ├── auth_layout.html.heex
│   │   └── portal_layouts.ex   # Layout definitions for specific portals
│   └── portals/        # [BUSINESS] Domain-specific components.
│       ├── platform/   # Components for Platform Admin
│       ├── tenant/     # Components for Tenant Portal
│       ├── merchant/   # Components for Merchant Portal
│       └── ...
├── live/
│   ├── platform/       # LiveViews for Platform Admin
│   ├── tenant/         # LiveViews for Tenant Portal
│   ├── merchant/       # LiveViews for Merchant Portal
│   ├── dev/
│   │   └── style_guide_live.ex # Reference implementation
│   └── ...
```

### Component Types

| Type         | Location              | Responsibility                                     | Dependencies                       |
| :----------- | :-------------------- | :------------------------------------------------- | :--------------------------------- |
| **Core**     | `components/core/`    | Visual rendering only. Props-driven.               | DaisyUI, Tailwind                  |
| **Layout**   | `components/layouts/` | Page structure (Shell, Nav).                       | Core Components                    |
| **Business** | `components/portals/` | Domain logic, data formatting, specific workflows. | Core Components, Ash Resources     |
| **LiveView** | `live/`               | Page lifecycle, event handling, data fetching.     | Business Components, Ash Resources |

## 8. Design System & Theming (Tiered Logic)

We use a 3-tier inheritance model for theming:

1.  **Platform Default**: Defined in `assets/css/app.css` using Tailwind v4 `@theme`.
2.  **Tenant Override**: Injected at runtime via `ThemePlug`.
3.  **Merchant Override**: Injected at runtime via `ThemePlug` (for white-labeling).

### Design Tokens

We use semantic names for colors and properties. Use these Tailwind utilities:

- **Colors**: `bg-primary`, `text-secondary`, `border-accent`, `bg-base-100` (surface), `text-base-content` (text).
- **Status**: `alert-info`, `alert-success`, `alert-warning`, `alert-error`.
- **Spacing**: Standard Tailwind spacing (`p-4`, `m-2`, `gap-6`).
- **Typography**: `font-sans`, `text-xl`, `font-bold`.

### Live Style Guide

You can view the current design system in action at:
`http://localhost:4000/dev/style-guide`

## 9. Implementation Patterns

### A. Creating a New UI Element

1.  **Check Core**: Does a generic version exist in `CoreComponents`?
    - _Yes_: Use it.
    - _No_: Create a generic, prop-driven version in `CoreComponents` using DaisyUI classes.
2.  **Compose**: Use the Core component in your Business component or LiveView.

**DO NOT** write raw HTML like `<div class="bg-blue-500 ...">` in a LiveView.
**DO**: Use `<.card class="bg-primary">` or `<.button phx-click="save">`.

### B. Portal Routing

Routes are strictly segregated by scope and pipeline in `router.ex`.

- **Platform Admin**: `scope "/admin", ... pipe_through [:browser, :platform_layout]`
- **Tenant Portal**: `scope "/tenant", ... pipe_through [:browser, :tenant_layout]`
- **Merchant Portal**: `scope "/app", ... pipe_through [:browser, :merchant_layout]`

### C. Data Access

- **LiveViews** fetch data using Ash Resources.
- **Business Components** accept data structs (e.g., `%User{}`) as attributes.
- **Core Components** accept primitive types (strings, lists, booleans) or generic slots.

## 10. Requirements Checklist

Before submitting a PR, ensure:

- [ ] All UI components use `CoreComponents` (DaisyUI).
- [ ] No hardcoded colors (hex/rgb) are used; use semantic tokens.
- [ ] The component is placed in the correct directory (`core` vs `portals`).
- [ ] It works across all themes (light/dark/tenant-custom).
- [ ] It has loading states for async actions.
- [ ] It is responsive (mobile-first).
