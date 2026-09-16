# Relay Product Specification

## Product Summary

Relay is a native macOS terminal workspace built around projects and persistent development sessions.

The product is not intended to be "another terminal with AI features." Its core model is:

**Relay → Workspace → Session → Terminal**

- A **Workspace** represents what the user is working on.
- A **Session** represents a specific shell or coding-agent process running within that workspace.
- The **Terminal** is where the session is displayed and interacted with.

Relay should make it easy to move between multiple ongoing development contexts, especially coding-agent sessions such as Claude Code and GitHub Copilot CLI.

## Product Positioning

**Relay**  
*Your terminal sessions, in motion.*

Relay should feel like a focused, polished macOS utility for software developers rather than a full IDE.

Its differentiators are:

- Workspace-first navigation
- Multiple sessions per workspace
- First-class support for agent-oriented terminal workflows
- Fast switching between ongoing sessions
- Native macOS interaction patterns
- A visually refined Apple-focused interface
- A clean terminal surface powered by libghostty

## Core Concepts

### Workspace

A workspace is Relay's representation of a project or working directory.

A workspace:

- Has a display name
- Points to a directory on disk
- May optionally be a Git repository
- Can contain multiple sessions
- Persists between app launches
- Can be favorited or reordered later
- Does not require Git

Examples:

- `Aquarium Manager` → `~/Developer/aquarium`
- `Relay` → `~/Developer/relay`
- `Work` → `~/Developer/work`
- `Homelab` → `~/homelab`

Git-related information should appear automatically when available, but Git must never be required.

### Session

A session is a terminal context inside a workspace, or a temporary context outside any workspace. Temporary sessions use the user’s home directory and last only for the current app lifetime.

Supported initial session types:

- Claude Code
- GitHub Copilot
- Shell

Each session should track:

- Session type
- Display name
- Workspace
- Working directory
- Creation time
- Activity state
- Process state
- Optional command used to start it

Possible future session states:

- Running
- Idle
- Waiting for input
- Completed
- Disconnected
- Failed

### Terminal

The terminal surface should be powered by `libghostty`.

Relay should avoid reimplementing terminal behavior that belongs in libghostty.

The terminal should remain visually simple and readable even when the surrounding interface uses Liquid Glass and translucent materials.

## Primary User Flow

1. Launch Relay.
2. Select a workspace from the sidebar.
3. View the sessions belonging to that workspace.
4. Start a new Claude, Copilot, or Shell session from the workspace header.
5. Relay starts the session in the selected workspace directory.
6. Switch between sessions using the session cards.
7. Switch between workspaces without losing project context.

## Navigation Model

The left sidebar shows **workspaces and a Temporary Sessions destination**.

It should not show individual sessions or a global session list.

The selected workspace or Temporary Sessions destination controls the main content area.

Recommended structure:

```text
Relay

WORKSPACES

Aquarium Manager
Relay
Work
Homelab
Side Projects

+ Add Workspace

Temporary Sessions

--------------------

TEMPORARY SESSION

Claude    Copilot    Shell
```

Sessions belonging to the selected destination appear in the main content area, not in the sidebar. Workspace headers provide a New Session menu. The bottom-left launchers always create temporary sessions and navigate to Temporary Sessions, without changing the last selected workspace. Temporary sessions survive navigation but are not restored after quitting.

## Product Principles

### Workspace-first

The project is more important than the terminal tab.

### Fast by default

Common actions should require very little UI.

Starting a session should usually be one click.

### Native macOS

Relay should behave like a first-party macOS application whenever possible.

### Terminal, not IDE

Relay may expose useful project metadata, Git information, and agent state, but it should not become a code editor or attempt to replace Xcode, VS Code, or other IDEs.

### Progressive complexity

The default experience should be simple.

Advanced capabilities such as split panes, SSH, session restoration, agent monitoring, or Git tooling can be layered in later.

## Non-Goals for Initial Versions

Relay is not initially intended to be:

- A full IDE
- A source-code editor
- A Git client
- A task tracker
- A project-management application
- A replacement for Claude Code or Copilot
- A custom terminal-rendering engine
