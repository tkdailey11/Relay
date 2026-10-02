# Relay

A native macOS terminal built for switching between workspaces and sessions. See `Docs/USAGE.md`
for what it does and `Docs/ARCHITECTURE.md` for how it is put together.

## Building

Relay needs Xcode 26 or newer, and Zig 0.14.1 to build libghostty once:

```sh
Scripts/BuildGhostty.sh
open Relay.xcodeproj
```

## License

Relay is released under the [MIT License](LICENSE).

Relay's terminal is [libghostty](https://github.com/ghostty-org/ghostty), the engine behind the
Ghostty terminal, built unmodified from the official 1.2.3 release. Thank you to Mitchell Hashimoto
and the Ghostty contributors. Relay is an independent project and is not affiliated with or
endorsed by Ghostty. The licenses of libghostty and the libraries inside it are in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
