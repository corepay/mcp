# MCP UI Design & Implementation Guide

This document outlines the architectural standards, design patterns, and implementation guidelines for the MCP frontend. It serves as the source of truth for all UI development.

## 1. Core Philosophy

*   **Strict Separation of Concerns**: We strictly separate "Pure" UI components (visuals only) from "Business" components (logic & data).
*   **DaisyUI & Tailwind v4**: We leverage DaisyUI for component primitives and Tailwind v4 for utility-first styling. **No custom CSS classes** should be written unless absolutely necessary; use `@apply` or Tailwind utilities.
*   **Design Tokens**: All theming is driven by CSS variables defined in `app.css` and injected via `ThemePlug`. Hardcoded hex values are forbidden in components.
*   **Multi-Tenancy First**: Every UI decision must account for the 7 distinct portal contexts (Admin, Tenant, Merchant, etc.).

## 2. Architecture & Directory Structure

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
│   └── ...
```

### Component Types

| Type | Location | Responsibility | Dependencies |
| :--- | :--- | :--- | :--- |
| **Core** | `components/core/` | Visual rendering only. Props-driven. | DaisyUI, Tailwind |
| **Layout** | `components/layouts/` | Page structure (Shell, Nav). | Core Components |
| **Business** | `components/portals/` | Domain logic, data formatting, specific workflows. | Core Components, Ash Resources |
| **LiveView** | `live/` | Page lifecycle, event handling, data fetching. | Business Components, Ash Resources |

## 3. Design System & Theming

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

### Example: Theming in `app.css`
```css
@theme {
  --color-primary: oklch(55% 0.2 260);
  --color-secondary: oklch(65% 0.15 200);
  /* ... */
}
```

## 4. Implementation Patterns

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
*   **Tenant Portal**: `scope "/portal", ... pipe_through [:browser, :tenant_layout]`
*   **Merchant Portal**: `scope "/app", ... pipe_through [:browser, :merchant_layout]`

### C. Data Access
*   **LiveViews** fetch data using Ash Resources.
*   **Business Components** accept data structs (e.g., `%User{}`) as attributes.
*   **Core Components** accept primitive types (strings, lists, booleans) or generic slots.

## 5. Requirements Checklist

Before submitting a PR, ensure:
- [ ] All UI components use `CoreComponents` (DaisyUI).
- [ ] No hardcoded colors (hex/rgb) are used; use semantic tokens.
- [ ] The component is placed in the correct directory (`core` vs `portals`).
- [ ] It works across all themes (light/dark/tenant-custom).
- [ ] It is responsive (mobile-first).
