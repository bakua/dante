#!/usr/bin/env bash
# generate_keystore.sh — Generate an Android release keystore for DANTE TERMINAL
#
# This script wraps the `keytool` command to generate a release signing keystore.
# The keystore is required for uploading signed AABs to Google Play.
#
# IMPORTANT:
#   - The generated .jks file must be stored SECURELY and NEVER committed to git.
#   - Back up both the .jks file AND your passwords — if you lose the keystore,
#     you can NEVER update the app on Google Play.
#   - The android/.gitignore already excludes key.properties and *.jks files.
#
# Usage:
#   ./scripts/generate_keystore.sh [OPTIONS]
#
# Options:
#   --output PATH     Output keystore path (default: ~/dante-release-key.jks)
#   --alias NAME      Key alias (default: dante-release)
#   --validity DAYS   Validity in days (default: 10000 ≈ 27 years)
#   --help            Show this help message
#
# After running this script:
#   1. Copy dante_terminal/android/key.properties.template to
#      dante_terminal/android/key.properties
#   2. Fill in the passwords and keystore path in key.properties
#   3. Run: flutter build appbundle --release
#
# See also: BL-195 handoff checklist (H5) for full context.

set -euo pipefail

# Defaults
OUTPUT="$HOME/dante-release-key.jks"
ALIAS="dante-release"
VALIDITY=10000
KEY_ALG="RSA"
KEY_SIZE=2048

usage() {
    sed -n '/^# Usage:/,/^# See also:/p' "$0" | sed 's/^# \?//'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --alias)
            ALIAS="$2"
            shift 2
            ;;
        --validity)
            VALIDITY="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Run with --help for usage."
            exit 1
            ;;
    esac
done

# Pre-flight checks
if ! command -v keytool &> /dev/null; then
    echo "Error: keytool not found. Install a JDK (e.g., 'brew install openjdk')."
    exit 1
fi

if [[ -f "$OUTPUT" ]]; then
    echo "Error: Keystore already exists at $OUTPUT"
    echo "Delete it first or use --output to specify a different path."
    exit 1
fi

# Ensure output directory exists
OUTPUT_DIR="$(dirname "$OUTPUT")"
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

echo "=== DANTE TERMINAL: Android Release Keystore Generator ==="
echo ""
echo "Generating keystore with:"
echo "  Output:   $OUTPUT"
echo "  Alias:    $ALIAS"
echo "  Algorithm: $KEY_ALG $KEY_SIZE-bit"
echo "  Validity: $VALIDITY days"
echo ""
echo "You will be prompted for:"
echo "  - Keystore password (choose a strong password)"
echo "  - Key password (can be same as keystore password)"
echo "  - Your name, organization, and location"
echo ""
echo "IMPORTANT: Write down your passwords securely. You cannot recover them."
echo ""

keytool -genkey -v \
    -keystore "$OUTPUT" \
    -keyalg "$KEY_ALG" \
    -keysize "$KEY_SIZE" \
    -validity "$VALIDITY" \
    -alias "$ALIAS"

echo ""
echo "=== Keystore generated successfully ==="
echo ""
echo "Next steps:"
echo "  1. Copy the template:"
echo "     cp dante_terminal/android/key.properties.template dante_terminal/android/key.properties"
echo ""
echo "  2. Edit dante_terminal/android/key.properties with your values:"
echo "     storePassword=<your keystore password>"
echo "     keyPassword=<your key password>"
echo "     keyAlias=$ALIAS"
echo "     storeFile=$OUTPUT"
echo ""
echo "  3. Build a signed release:"
echo "     cd dante_terminal && flutter build appbundle --release"
echo ""
echo "  4. BACK UP '$OUTPUT' and your passwords to a secure location."
echo "     If you lose the keystore, you can NEVER update the app on Google Play."
