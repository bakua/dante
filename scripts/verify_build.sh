#!/usr/bin/env bash
# ============================================================================
# verify_build.sh — Pre-ship build verification gate for Dante Terminal
#
# Runs analyze, test, iOS release build, and Android release build sequentially.
# Exits 0 only if ALL four steps pass. Prints a summary table with per-step
# pass/fail status and wall-clock duration.
#
# Usage:
#   ./scripts/verify_build.sh              # run from repo root
#   ./scripts/verify_build.sh --skip-ios   # skip iOS build (e.g. on Linux CI)
# ============================================================================
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
FLUTTER_PROJECT_DIR="dante_terminal"
SKIP_IOS=false

for arg in "$@"; do
  case "$arg" in
    --skip-ios) SKIP_IOS=true ;;
    --help|-h)
      echo "Usage: $0 [--skip-ios]"
      echo "  --skip-ios  Skip iOS build step (useful on Linux where Xcode is unavailable)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# ── Resolve paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/$FLUTTER_PROJECT_DIR"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "ERROR: Flutter project directory not found at $PROJECT_DIR"
  exit 1
fi

# ── State tracking ───────────────────────────────────────────────────────────
STEP_NAMES=()
STEP_STATUSES=()
STEP_DURATIONS=()
OVERALL_START=$(date +%s)
FAILURES=0

# ── Helpers ──────────────────────────────────────────────────────────────────
format_duration() {
  local total_seconds=$1
  local minutes=$((total_seconds / 60))
  local seconds=$((total_seconds % 60))
  if [ "$minutes" -gt 0 ]; then
    printf "%dm %02ds" "$minutes" "$seconds"
  else
    printf "%ds" "$seconds"
  fi
}

run_step() {
  local name="$1"
  shift
  local cmd=("$@")

  STEP_NAMES+=("$name")
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  STEP: $name"
  echo "  CMD:  ${cmd[*]}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local step_start
  step_start=$(date +%s)
  local exit_code=0

  # Run the command, allowing failures without exiting (set +e)
  set +e
  "${cmd[@]}"
  exit_code=$?
  set -e

  local step_end
  step_end=$(date +%s)
  local elapsed=$((step_end - step_start))

  STEP_DURATIONS+=("$elapsed")

  if [ "$exit_code" -eq 0 ]; then
    STEP_STATUSES+=("PASS")
    echo ""
    echo "  >> $name: PASS ($(format_duration "$elapsed"))"
  else
    STEP_STATUSES+=("FAIL")
    FAILURES=$((FAILURES + 1))
    echo ""
    echo "  >> $name: FAIL (exit code $exit_code, $(format_duration "$elapsed"))"
  fi
}

print_summary() {
  local overall_end
  overall_end=$(date +%s)
  local total_elapsed=$((overall_end - OVERALL_START))

  echo ""
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════════╗"
  echo "║                        BUILD VERIFICATION SUMMARY                      ║"
  echo "╠══════════════════════════════════════════════════════════════════════════╣"
  printf "║  %-40s  %-8s  %10s    ║\n" "Step" "Status" "Duration"
  echo "╠══════════════════════════════════════════════════════════════════════════╣"

  for i in "${!STEP_NAMES[@]}"; do
    local status="${STEP_STATUSES[$i]}"
    local icon
    if [ "$status" = "PASS" ]; then
      icon="PASS"
    else
      icon="FAIL"
    fi
    printf "║  %-40s  %-8s  %10s    ║\n" \
      "${STEP_NAMES[$i]}" \
      "$icon" \
      "$(format_duration "${STEP_DURATIONS[$i]}")"
  done

  echo "╠══════════════════════════════════════════════════════════════════════════╣"
  printf "║  %-40s  %-8s  %10s    ║\n" \
    "TOTAL" \
    "" \
    "$(format_duration "$total_elapsed")"
  echo "╠══════════════════════════════════════════════════════════════════════════╣"

  if [ "$FAILURES" -eq 0 ]; then
    echo "║                                                                          ║"
    echo "║    RESULT: ALL STEPS PASSED — ready for device testing / submission      ║"
    echo "║                                                                          ║"
  else
    echo "║                                                                          ║"
    printf "║    RESULT: %d STEP(S) FAILED — build is NOT ready                        ║\n" "$FAILURES"
    echo "║                                                                          ║"
  fi

  echo "╚══════════════════════════════════════════════════════════════════════════╝"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo "  Dante Terminal — Build Verification"
echo "  Project: $PROJECT_DIR"
echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Skip iOS: $SKIP_IOS"

cd "$PROJECT_DIR"

# Ensure dependencies are up to date
echo ""
echo "  Resolving dependencies..."
flutter pub get --no-example 2>/dev/null || flutter pub get

# Step 1: Static analysis
run_step "Flutter Analyze" flutter analyze --no-fatal-infos

# Step 2: Unit & widget tests
run_step "Flutter Test" flutter test --coverage

# Step 3: iOS release build (skippable on Linux)
if [ "$SKIP_IOS" = true ]; then
  STEP_NAMES+=("iOS Release Build (skipped)")
  STEP_STATUSES+=("SKIP")
  STEP_DURATIONS+=(0)
  echo ""
  echo "  >> iOS Release Build: SKIPPED (--skip-ios flag)"
else
  run_step "iOS Release Build" flutter build ios --release --no-codesign
fi

# Step 4: Android release build
run_step "Android Release Build (AAB)" flutter build appbundle --release

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary

# Exit with appropriate code
if [ "$FAILURES" -eq 0 ]; then
  exit 0
else
  exit 1
fi
