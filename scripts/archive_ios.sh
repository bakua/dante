#!/usr/bin/env bash
# ============================================================================
# archive_ios.sh — Build, archive, and export DANTE TERMINAL for App Store
#
# Wraps Flutter build + xcodebuild archive + xcodebuild -exportArchive into
# a single script with error handling. Produces a signed .ipa ready for
# TestFlight or App Store submission.
#
# Prerequisites:
#   - Xcode installed with command-line tools
#   - Valid Apple Developer signing identity + provisioning profile
#   - Flutter SDK on PATH
#
# Usage:
#   ./scripts/archive_ios.sh --team-id ABCDE12345 --profile "MyApp Distribution"
#   ./scripts/archive_ios.sh --team-id ABCDE12345 --profile "MyApp Distribution" --build-number 2
#
# Options:
#   --team-id       Apple Developer Team ID (required, 10-char alphanumeric)
#   --profile       Provisioning profile name (required)
#   --build-name    Version string, e.g. 1.0.0 (default: from pubspec.yaml)
#   --build-number  Integer build number (default: from pubspec.yaml)
#   --output-dir    Directory for .ipa output (default: build/ios/ipa)
#   --help          Show this help message
# ============================================================================
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
SCHEME="Runner"
WORKSPACE_REL="ios/Runner.xcworkspace"
EXPORT_OPTIONS_REL="ios/ExportOptions.plist"
BUNDLE_ID="com.danteterminal.danteTerminal"

# ── Defaults ─────────────────────────────────────────────────────────────────
TEAM_ID=""
PROFILE_NAME=""
BUILD_NAME=""
BUILD_NUMBER=""
OUTPUT_DIR=""

# ── Parse arguments ──────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 --team-id TEAM_ID --profile PROFILE_NAME [options]"
  echo ""
  echo "Required:"
  echo "  --team-id       Apple Developer Team ID (10-char alphanumeric)"
  echo "  --profile       Provisioning profile name for App Store distribution"
  echo ""
  echo "Optional:"
  echo "  --build-name    Version string, e.g. 1.0.0 (default: from pubspec.yaml)"
  echo "  --build-number  Integer build number (default: from pubspec.yaml)"
  echo "  --output-dir    Directory for .ipa output (default: build/ios/ipa)"
  echo "  --help          Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --team-id ABCDE12345 --profile 'DANTE TERMINAL Distribution'"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      TEAM_ID="$2"
      shift 2
      ;;
    --profile)
      PROFILE_NAME="$2"
      shift 2
      ;;
    --build-name)
      BUILD_NAME="$2"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

# ── Validate required arguments ──────────────────────────────────────────────
if [ -z "$TEAM_ID" ]; then
  echo "ERROR: --team-id is required."
  echo "  Find your Team ID at: https://developer.apple.com/account → Membership Details"
  usage
  exit 1
fi

if [ -z "$PROFILE_NAME" ]; then
  echo "ERROR: --profile is required."
  echo "  Create a provisioning profile at: https://developer.apple.com/account/resources/profiles"
  usage
  exit 1
fi

