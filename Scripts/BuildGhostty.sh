#!/bin/bash
# Build the official pinned embedding library; run once before opening Relay.xcodeproj.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
zig_bin="${ZIG:-zig}"
if [[ "$("$zig_bin" version)" != "0.14.1" ]]; then
    echo 'Ghostty 1.2.3 requires Zig 0.14.1. Set ZIG to that compiler’s path.' >&2
    exit 1
fi
build_root="${RELAY_GHOSTTY_BUILD_DIR:-$repo_root/.build/ghostty}"
mkdir -p "$build_root"
cache_dir="$build_root/zig-cache"

# Zig 0.14.1 matches SDK stub targets literally, and the Xcode 26.4 SDK renamed the
# arm64-macos entries that carry libSystem's symbols to arm64e-macos, so linking against it
# fails with every libc symbol undefined (ziglang/zig#31658, fixed only in Zig 0.16). Nothing
# in the stubs reliably advertises this, so ask Zig directly: link a trivial program, which
# pulls in libSystem exactly as Ghostty's build does, and keep the newest toolchain that works.
# An SDKROOT inherited from the environment would outrank the toolchain chosen here.
unset SDKROOT
probe_root="$build_root/sdk-probe"
rm -rf "$probe_root"
mkdir -p "$probe_root"
printf 'pub fn main() void {}\n' > "$probe_root/probe.zig"
links_against() {
    DEVELOPER_DIR="$1" "$zig_bin" build-exe "$probe_root/probe.zig" \
        -femit-bin="$probe_root/probe" --cache-dir "$probe_root/cache" \
        --global-cache-dir "$cache_dir" > "$probe_root/log" 2>&1
}
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    candidates="$DEVELOPER_DIR"
else
    candidates="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -Vr | sed 's|$|/Contents/Developer|')
$(xcode-select -p)"
fi
selected=""
while IFS= read -r candidate; do
    [[ -d "$candidate" ]] || continue
    if links_against "$candidate"; then
        selected="$candidate"
        break
    fi
    echo "Skipping $candidate: Zig 0.14.1 cannot link against its SDK."
done <<< "$candidates"
if [[ -z "$selected" ]]; then
    echo 'No installed Xcode ships an SDK that Zig 0.14.1 can link against; install Xcode 26.3 or older, or set DEVELOPER_DIR to one. The last attempt reported:' >&2
    cat "$probe_root/log" >&2
    exit 1
fi
export DEVELOPER_DIR="$selected"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
rm -rf "$probe_root"
echo "Building libghostty with $DEVELOPER_DIR against $SDKROOT"

archive="$build_root/ghostty-1.2.3.tar.gz"
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 'https://release.files.ghostty.org/1.2.3/ghostty-1.2.3.tar.gz' -o "$archive"
fi
printf '%s  %s\n' '559770fe9773161e93e3dd9177d916e27037d7f548edcf6186eabc571c0e520b' "$archive" | shasum -a 256 -c -
source_root="$build_root/source"
if [[ ! -d "$source_root" ]]; then
    mkdir -p "$source_root"
    tar -xzf "$archive" -C "$source_root" --strip-components=1
fi
cd "$source_root"

# Three of Ghostty's packages are pinned as git+https, and Zig 0.14.1 speaks the git
# smart-HTTP protocol itself rather than shelling out to git. That handshake is what fails on
# GitHub's runners — "unable to discover remote git server capabilities: EndOfStream", every
# run, for the Codeberg-hosted one. The same commits are served as plain tarballs, and a
# tarball fetch hashes identically to the git fetch, so seed the cache over plain HTTPS and
# `zig build` resolves them by hash without ever opening a git connection. A hash that stops
# matching means Ghostty moved a pin and these URLs are stale, so fail loudly rather than
# leaving the build to fetch something unexpected.
git_packages=(
    "vaxis-0.1.0-BWNV_FUICQAFZnTCL11TUvnUr1Y0_ZdqtXHhd51d76Rn https://github.com/rockorager/libvaxis/archive/1f41c121e8fc153d9ce8c6eb64b2bbab68ad7d23.tar.gz"
    "zigimg-0.1.0-lly-O6N2EABOxke8dqyzCwhtUCAafqP35zC7wsZ4Ddxj https://github.com/TUSF/zigimg/archive/31268548fe3276c0e95f318a6c0d2ab10565b58d.tar.gz"
    "zg-0.13.4-AAAAAGiZ7QLz4pvECFa_wG4O4TP4FLABHHbemH2KakWM https://codeberg.org/atman/zg/archive/4a002763419a34d61dcbb1f415821b83b9bf8ddc.tar.gz"
)
for package in "${git_packages[@]}"; do
    read -r expected url <<< "$package"
    [[ -d "$cache_dir/p/$expected" ]] && continue
    for attempt in 1 2 3; do
        if actual="$("$zig_bin" fetch --global-cache-dir "$cache_dir" "$url")"; then
            break
        fi
        actual=""
        (( attempt < 3 )) && sleep $(( attempt * 15 ))
    done
    if [[ -z "$actual" ]]; then
        echo "Could not download $url after 3 attempts." >&2
        exit 1
    fi
    if [[ "$actual" != "$expected" ]]; then
        echo "$url hashed to $actual, but Ghostty 1.2.3 pins $expected." >&2
        echo 'Re-check the git+https pins in build.zig.zon before changing this list.' >&2
        exit 1
    fi
done

# The remaining 32 packages are plain tarballs, but Zig's HTTP client still intermittently
# reuses a pooled connection the server has already closed (ziglang/zig#21316, still open).
# Packages that did land stay in the cache, so a retry resumes instead of starting over.
# Only fetch failures are retried; a compile error is deterministic and should fail at once.
build_log="$build_root/build.log"
attempt=1
attempts=3
while true; do
    if "$zig_bin" build -Doptimize=ReleaseFast -Demit-macos-app=false \
        -Dxcframework-target=native -Demit-docs=false -Demit-themes=false -Di18n=false \
        --global-cache-dir "$cache_dir" 2>&1 | tee "$build_log"; then
        break
    fi
    if ! grep -qE 'unable to (discover remote git server capabilities|fetch)|ConnectionResetByPeer|EndOfStream|TemporaryNameServerFailure|TlsInitializationFailed' "$build_log"; then
        exit 1
    fi
    if (( attempt >= attempts )); then
        echo "Fetching Ghostty's dependencies still failed after $attempts attempts." >&2
        exit 1
    fi
    echo "Attempt $attempt/$attempts failed while fetching dependencies; retrying in $(( attempt * 15 ))s."
    sleep $(( attempt * 15 ))
    attempt=$(( attempt + 1 ))
done
package="$repo_root/Packages/TerminalKit"
mkdir -p "$package/Vendor" "$package/Sources/TerminalKit/Resources"
ditto macos/GhosttyKit.xcframework "$package/Vendor/GhosttyKit.xcframework"
ditto zig-out/share/ghostty "$package/Sources/TerminalKit/Resources/ghostty"
ditto zig-out/share/terminfo "$package/Sources/TerminalKit/Resources/terminfo"
cp LICENSE "$package/Vendor/Ghostty-LICENSE"
echo "Built libghostty 1.2.3 for $(uname -m). Relay.xcodeproj is ready to build."
