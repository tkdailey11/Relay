# Releasing Relay

Relay is distributed outside the App Store, so every build a tester installs must be signed with
a Developer ID certificate and notarized by Apple. An unnotarized build is refused by Gatekeeper
with a message that reads like corruption, so this is not optional.

`Scripts/Release.sh` is the single source of truth. CI runs the same script with the same
arguments a person would, which keeps releases reproducible from a laptop when Actions is
unavailable and makes notarization failures debuggable interactively.

## Versioning

`VERSION` at the repository root holds the marketing version (`0.1.0`). The build number is the
commit count, so it increases with every build a tester can install and never needs to be
maintained by hand. Both are passed to `xcodebuild` at archive time; the values checked into
`project.pbxproj` only apply to local Xcode builds.

The standard About panel shows both, so a tester reporting a bug can read off the exact build.

## One-time setup

### 1. Developer ID certificate

The account currently has only *Apple Development* certificates, which cannot be notarized.
At [developer.apple.com](https://developer.apple.com/account/resources/certificates/list),
create a **Developer ID Application** certificate and install it. Confirm with:

```sh
security find-identity -v -p codesigning | grep "Developer ID Application"
```

### 2. App Store Connect API key

Notarization authenticates with an API key rather than an app-specific password, which is what
lets CI run unattended. In App Store Connect → Users and Access → Integrations, create a key with
the **Developer** role and download the `.p8` once — it cannot be downloaded again.

For local releases, store it in the keychain and skip the environment variables:

```sh
xcrun notarytool store-credentials Relay \
    --key ~/private_keys/AuthKey_XXXXXXXX.p8 --key-id XXXXXXXX --issuer <issuer-uuid>
```

### 3. GitHub secrets

For the workflow, add these under Settings → Secrets and variables → Actions:

| Secret | What it is |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | The Developer ID Application `.p12`, `base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | The password set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any string; it protects the throwaway CI keychain |
| `AC_API_KEY_BASE64` | The `.p8`, base64 encoded |
| `AC_API_KEY_ID` | The key id, e.g. `XXXXXXXX` |
| `AC_API_ISSUER_ID` | The issuer UUID from App Store Connect |

## Cutting a release

Locally:

```sh
AC_KEYCHAIN_PROFILE=Relay Scripts/Release.sh
```

Through GitHub Actions, either push a tag matching `VERSION`:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

or run the **Release** workflow manually, which produces a draft release tagged with the build
number. Both paths upload a notarized, stapled `Relay-<version>.zip`.

## Architecture

`Scripts/BuildGhostty.sh` vendors libghostty for the host architecture only, so releases are
Apple Silicon only. To ship a universal app, build Ghostty with `-Dxcframework-target=universal`
and drop the `ARCHS=arm64` override in `Scripts/Release.sh`. macOS 26 still runs on some Intel
Macs, so this matters if any tester is on one.

## Toolchain

Relay itself builds with the newest installed Xcode, but libghostty does not. Zig 0.14.1, which
Ghostty 1.2.3 pins, matches SDK stub targets literally, and the Xcode 26.4 SDK renamed its
`arm64-macos` entries to `arm64e-macos`; linking against it fails with every libSystem symbol
undefined ([ziglang/zig#31658](https://codeberg.org/ziglang/zig/issues/31658), fixed only in Zig
0.16). The stubs do not reliably advertise this, so `Scripts/BuildGhostty.sh` asks Zig instead:
it links a trivial program against each installed Xcode, newest first, and exports the first one
that succeeds — Xcode 26.3 or older — as `DEVELOPER_DIR` for that step alone. Set `DEVELOPER_DIR`
yourself to override the choice; the script still probes it and fails loudly if it cannot link.
Once Ghostty moves to Zig 0.16 or newer, the whole block can go.

## Entitlements

`Relay/Relay.entitlements` declares the TCC keys Ghostty declares, for the same reason: Relay
runs under the hardened runtime, and without them a program a user runs inside a Relay terminal
is denied access to Contacts, Calendars, the microphone or AppleEvents silently, rather than
prompting. They grant Relay nothing by themselves.

## Getting a useful bug report back

Ask testers to open **Help ▸ Diagnostics…**, press Copy, and paste the result into the report.
It names the exact build, the macOS version and architecture, whether each CLI resolved and to
what path, every session's terminal status, and a timestamped log of what Relay did this run.
Nothing is transmitted; the sheet exists so the tester can read what they are sharing first.

For anything the in-app report cannot explain, Relay also logs to the unified log:

```sh
log stream --predicate 'subsystem == "com.tylerdailey.Relay"' --level debug
```

## Settings

Terminal font family and size live in **Relay ▸ Settings ▸ Terminal** and apply to open terminals
immediately. ⌘+, ⌘− and ⌘0 in the View menu move the same preference, so every terminal agrees
with Settings and the change survives a relaunch.

**Settings ▸ Session Types** is the list of things a user can start. Relay ships Claude, Copilot,
Codex and Shell as presets, and the Add menu offers more from a catalog (Gemini, Aider, Cursor,
opencode, Copilot via `gh`) or a custom type with its own name, command, icon and color. Every
row is editable, so a tester whose CLI Relay cannot find fixes it with a full path.

Two behaviours worth knowing:

- **Shell cannot be removed.** Relay is a terminal; the empty state and ⌘N both start a login
  shell, so that one type is pinned. Everything else, presets included, can be removed.
- **Removing a type leaves its sessions alone.** A running terminal keeps running and its card
  keeps the name it was started under, with a generic icon. Starting a *new* session of a removed
  type is what reports the type is gone.

⌘N starts the default type, which is Shell unless it has been disabled. The other types stay in
the File menu without shortcuts, since the list is user editable and bound keys would move
underneath people as they reorder it.

0.1's `defaults write com.tylerdailey.Relay "RelayCommand.Copilot" "gh copilot"` overrides are
migrated onto their presets on first launch. 0.1 also tried `copilot` then `gh copilot`
automatically; that hidden fallback is now the "Copilot (gh)" catalog entry instead.

## Terminal shortcuts

`relay.conf` sets `keybind = clear`, so libghostty contributes no shortcuts of its own and the
menu bar owns every Command key. The Terminal menu puts back the ones worth having: Clear Screen
(⌘K), Search Scrollback (⌘F), jump to previous/next prompt (⌘↑/⌘↓), page up/down and scroll to
top/bottom. ⌘N makes a new Shell session, since Relay is a single-window app and New Window has
nothing to do.

**Search Scrollback is not find-in-terminal.** libghostty 1.2.3 exposes no search, and no way to
set a selection or scroll to a match, so Relay reads the scrollback text out and lists the lines
that match. It cannot highlight a hit in place or scroll the terminal to it. Revisit this when
libghostty gains a search API.

## Verifying a build before sending it out

```sh
spctl --assess --type execute --verbose=4 /path/to/Relay.app   # expect "accepted, source=Notarized Developer ID"
xcrun stapler validate /path/to/Relay.app
```

The most honest check is to download the zip on a Mac that has never seen the source and
double-click it.
