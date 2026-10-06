#!/usr/bin/env bash
set -euo pipefail

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get

# Usage analytics (lib/core/telemetry/telemetry.dart): on only when BOTH build
# variables are set, ET_APP_ID (paintshop_app) and ET_WRITE_KEY. Either one
# missing: no define is passed and the app sends nothing, exactly as before.
# ET_BASE_URL is optional (events go to the API host by default). Never echo
# the key.
DART_DEFINES=()
if [ -n "${ET_APP_ID:-}" ] && [ -n "${ET_WRITE_KEY:-}" ]; then
  DART_DEFINES+=(--dart-define=ET_APP_ID="${ET_APP_ID}" --dart-define=ET_WRITE_KEY="${ET_WRITE_KEY}")
  if [ -n "${ET_BASE_URL:-}" ]; then
    DART_DEFINES+=(--dart-define=ET_BASE_URL="${ET_BASE_URL}")
  fi
  echo ">> Usage analytics on, as ${ET_APP_ID}"
else
  echo ">> Usage analytics off (ET_APP_ID / ET_WRITE_KEY not set)"
fi

flutter build web --release "${DART_DEFINES[@]+"${DART_DEFINES[@]}"}"
