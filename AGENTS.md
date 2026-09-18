# Repository Guidelines

## Specification & Scope

Read all files in `Docs/` before implementation. They define Relay’s current product, design, architecture, and MVP specification. `Docs/MVP.md` controls scope; do not implement roadmap features unless explicitly requested. Prioritize excellent workspace/session switching, stability, and native macOS behavior.

## Project Structure & Module Organization

- `Relay/`: SwiftUI application source; `RelayApp.swift` is the entry point and `ContentView.swift` currently contains the starter UI.
- `Relay/Assets.xcassets/`: app icon, accent color, and image assets.
- `RelayTests/`: unit tests using Swift Testing.
- `RelayUITests/`: XCTest UI and launch tests.
- `Relay.xcodeproj/`: Xcode project and build configuration.
- `Docs/`: authoritative specifications and future roadmap.

As features develop, follow the proposed `App`, `Models`, `Features`, `Services`, and `TerminalKit` organization in `Docs/ARCHITECTURE.md`. These layers are planned, not yet implemented. Keep libghostty behind a thin Swift-facing `TerminalKit` wrapper; domain models and product UI must not depend on its internals.

## Build, Test, and Development Commands

Use Xcode 26 or newer with the macOS 26 SDK; the current deployment target is macOS 26. Run commands from the repository root:

```sh
open Relay.xcodeproj
xcodebuild -project Relay.xcodeproj -scheme Relay -configuration Debug build
xcodebuild -project Relay.xcodeproj -scheme Relay -destination 'platform=macOS' test
```

These open the project, build the app, and run both test targets. To run locally, select the `Relay` scheme and My Mac in Xcode, then press Command-R. Use SwiftUI previews for focused UI iteration. To cut a signed, notarized build for testers, run `Scripts/Release.sh`; `Docs/RELEASING.md` covers the certificates and secrets it needs.

## Coding Style & Naming Conventions

Match existing Swift code: four-space indentation, same-line opening braces, `UpperCamelCase` types, and `lowerCamelCase` properties and functions. Name files after their primary type, such as `WorkspaceStore.swift`. Prefer SwiftUI, using AppKit where platform integration requires it. Respect the app target’s default MainActor isolation. No formatter or linter is configured.

## Testing Guidelines

Use `@Test` and `#expect` for unit tests; use `XCTestCase` and `test...` methods for UI tests. Name tests for observable behavior, such as `testWorkspaceSelection`. Cover persistence and session lifecycle as implemented. Existing tests are scaffolding; no coverage threshold is configured. For UI changes, verify dark/light appearance and keyboard focus manually.

## Commit & Pull Request Guidelines

History contains only `Initial Commit`, so no established commit convention exists. Use concise, imperative subjects, such as `Add workspace persistence`. Keep changes focused. PRs should describe behavior, identify the relevant MVP milestone, link related issues when applicable, and report validation results. Include screenshots for visual changes.
