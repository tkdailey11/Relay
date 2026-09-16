# Relay MVP

## Goal

Build the smallest version of Relay that proves the product model:

**A native macOS terminal where users organize work by workspace and run multiple terminal or coding-agent sessions inside each workspace.**

The MVP should prioritize stability, responsiveness, and product feel over feature count.

## MVP Success Criteria

Relay 0.1 is successful if a user can:

1. Launch Relay.
2. Add a local directory as a workspace.
3. Select that workspace.
4. Start a Shell session.
5. Start a Claude session.
6. Start a Copilot session.
7. Switch between sessions.
8. Switch between workspaces.
9. Quit and reopen Relay without losing workspace definitions.
10. Create temporary Shell, Claude, or Copilot sessions without selecting a workspace.
11. Switch between temporary sessions and workspaces without losing sessions during the app lifetime.
12. Feel that the app already behaves like a polished native Mac application.

## Milestone 1 — Application Shell

Build:

- macOS SwiftUI app
- Main window
- Sidebar
- Workspace placeholder list
- Temporary Sessions navigation destination
- Main content placeholder
- Dark/light mode support
- Relay branding assets

No terminal integration yet.

### Done When

The application visually resembles the agreed Relay design and basic navigation works.

## Milestone 2 — Workspace Model

Build:

- Workspace model
- Add Workspace using NSOpenPanel
- Persist workspaces locally
- Select workspace
- Remove workspace
- Remember last selected workspace

### Done When

A user can build a persistent list of project directories.

## Milestone 3 — Terminal Integration

Build:

- `TerminalKit`
- libghostty integration
- One embedded terminal
- Start user shell in selected workspace directory
- Keyboard focus
- Resize behavior
- Clipboard basics

### Done When

Relay can function as a basic terminal inside a workspace.

## Milestone 4 — Multiple Sessions

Build:

- Session model
- Session Manager
- Multiple sessions per workspace
- Session cards
- Active session switching
- Close session
- New Shell session
- A New Session menu in each workspace header for Claude, Copilot, and Shell
- Temporary sessions outside workspaces, available through a dedicated sidebar destination

### Done When

A workspace can contain multiple usable terminal sessions.

## Milestone 5 — Claude and Copilot Launchers

Build session launchers for:

- Claude
- Copilot
- Shell

Workspace header launchers use that workspace’s directory and create persisted session metadata in that workspace.

The bottom-left Claude, Copilot, and Shell controls always create a **temporary session**, even when a workspace is selected. They require no workspace and use the user’s home directory. Creating one selects the Temporary Sessions destination. This destination uses the same session cards and terminal layout, including a New Session menu and close-session controls.

Temporary sessions remain available when switching destinations during the current app lifetime. Their metadata, selection, and running processes are not restored after quitting. They never appear in a workspace’s session list or persisted workspace data. In the UI-shell milestone, both types remain previews and launch no processes.

If the required executable is missing, show a helpful native error instead of failing silently.

### Done When

Both the workspace header launchers and the three temporary-session controls at the bottom of the sidebar work.

## Milestone 6 — Polish

Add:

- Liquid Glass / material treatments
- Hover states
- Active session state
- Basic session status
- Native context menus
- Keyboard shortcuts
- Command palette or quick switcher if time permits
- Better empty states
- App icon

### Done When

Relay feels intentional rather than like a technical prototype.

## MVP UI

### Sidebar

Contains:

- Relay branding
- Workspaces
- Temporary Sessions destination (not individual session rows)
- Add Workspace
- Temporary Session area with Claude, Copilot, and Shell launchers

Does not contain:

- Individual sessions
- Agents
- Snippets
- Git sections
- Settings navigation

Settings should use standard macOS patterns.

### Main Workspace Content

Contains:

- Workspace title
- Workspace path
- New Session menu for Claude, Copilot, and Shell
- Optional Git branch metadata
- Session cards
- Terminal

### Session Cards

Initial metadata:

- Session type
- Session title
- Active state
- Simple status

Do not build complex monitoring yet.

## MVP Data Persistence

Persist:

- Workspace list
- Workspace order
- Last selected workspace
- Workspace session metadata and per-workspace selected session

Do not persist temporary sessions or their selection. Reopen the last selected workspace when available; otherwise show an empty Temporary Sessions destination.

Do not require persistent running processes across app termination.

## Explicitly Out of Scope

Do not implement these in 0.1:

- SSH manager
- Split panes
- Terminal collaboration
- Full Git UI
- Source editor
- File explorer
- Diff viewer
- Agent orchestration
- Agent prompt queues
- Background agent monitoring
- Process restoration across system reboot
- Plugins
- Cloud sync
- Accounts
- Team features
- Remote workspaces

## Development Rule

When choosing between:

A. Adding another feature  
B. Making workspace/session switching feel excellent

Choose **B**.

That interaction is the product.
