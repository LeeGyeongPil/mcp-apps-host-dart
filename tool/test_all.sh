#!/bin/sh
# Runs every check of both packages and the example app: pub get, analyze, test.
# Needs the Dart SDK and Flutter (CI pins Flutter 3.32.4). No keys, no network
# beyond `pub get` (set PUB_GET_FLAGS=--offline to use the pub cache only).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== mcp_apps_host (pure Dart) =="
cd "$ROOT/packages/mcp_apps_host"
dart pub get $PUB_GET_FLAGS
dart analyze
dart test

echo "== mcp_apps_host_flutter (widget tests, no real WebView) =="
cd "$ROOT/packages/mcp_apps_host_flutter"
flutter pub get $PUB_GET_FLAGS
flutter analyze
flutter test

echo "== example app (analyze + widget test) =="
cd "$ROOT/packages/mcp_apps_host_flutter/example"
flutter pub get $PUB_GET_FLAGS
flutter analyze
flutter test
