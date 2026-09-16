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

The Relay icon uses:

- A terminal prompt symbol: `>_`
- Two opposing directional arrows
- Blue-to-purple accent colors
- A flat, modern macOS-style presentation

The arrows communicate movement between sessions and contexts.

The terminal prompt makes the product category immediately recognizable.

## Brand Colors

Primary accent direction:

- Cyan / bright blue
- Violet / purple

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

The sidebar contains workspaces only.

Recommended content:

- Relay branding near the top
- Workspace section
- Add Workspace action
- Session launchers fixed near the bottom

The sidebar should use translucent or Liquid Glass materials.

The selected workspace should be obvious without being visually loud.

### Workspace Row

A workspace row may contain:

- Folder/project icon
- Workspace name
- Path
- Optional subtle status

Do not show nested sessions in the sidebar.

## Start Session Area

The bottom of the sidebar should provide fast launch controls for:

- Claude
- Copilot
- Shell

These should be visually distinct but compact.

When a workspace is selected, clicking one of these should immediately launch that session in the selected workspace unless additional configuration is genuinely required.

## Workspace Header

The top of the main area may show:

- Workspace icon
- Workspace name
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
