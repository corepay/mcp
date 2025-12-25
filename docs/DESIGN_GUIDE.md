# MCP UI Design & Implementation Guide

This document outlines the architectural standards, design patterns, and implementation guidelines for the MCP frontend. It serves as the source of truth for all UI development.

## 1. Core Philosophy

*   **Strict Separation of Concerns**: We strictly separate "Pure" UI components (visuals only) from "Business" components (logic & data).

## 2. Design System: DaisyUI + Tailwind v4
- **Framework**: [DaisyUI](https://daisyui.com) (Component Classes) + [Tailwind CSS v4](https://tailwindcss.com) (Utilities).
- **Reference**: Use [https://daisyui.com/llms.txt](https://daisyui.com/llms.txt) for context-optimized component documentation.
- **Theme**: "dark" (default) and "light" (optional), defined in `app.css`.
- **Custom CSS**: No custom CSS classes should be written unless absolutely necessary; use `@apply` or Tailwind utilities.

*   **Design Tokens**: All theming is driven by CSS variables defined in `app.css` and injected via `ThemePlug`. Hardcoded hex values are forbidden in components.
*   **Multi-Tenancy First**: Every UI decision must account for the 7 distinct portal contexts (Admin, Tenant, Merchant, etc.).
*   **Modern Aesthetics**: UI must be clean, motion-rich, and premium. **Micro-interactions** (hover states, transitions) are mandatory, not optional.

## 3. Agent & AI Guidelines

> [!IMPORTANT]
> **To all Agents and AI Assistants:** You must follow these rules strictly. Failure to do so results in broken UI and dissatisfied users.

1.  **Golden Rule**: **NEVER** write raw HTML for standard elements. ALWAYS use `McpWeb.Core.CoreComponents`.
    *   ❌ `<button class="btn btn-primary">Save</button>`
    *   ✅ `<.button variant="primary">Save</.button>`
2.  **No Magic Values**: Never use arbitrary pixel values like `w-[350px]` or colors like `bg-[#1a2b3c]`. ALWAYS use semantic tokens: `w-96` or `bg-primary`.
3.  **Motion by Default**: UI elements should feel alive.
    *   Use `phx-click-loading` on all action buttons.
    *   Use transitions for showing/hiding elements.
4.  **Alpine JS**: Use Alpine (`x-data`) *only* for purely client-side interactivity that does not require server roundtrips (e.g., toggling a dropdown menu, local tab switching). For everything else, use LiveView.

## 3. Interaction Design

*   **Loading States**: All async actions must have a visible loading state.
    *   Buttons: `icon="hero-arrow-path" class="animate-spin"`
    *   Containers: `<.skeleton>`
*   **Transitions**:
    *   Modals: Scale in/out.
    *   Drawers: Slide in/out.
    *   Alerts: Fade in/out.
*   **Feedback**: Every successful action needs a `put_flash(:info, ...)` or visible UI update. Every error needs a `put_flash(:error, ...)` or inline form error.

## 4. Architecture & Directory Structure

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

| Type | Location | Responsibility | Dependencies |
| :--- | :--- | :--- | :--- |
| **Core** | `components/core/` | Visual rendering only. Props-driven. | DaisyUI, Tailwind |
| **Layout** | `components/layouts/` | Page structure (Shell, Nav). | Core Components |
| **Business** | `components/portals/` | Domain logic, data formatting, specific workflows. | Core Components, Ash Resources |
| **LiveView** | `live/` | Page lifecycle, event handling, data fetching. | Business Components, Ash Resources |

## 5. Design System & Theming

We use a 3-tier inheritance model for theming:
1.  **Platform Default**: Defined in `assets/css/app.css` using Tailwind v4 `@theme`.
2.  **Tenant Override**: Injected at runtime via `ThemePlug`.
3.  **Merchant Override**: Injected at runtime via `ThemePlug` (for white-labeling).

### Design Tokens
We use semantic names for colors and properties. Use these Tailwind utilities:

*   **Colors**: `bg-primary`, `text-secondary`, `border-accent`, `bg-base-100` (surface), `text-base-content` (text).
*   **Status**: `alert-info`, `alert-success`, `alert-warning`, `alert-error`.
*   **Spacing**: Standard Tailwind spacing (`p-4`, `m-2`, `gap-6`).
*   **Typography**: `font-sans`, `text-xl`, `font-bold`.

### Live Style Guide
You can view the current design system in action at:
`http://localhost:4000/dev/style-guide`

## 6. Implementation Patterns

### A. Creating a New UI Element
1.  **Check Core**: Does a generic version exist in `CoreComponents`?
    *   *Yes*: Use it.
    *   *No*: Create a generic, prop-driven version in `CoreComponents` using DaisyUI classes.
2.  **Compose**: Use the Core component in your Business component or LiveView.

**DO NOT** write raw HTML like `<div class="bg-blue-500 ...">` in a LiveView.
**DO**: Use `<.card class="bg-primary">` or `<.button phx-click="save">`.

### B. Portal Routing
Routes are strictly segregated by scope and pipeline in `router.ex`.

*   **Platform Admin**: `scope "/admin", ... pipe_through [:browser, :platform_layout]`
*   **Tenant Portal**: `scope "/tenant", ... pipe_through [:browser, :tenant_layout]`
*   **Merchant Portal**: `scope "/app", ... pipe_through [:browser, :merchant_layout]`

### C. Data Access
*   **LiveViews** fetch data using Ash Resources.
*   **Business Components** accept data structs (e.g., `%User{}`) as attributes.
*   **Core Components** accept primitive types (strings, lists, booleans) or generic slots.

## 7. Requirements Checklist

Before submitting a PR, ensure:
- [ ] All UI components use `CoreComponents` (DaisyUI).
- [ ] No hardcoded colors (hex/rgb) are used; use semantic tokens.
- [ ] The component is placed in the correct directory (`core` vs `portals`).
- [ ] It works across all themes (light/dark/tenant-custom).
- [ ] It has loading states for async actions.
- [ ] It is responsive (mobile-first).