if ! [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "ERROR: Team ID must be exactly 10 alphanumeric characters. Got: '$TEAM_ID'"
  exit 1
fi

# ── Resolve paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/dante_terminal"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "ERROR: Flutter project directory not found at $PROJECT_DIR"
  exit 1
fi

cd "$PROJECT_DIR"

WORKSPACE="$PROJECT_DIR/$WORKSPACE_REL"
EXPORT_OPTIONS_TEMPLATE="$PROJECT_DIR/$EXPORT_OPTIONS_REL"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/DanteTerminal.xcarchive"

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$PROJECT_DIR/build/ios/ipa"
fi

if [ ! -f "$EXPORT_OPTIONS_TEMPLATE" ]; then
  echo "ERROR: ExportOptions.plist not found at $EXPORT_OPTIONS_TEMPLATE"
  exit 1
fi

if [ ! -d "$WORKSPACE" ]; then
  echo "ERROR: Xcode workspace not found at $WORKSPACE"
  echo "  Run 'flutter build ios' first to generate the workspace."
  exit 1
fi

# ── Prepare ExportOptions.plist with real values ─────────────────────────────
EXPORT_OPTIONS_RESOLVED="$PROJECT_DIR/build/ios/ExportOptions-resolved.plist"
mkdir -p "$(dirname "$EXPORT_OPTIONS_RESOLVED")"

echo "  Preparing ExportOptions.plist..."
sed \
  -e "s/TEAM_ID_PLACEHOLDER/$TEAM_ID/g" \
  -e "s/PROVISIONING_PROFILE_PLACEHOLDER/$PROFILE_NAME/g" \
  "$EXPORT_OPTIONS_TEMPLATE" > "$EXPORT_OPTIONS_RESOLVED"

echo "  Team ID:     $TEAM_ID"
echo "  Profile:     $PROFILE_NAME"
echo "  Bundle ID:   $BUNDLE_ID"

# ── Step 1: Flutter build (generates Xcode project with release config) ──────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 1/3: Flutter build ios --release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FLUTTER_BUILD_ARGS=(flutter build ios --release --no-codesign)
if [ -n "$BUILD_NAME" ]; then
  FLUTTER_BUILD_ARGS+=(--build-name "$BUILD_NAME")
fi
if [ -n "$BUILD_NUMBER" ]; then
  FLUTTER_BUILD_ARGS+=(--build-number "$BUILD_NUMBER")
fi

echo "  CMD: ${FLUTTER_BUILD_ARGS[*]}"
"${FLUTTER_BUILD_ARGS[@]}"
echo "  >> Flutter build: DONE"

# ── Step 2: xcodebuild archive ───────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 2/3: xcodebuild archive"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean previous archive if it exists
if [ -d "$ARCHIVE_PATH" ]; then
  echo "  Removing previous archive..."
  rm -rf "$ARCHIVE_PATH"
fi

echo "  CMD: xcodebuild archive -workspace ... -scheme $SCHEME -archivePath ..."
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE="Manual" \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
  | tail -20

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo ""
  echo "ERROR: Archive failed — $ARCHIVE_PATH was not created."
  echo "  Common causes:"
  echo "  - Invalid Team ID or provisioning profile"
  echo "  - Missing signing certificate in Keychain"
  echo "  - Bundle ID mismatch (expected: $BUNDLE_ID)"
  exit 1
fi

echo "  >> xcodebuild archive: DONE"
echo "  Archive: $ARCHIVE_PATH"

# ── Step 3: xcodebuild -exportArchive ────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  STEP 3/3: xcodebuild -exportArchive"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "$OUTPUT_DIR"

echo "  CMD: xcodebuild -exportArchive -archivePath ... -exportPath $OUTPUT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_RESOLVED" \
  -exportPath "$OUTPUT_DIR" \
  | tail -10

# Verify .ipa was produced
IPA_FILE=$(find "$OUTPUT_DIR" -name "*.ipa" -maxdepth 1 | head -1)

if [ -z "$IPA_FILE" ]; then
  echo ""
  echo "ERROR: Export failed — no .ipa file found in $OUTPUT_DIR"
  echo "  Common causes:"
  echo "  - Provisioning profile does not match bundle ID ($BUNDLE_ID)"
  echo "  - Profile is not for App Store distribution"
  echo "  - Certificate associated with profile is not in Keychain"
  exit 1
fi

# ── Summary ──────────────────────────────────────────────────────────────────
IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                     iOS ARCHIVE & EXPORT COMPLETE                      ║"
echo "╠══════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                        ║"
printf "║  IPA:       %-56s  ║\n" "$IPA_FILE"
printf "║  Size:      %-56s  ║\n" "$IPA_SIZE"
printf "║  Bundle ID: %-56s  ║\n" "$BUNDLE_ID"
printf "║  Team ID:   %-56s  ║\n" "$TEAM_ID"
echo "║                                                                        ║"
echo "║  Next steps:                                                           ║"
echo "║  1. Validate:  xcrun altool --validate-app -f \"$IPA_FILE\" ...          ║"
echo "║  2. Upload:    xcrun altool --upload-app -f \"$IPA_FILE\" ...            ║"
echo "║     or: Open Xcode > Window > Organizer > Distribute App               ║"
echo "║                                                                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
