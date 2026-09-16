# Relay Design Specification

## Design Direction

Relay should feel deeply native to modern macOS.

The interface should be:

- Apple-focused
- Minimal
- Spatial
- Refined
- Cutting edge
- Keyboard friendly
- Dark-first
- Comfortable for long development sessions

The visual direction is inspired by modern macOS design language, including Liquid Glass, layered materials, rounded cards, subtle depth, and restrained use of color.

## Branding

### Name

**Relay**

### Tagline

**Your terminal sessions, in motion.**

### Core Visual Idea

The Relay icon uses two broad, rounded arrows surrounding a centered terminal prompt (`>_`). The cyan upper arrow turns right; the violet lower arrow turns left. A softly shaded, rounded square forms the background.

- Light variant: white/paper tile with an ink-colored prompt.
- Dark variant: charcoal/ink tile with a white prompt.
- The sidebar follows the system appearance; the macOS app icon uses the light variant.
- The wordmark is bold **Relay**, paired with “Your terminal sessions, in motion.”
- Brand themes: Focus / Context / Momentum.

Vector drawing and all app-icon sizes are reproducible with `swift Scripts/GenerateBrandAssets.swift`. Artwork is stored in `Relay/Assets.xcassets/`.

## Brand Colors

- Cyan: `#0EA5FF` (primary accent)
- Violet: `#8B5CF6` (secondary accent)
- Ink: `#111827`
- Mist: `#E5E7EB`
- Paper: `#F8FAFC`

Use the accent sparingly.

Preferred uses:

- Selected workspace
- Active session
- Focus states
- Important status indicators
- Session transition animations
- Primary actions

Avoid applying gradients to every surface.

## Window Structure

The primary Relay window should contain:

1. Workspace sidebar
2. Workspace header
3. Session card row
4. Terminal surface
5. Optional lightweight status area

Conceptual layout:

```text
┌───────────────────────────────────────────────────────────────┐
│ Sidebar │ Workspace Header                                   │
│         │                                                    │
│         │ Session Card  Session Card  Session Card   +       │
│         │                                                    │
│         │ ┌───────────────────────────────────────────────┐  │
│         │ │                                               │  │
│         │ │                 Terminal                      │  │
│         │ │                                               │  │
│         │ └───────────────────────────────────────────────┘  │
│         │                                                    │
│         │ Status                                             │
└───────────────────────────────────────────────────────────────┘
```

## Sidebar

The sidebar contains workspaces and one Temporary Sessions destination; it does not list individual sessions.

Recommended content:

- Relay branding near the top
- Workspace section
- Add Workspace action
- Temporary Sessions destination
- Temporary session launchers fixed near the bottom

The sidebar should use translucent or Liquid Glass materials.

The selected workspace should be obvious without being visually loud.

### Workspace Row

A workspace row may contain:

- Folder/project icon
- Workspace name
- New Session menu for Claude, Copilot, and Shell in that workspace
- Path
- Optional subtle status

Do not show nested sessions in the sidebar.

## Start Session Area

The bottom of the sidebar should label its launch controls **Temporary Session** and provide:

- Claude
- Copilot
- Shell

These should be visually distinct but compact.

Clicking one always creates a temporary session in the user’s home directory and selects Temporary Sessions. These sessions remain available while navigating, but are cleared on quit. The destination uses the same card and terminal layout, with an explicit temporary-lifetime label.

## Workspace Header

The top of the main area may show:

- Workspace icon
- Workspace name
- New Session menu for Claude, Copilot, and Shell in that workspace
- Path
- Git branch, if available
- Git status, if useful
- Search / command palette access

Keep this area compact.

## Session Cards

Sessions should appear as cards across the top of the workspace content area.

A card may show:

- Agent / shell icon
- Session type
- Session name
- Status
- Optional activity indicator
- Context menu

Example:

```text
┌──────────────────┐
│ Claude           │
│ API Refactor     │
│ ● Running        │
└──────────────────┘
```

Possible states:

- Active
- Running
- Idle
- Waiting for input
- Completed
- Failed

The active card may use a subtle Relay-blue glow or stronger material treatment.

Avoid overly bright borders.

## Terminal Surface

The terminal is the visual anchor of the app.

Rules:

- Keep the terminal flatter than the surrounding UI
- Prioritize contrast and text readability
- Avoid transparency behind terminal text unless extremely subtle
- Avoid decorative gradients inside the terminal
- Use libghostty for terminal behavior and rendering
- Let the terminal feel precise while the surrounding chrome feels soft

The contrast between crisp terminal content and translucent Relay chrome is intentional.

## Liquid Glass Usage

Liquid Glass should be used primarily for:

- Sidebar
- Toolbar
- Session cards
- Popovers
- Context menus
- Search / command palette
- Status chrome
- Optional inspector panels

Do not make every surface translucent.

Too much glass will reduce readability and make the UI feel ornamental rather than productive.

## Cards

Cards should communicate hierarchy.

Good card uses:

- Sessions
- Workspace overview modules
- Inspector sections
- Empty-state actions

Avoid wrapping every individual control in a card.

## Motion

Motion should be subtle and useful.

Possible interactions:

- Session cards gently lift on hover
- Active session transitions use a short slide or directional blur
- Waiting sessions may use a restrained pulse
- Sidebar selection transitions smoothly
- Inspectors slide in from the right
- Popovers use native macOS timing and spring behavior

Avoid flashy or prolonged animations.

## Typography and Icons

Prefer:

- SF Pro
- SF Mono for terminal-adjacent metadata where appropriate
- SF Symbols for native UI controls

Use custom icons only where brand identity or external tool recognition requires them.

## Dark and Light Modes

Support both.

Design dark mode first.

Dark mode should use:

- Deep navy / charcoal terminal areas
- Translucent dark glass chrome
- Blue / purple Relay accents

Light mode should preserve hierarchy without becoming washed out.

## Interaction Principles

Relay should be:

- Keyboard-first without being keyboard-only
- Easy to understand without documentation
- Familiar to macOS users
- Fast to scan
- Calm under heavy use

Useful shortcuts may include:

- Command Palette
- New Session
- Switch Workspace
- Switch Session
- Close Session
- Add Workspace
