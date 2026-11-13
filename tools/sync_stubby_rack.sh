#!/usr/bin/env bash
# Vendor stubby-rack's built addon into res://addons/stubby_rack/ (design D11 of
# add-rack-audio-engine, task 2.6). Builds the debug and release libraries for this
# platform from a clean stubby-rack checkout, copies the addon, pins the commit in
# addons/stubby_rack/VERSION, and imports twice (the first clean headless import
# with a GDExtension aborts on the Godot 4.8 beta, task 2.5).
#
#   tools/sync_stubby_rack.sh [path/to/stubby-rack]     (default: ../stubby-rack)
#   SKIP_BUILD=1 tools/sync_stubby_rack.sh               copy what is already built
#
# Other platforms' binaries come from stubby-rack's CI artifacts: unpack them into
# <stubby-rack>/demo/addons/stubby_rack/bin/ first, then run with SKIP_BUILD=1.
set -euo pipefail

game="$(cd "$(dirname "$0")/.." && pwd)"
rack="$(cd "${1:-$game/../stubby-rack}" && pwd)"
src="$rack/demo/addons/stubby_rack"
dst="$game/addons/stubby_rack"

if [[ -n "$(git -C "$rack" status --porcelain --untracked-files=no)" ]]; then
    echo "stubby-rack has uncommitted changes; commit them so VERSION names what was built" >&2
    exit 1
fi
commit="$(git -C "$rack" rev-parse HEAD)"

if [[ -z "${SKIP_BUILD:-}" ]]; then
    jobs="$(nproc)"
    (cd "$rack" && scons -j"$jobs" target=template_debug && scons -j"$jobs" target=template_release && scons tests)
fi

shopt -s nullglob
libs=("$src"/bin/*)
if [[ ${#libs[@]} -eq 0 ]]; then
    echo "no binaries in $src/bin" >&2
    exit 1
fi

rm -rf "$dst"
mkdir -p "$dst/bin"
cp "$src/stubby_rack.gdextension" "$dst/"
[[ -f "$src/stubby_rack.gdextension.uid" ]] && cp "$src/stubby_rack.gdextension.uid" "$dst/"
cp "${libs[@]}" "$dst/bin/"
cp "$rack/LICENSE" "$dst/LICENSE"
cp "$rack/THIRDPARTY.md" "$dst/THIRDPARTY.md"
{
    echo "stubby-rack $commit"
    echo "source https://github.com/buddha314/stubby-rack/commit/$commit"
    echo "synced $(date -u +%Y-%m-%d) by tools/sync_stubby_rack.sh"
} > "$dst/VERSION"

echo "vendored stubby-rack ${commit:0:7}: $(ls "$dst/bin" | tr '\n' ' ')"
cd "$game"
saved="$(mktemp)"
cp project.godot "$saved"  # --import rewrites project.godot's formatting: put it back as it was
godot --headless --path . --import >/dev/null 2>&1 || echo "first import exited $? (known 4.8 beta abort with GDExtensions; importing again)"
godot --headless --path . --import >/dev/null 2>&1
cp "$saved" project.godot
rm -f "$saved"
echo "imported"
