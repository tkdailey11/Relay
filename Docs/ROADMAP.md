# Relay Roadmap

## Product Direction

Relay should grow from a focused terminal workspace into a better environment for managing development sessions and coding agents.

Growth should preserve the core model:

**Workspace → Session → Terminal**

Avoid turning Relay into a general-purpose IDE.

# 0.1 — Foundation

Focus:

- Native macOS app shell
- Workspace management
- libghostty terminal
- Multiple sessions
- Claude / Copilot / Shell launchers
- Session cards
- Persistent workspace list
- Relay visual design

This is the MVP.

# 0.2 — Session Quality

Potential features:

- Rename sessions
- Duplicate session
- Session keyboard shortcuts
- Better session status
- Recently closed sessions
- Reorder session cards
- Session-specific icons
- Improved command palette
- Per-workspace remembered active session

Goal:

Make managing several sessions feel effortless.

# 0.3 — Workspace Intelligence

Potential features:

- Automatic Git repository detection
- Branch display
- Dirty / clean status
- Repository root detection
- Workspace-specific launch commands
- Workspace environment configuration
- Workspace icons and colors
- Recent workspace activity

Goal:

Make each workspace feel like a persistent development context.

# 0.4 — Agent Awareness

Potential features:

- Detect Claude Code sessions
- Detect Copilot sessions
- Detect whether an agent is active, idle, or waiting
- Native notification when an agent needs input
- Agent status indicators on session cards
- Optional session activity history

Important:

Do not depend on fragile terminal text scraping unless necessary.

Prefer robust process or integration mechanisms when available.

# 0.5 — Terminal Power Features

Potential features:

- Split panes
- Drag sessions into splits
- Session groups
- Search
- Better terminal profiles
- Custom fonts
- Terminal themes
- Per-session environment
- Quick terminal commands

Goal:

Add power without making the default UI complicated.

# 0.6 — Remote Development

Potential features:

- SSH sessions
- Saved remote hosts
- Remote workspace mapping
- Remote session status
- Secure keychain-backed configuration

Goal:

Allow a workspace to represent local or remote development.

# 0.7 — Persistent Sessions

Explore:

- Persistent process host
- Lightweight Relay daemon
- tmux integration
- Restoring running sessions after Relay UI closes

This should be researched carefully before implementation.

Do not introduce a background architecture until the user experience clearly requires it.

# 0.8 — Workspace Tools

Potential features:

- Configurable project commands
- Start dev server
- Run tests
- Build project
- Custom command buttons
- Project-specific shortcuts

These should launch normal sessions rather than introduce a parallel task system whenever possible.

# 0.9 — Extensibility

Explore:

- Additional coding agents
- Custom session templates
- User-defined launchers
- Local integrations
- Plugin system

Possible future session providers:

- Claude Code
- GitHub Copilot
- OpenAI coding tools
- Gemini CLI
- Aider
- Custom shell command

Relay should not hard-code itself around any single AI vendor.

# 1.0 — Product Standard

Relay 1.0 should mean:

- Stable workspace model
- Stable session model
- Excellent libghostty integration
- Reliable process lifecycle
- Refined native macOS design
- Strong keyboard navigation
- Robust Claude / Copilot / Shell workflows
- High-quality settings experience
- Excellent accessibility
- High-quality onboarding
- Clear failure states

The goal is not maximum feature count.

The goal is for Relay to feel complete, fast, and unmistakably native to macOS.
