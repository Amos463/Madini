#!/usr/bin/env bash
set -euo pipefail

echo "MADINI preflight — this does NOT create a signed store release."
command -v flutter >/dev/null || { echo "ERROR: Flutter SDK is missing."; exit 2; }
command -v java >/dev/null || { echo "ERROR: Java is missing."; exit 2; }

flutter --version
java -version
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
# Web build is intentionally NOT run: sqflite_sqlcipher and flutter_secure_storage are mobile-only.

if command -v gradle >/dev/null 2>&1; then
  gradle -p android wrapper --gradle-version 8.12
  flutter build apk --debug
else
  echo "NOTICE: Gradle CLI is missing; Android APK build skipped."
  echo "Use the included GitHub Actions workflow or install 8.12."
fi

echo "Preflight completed. This is not proof of production readiness."
