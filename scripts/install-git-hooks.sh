#!/usr/bin/env bash
# Script: install-git-hooks.sh
# Purpose: Install versioned git hooks — The Summoning Protocol
# Guardian: The All-Seeing Eye
# Consciousness: 4.4
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${REPO_ROOT}"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  THE SUMMONING PROTOCOL — Installing Guardian Hooks"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

if [[ ! -d ".githooks" ]]; then
  echo "❌ No .githooks directory found. Nothing to install." >&2
  exit 1
fi

# Set hooks path
git config core.hooksPath .githooks

# Make all hooks executable
chmod +x .githooks/* 2>/dev/null || true

echo "✅ Hooks installed: core.hooksPath set to .githooks"
echo ""
echo "   Installed hooks:"
for hook in .githooks/*; do
  if [[ -f "$hook" && -x "$hook" ]]; then
    HOOK_NAME=$(basename "$hook")
    case "$HOOK_NAME" in
      pre-commit)
        echo "   - pre-commit      (BOM/CRLF normalization)"
        ;;
      commit-msg)
        echo "   - commit-msg      (Namer: Conventional Commits validation)"
        ;;
      prepare-commit-msg)
        echo "   - prepare-commit-msg (Namer: Template injection)"
        ;;
      post-commit)
        echo "   - post-commit     (Eye: Threshold detection)"
        ;;
      pre-push)
        echo "   - pre-push        (Gatekeeper: Full validation)"
        ;;
      *)
        echo "   - $HOOK_NAME"
        ;;
    esac
  fi
done

echo ""
echo "   Guardian responsibilities:"
echo "   ┌────────────────────┬───────────────────────────────────────────┐"
echo "   │ Hook               │ Guardian    │ Purpose                     │"
echo "   ├────────────────────┼─────────────┼─────────────────────────────┤"
echo "   │ prepare-commit-msg │ Namer       │ Inject template             │"
echo "   │ commit-msg         │ Namer       │ Validate format             │"
echo "   │ post-commit        │ Eye         │ Detect thresholds           │"
echo "   │ pre-commit         │ Scholar     │ Normalize encoding          │"
echo "   │ pre-push           │ Gatekeeper  │ Block unclean code          │"
echo "   └────────────────────┴─────────────┴─────────────────────────────┘"
echo ""
echo "The guardians are summoned. The fortress watches."
echo ""
