# Using Relay

Relay is a native macOS terminal organized around **workspaces**. A workspace is a project folder. Inside it you run **sessions**: shells and coding agents such as Claude Code or Copilot, each with its own terminal.

```
Workspace  →  Session  →  Terminal
```

## Workspaces

- **Add a workspace** with **Add Workspace** in the sidebar (⇧⌘O) and choose a folder. Adding a folder that is already a workspace selects it instead of adding it again.
- **Reorder workspaces** by dragging them in the sidebar, or with **Move Up** / **Move Down** in a workspace's context menu.
- **Remove a workspace** from its context menu, its ⋯ button, or by pressing ⌫ while it is selected. Relay asks first, and warns you if any of its sessions still have processes running. The folder itself is never touched.
- **Show in Finder** is in the same menu.

Relay remembers your workspaces, their order, each workspace's sessions, and which ones were selected. After a relaunch, sessions come back as entries, but their processes start fresh. Relay does not keep processes running after it quits.

## Sessions

Start a session from the **New Session** menu in a workspace's header. It runs in that workspace's folder.

- **⌘N** starts a new session of the default type (Shell, unless you've disabled it). Every other type is in the **File** menu.
- **Switch sessions** by clicking their cards, with ⌘1–⌘9 for the first nine, or with ⇧⌘[ / ⇧⌘] for the previous/next one.
- **Rename** or **close** a session from its card's context menu. Relay confirms before closing a session that still has a process running.

### Temporary sessions

The launchers at the bottom of the sidebar always start a **temporary session** in your home directory, even while a workspace is selected. Temporary sessions are collected under **Temporary Sessions** in the sidebar. They stay alive while you switch around, but they are not saved: quitting Relay discards them.

Use them for one-off commands that don't belong to a project.

## Getting around

| Action | Shortcut |
| --- | --- |
| Quick Switch to any workspace or session | ⌘P |
| Previous / next workspace | ⌃⌘↑ / ⌃⌘↓ |
| Previous / next session | ⇧⌘[ / ⇧⌘] |
| Jump to session 1–9 | ⌘1 – ⌘9 |
| Focus Terminal (toggle) | ⇧⌘↩ |
| New session (default type) | ⌘N |
| Add Workspace | ⇧⌘O |

**Quick Switch** (⌘P) searches workspaces and sessions together. Each word you type narrows the results, so `relay claude` finds the Claude session in the Relay workspace.

**Terminal Focus** (⇧⌘↩, or the expand button in the terminal's title bar) hides the sidebar, header, and session cards so the terminal gets the whole window. Your sessions appear as compact tabs, and you can still create, close, and switch sessions from there. Esc deliberately does *not* leave focus mode, because Esc belongs to the terminal (vim and other full-screen programs need it).

## In the terminal

| Action | Shortcut |
| --- | --- |
| Clear Screen | ⌘K |
| Search Scrollback | ⌘F |
| Jump to previous / next prompt | ⌘↑ / ⌘↓ |
| Page Up / Page Down | ⌘⇞ / ⌘⇟ |
| Scroll to top / bottom | ⌘↖ / ⌘↘ |
| Bigger / smaller / actual-size text | ⌘+ / ⌘- / ⌘0 |

- **Search Scrollback** lists the lines that match your search, and you can copy any of them. Matches aren't highlighted in the terminal itself yet.
- **Drop files** onto a terminal to insert their paths, shell-escaped. You can also drop an image with no file behind it, such as a screenshot thumbnail or an image from a browser. Relay saves it and inserts the path to the saved file, so agents like Claude Code can pick it up.

## Settings (⌘,)

### Terminal

Choose the font (monospaced fonts only) and the text size. Changes apply to open terminals immediately.

### Colors

Pick one color scheme for light mode and one for dark mode. Terminals switch along with the system appearance.

- Built-in schemes include Catppuccin, Dracula, Gruvbox, Nord, Solarized and Tokyo Night.
- **Import** iTerm2 (`.itermcolors`), Terminal (`.terminal`) or Ghostty theme files, or drop them on the list.
- **Export** writes iTerm2 or Ghostty files.
- Built-in schemes can't be changed, so editing one saves a copy.

### Session Types

Session types are the kinds of sessions you can start. Relay ships with Claude, Copilot, Codex and Shell. You can add more from a catalog (Gemini, Aider, Cursor, opencode, `gh copilot`) or define your own: a name, a command, an icon and a color.

- An empty command starts your login shell. Shell is the one type that can't be deleted.
- Disabled types disappear from menus and launchers.
- Drag types to reorder them. The sidebar shows the first few as launchers and puts the rest in a "more" menu.

## Troubleshooting

**"Relay couldn't find `claude` on your login shell's PATH."**
Relay looks commands up using the PATH from an interactive login shell, so anything you add to PATH in `.zprofile` or `.zshrc` counts. If you still see this:

1. Check that `which claude` (or the relevant command) works in a new Terminal window.
2. If the CLI lives somewhere unusual, set its full path in **Settings ▸ Session Types**.

**Something else is wrong.**
Open **Help ▸ Diagnostics…** and copy the report. It includes the PATH Relay sees and the state of each session, which is the most useful thing to send with a bug report.
