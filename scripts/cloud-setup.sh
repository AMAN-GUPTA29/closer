#!/usr/bin/env bash
# Installs the pinned Flutter SDK in Claude Code cloud sessions (Ubuntu 24.04 x86_64).
# Runs from the SessionStart hook in .claude/settings.json; a no-op on local machines.
# It can also be pasted into the cloud environment's "Setup script" field so the
# install is cached across sessions (see docs/remote-development.md).
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.47.4"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION into $FLUTTER_HOME"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  tar -xf "$tmp/flutter.tar.xz" -C "$(dirname "$FLUTTER_HOME")"
  rm -rf "$tmp"
  git config --global --add safe.directory "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true

# Make flutter/dart available to the Claude session's later shell commands.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

if [ -f "${CLAUDE_PROJECT_DIR:-.}/pubspec.yaml" ]; then
  (cd "${CLAUDE_PROJECT_DIR:-.}" && flutter pub get) || echo "flutter pub get failed; continuing"
fi
