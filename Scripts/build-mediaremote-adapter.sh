#!/bin/bash
# Builds ungive/mediaremote-adapter — the workaround real boring-notch uses
# for the entitlement lockdown Apple added to MediaRemote.framework around
# macOS 15.4 (a system-trusted /usr/bin/perl process loads a helper
# framework and prints now-playing updates as JSON to stdout, since perl
# itself carries the entitlement third-party binaries don't get).
#
# Non-fatal by design: Now Playing gracefully falls back to the older
# direct-dlopen approach (which may or may not work depending on macOS
# version) if this can't build — a missing/failed build here shouldn't
# break the rest of the app.
set -uo pipefail

RESOURCES_DIR="${1:?usage: build-mediaremote-adapter.sh <Resources dir>}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Cloning ungive/mediaremote-adapter"
if ! git clone --depth 1 --recurse-submodules \
    https://github.com/ungive/mediaremote-adapter.git "$WORK_DIR/src" 2>&1; then
    echo "warning: could not clone mediaremote-adapter — Now Playing will fall back to the direct approach"
    exit 0
fi

echo "==> Building via CMake"
if ! cmake -S "$WORK_DIR/src" -B "$WORK_DIR/src/build" >/dev/null 2>&1 || \
   ! cmake --build "$WORK_DIR/src/build" 2>&1; then
    echo "warning: mediaremote-adapter build failed — Now Playing will fall back to the direct approach"
    exit 0
fi

FRAMEWORK="$WORK_DIR/src/build/MediaRemoteAdapter.framework"
SCRIPT="$WORK_DIR/src/bin/mediaremote-adapter.pl"
if [ ! -d "$FRAMEWORK" ] || [ ! -f "$SCRIPT" ]; then
    echo "warning: mediaremote-adapter build didn't produce expected output — skipping"
    exit 0
fi

echo "==> Staging into $RESOURCES_DIR/MediaRemoteAdapter"
mkdir -p "$RESOURCES_DIR/MediaRemoteAdapter"
cp -R "$FRAMEWORK" "$RESOURCES_DIR/MediaRemoteAdapter/"
cp "$SCRIPT" "$RESOURCES_DIR/MediaRemoteAdapter/"

echo "==> mediaremote-adapter staged successfully"
