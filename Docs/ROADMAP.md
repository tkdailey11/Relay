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

# On-Device Intelligence (Cross-Cutting)

This is a track that rides along with other releases, not a numbered version. It explores using Apple's `FoundationModels` framework (the on-device Apple Intelligence model) where it makes switching between sessions faster. Do not add AI features for their own sake.

Potential features:

- Suggested session names (0.3, alongside Git and working-directory detection). Use cwd, branch, and foreground process first; use the model only when those give no useful name. Suggest, never auto-rename.
- "What happened" summaries for background sessions (0.4, alongside agent awareness). When a session needs attention or exits, show a one-line summary of its recent output, such as why a build failed. Also a "where you left off" line when reopening a workspace.
- Natural-language command palette queries, such as "the session running the dev server". Only used when ordinary matching finds nothing, and only resolves to existing sessions and palette commands.

Principles:

- On-device only. Terminal output can contain secrets; it must never leave the Mac.
- Optional. Check model availability and fall back to the non-AI behavior on unsupported Macs or when Apple Intelligence is off. The no-AI path is the default experience.
- Suggestions only. The model never runs commands or changes state without the user confirming.
- Isolated. Keep `FoundationModels` behind a small protocol in `Services/`, as with libghostty and `TerminalKit`. Product UI and domain models must not depend on it directly.
- Mind the small context window. Strip ANSI sequences, send only the recent tail of output, redact obvious secrets, and cache results per session. Regenerate on state transitions, not on every output chunk.
- Structured process or integration signals decide *when* to summarize; the model only decides *what to say*. This keeps summaries from becoming the fragile terminal text scraping that 0.4 warns against.
- Do not persist generated summaries to disk without a deliberate decision, since they may contain sensitive text.

Not planned: natural-language-to-shell-command generation, autocomplete, or a general chat sidebar.

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
