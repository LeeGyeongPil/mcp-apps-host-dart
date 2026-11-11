#!/bin/sh
# Runs every check of both packages: pub get, analyze, test.
# Needs the Dart SDK and Flutter (CI pins Flutter 3.32.4). No keys, no network
# beyond `pub get`.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== mcp_apps_host (pure Dart) =="
cd "$ROOT/packages/mcp_apps_host"
dart pub get
dart analyze
dart test

echo "== mcp_apps_host_flutter (widget tests, no real WebView) =="
cd "$ROOT/packages/mcp_apps_host_flutter"
flutter pub get
flutter analyze
flutter test
