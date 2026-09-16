# Relay Architecture

## Overview

Relay is a native macOS application built around a small set of explicit domain concepts:

- Workspace
- Session
- Terminal

The architecture should keep terminal integration isolated so Relay can evolve independently from changes in libghostty.

## Recommended Technology

### Application UI

- Swift
- SwiftUI
- AppKit where required for windowing, terminal hosting, or lower-level macOS integration

### Terminal

- `libghostty`

Create a thin internal wrapper around libghostty rather than exposing libghostty directly throughout the application.

Suggested module name:

`TerminalKit`

## High-Level Structure

```text
Relay
├── App
│   ├── RelayApp
│   ├── AppState
│   └── Commands
│
├── Models
│   ├── Workspace
│   ├── Session
│   └── SessionType
│
├── Features
│   ├── Workspaces
│   ├── Sessions
│   └── Settings
│
├── TerminalKit
│   ├── GhosttyHost
│   ├── TerminalSession
│   └── ProcessIntegration
│
├── Services
│   ├── WorkspaceStore
│   ├── SessionManager
│   ├── ProcessLauncher
│   └── GitService
│
└── Resources
```

The exact folder structure may evolve, but dependencies should remain directional and simple.

## Domain Models

### Workspace

Possible initial shape:

```swift
struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var directoryURL: URL
    var createdAt: Date
    var isFavorite: Bool
}
```

Future additions may include:

- Custom icon
- Color
- Sort order
- Default session type
- Workspace-specific environment
- Workspace settings

Do not require Git metadata to be stored directly on the Workspace model.

Git should be discovered dynamically.

### SessionType

Initial cases:

```swift
enum SessionType: String, Codable {
    case shell
    case claude
    case copilot
}
```

Future session types should be easy to add.

### Session

Conceptual shape:

```swift
struct Session: Identifiable {
    let id: UUID
    let workspaceID: Workspace.ID
    let type: SessionType
    var title: String
    var createdAt: Date
    var state: SessionState
}
```

Avoid putting libghostty-specific implementation details directly into the domain model.

## TerminalKit

`TerminalKit` should isolate all libghostty integration.

Responsibilities may include:

- Creating a terminal instance
- Hosting the terminal view
- Launching a PTY / child process
- Resizing
- Keyboard input
- Clipboard behavior
- Terminal configuration
- Terminal teardown

Relay application code should interact with a stable Swift-facing abstraction.

Example conceptual API:

```swift
final class TerminalSessionController {
    func start(command: SessionCommand, workingDirectory: URL)
    func resize(to size: CGSize)
    func focus()
    func terminate()
}
```

This is illustrative only.

Follow the actual libghostty API rather than forcing this exact interface.

## Process Launching

Session types should map to commands.

Examples:

```text
Shell
→ user's configured shell

Claude
→ claude

Copilot
→ gh copilot
```

The exact Copilot command should be configurable because CLI behavior may change.

Do not hard-code assumptions that are difficult to migrate.

## Workspace Store

The workspace store should persist:

- Workspace IDs
- Names
- Directory URLs
- Order
- Favorites

Use simple local persistence for the MVP.

Good initial options:

- Codable + Application Support
- SwiftData if it remains simple and justified

Avoid introducing a database unless Relay actually needs one.

## Session Manager

The Session Manager owns active session lifecycle.

Responsibilities:

- Create session
- Close session
- Track active session
- Associate sessions with a workspace or the temporary-session collection
- Expose session state to SwiftUI
- Restore metadata later if persistence is added

Persist workspace session metadata and selections locally. Keep temporary sessions and their selection outside the persisted snapshot; their working directory is the user’s home directory. They survive navigation during the app lifetime but disappear on quit. The initial release does not need process persistence across full application termination.

## Git Integration

Git is optional enhancement data.

Possible responsibilities:

- Detect repository
- Read current branch
- Read dirty/clean state
- Provide lightweight status metadata

Do not build a Git client.

Prefer invoking Git or a small Git abstraction rather than implementing Git behavior directly.

## App State

Relay should have a clear selected-state model:

- Selected destination (workspace or Temporary Sessions)
- Last selected workspace, retained when visiting Temporary Sessions
- Selected session
- Open sessions grouped by workspace
- An in-memory temporary-session collection and independent selected temporary session

Example conceptual hierarchy:

```text
AppState
├── workspaces
├── selectedWorkspaceID
├── sessionsByWorkspace
└── selectedSessionByWorkspace
```

Preserve the selected session independently for each workspace when practical.

That allows this experience:

1. Select Aquarium Manager.
2. Claude session is active.
3. Switch to Relay workspace.
4. Shell session is active.
5. Switch back.
6. Aquarium Manager returns to its Claude session.

## UI Architecture

SwiftUI should manage most product UI.

AppKit may be used for:

- Terminal embedding
- Advanced focus behavior
- Window integration
- Platform APIs not comfortably exposed by SwiftUI

Avoid forcing the terminal renderer into a pure SwiftUI implementation if an AppKit host is more appropriate.

## Separation of Concerns

Important boundary:

```text
Product UI
    ↓
Session Manager
    ↓
TerminalKit
    ↓
libghostty
```

The rest of Relay should not know how libghostty works internally.

## Future Architecture Considerations

Not required for MVP:

- Persistent session daemon
- tmux-style session survival
- Remote sessions
- SSH
- Split panes
- Agent status parsers
- Notifications when an agent needs input
- Workspace command presets
- Plugin architecture
- Cloud sync

Design interfaces so these remain possible, but do not build them early.
