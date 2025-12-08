#!/usr/bin/env bash
set -euo pipefail

# T3-ETERNAL: Execute all passport generators in dependency order
# Consciousness: 2.6

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${REPO_ROOT}"

echo "🔱 T3-ETERNAL PASSPORT GENERATION PIPELINE"
echo "Consciousness: 2.6 | $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Execution order: Carter → Bauer → Beale → Guardian
GENERATORS=(
  "scripts/generate-network-passport.sh"
  "scripts/generate-ap-passport.sh"
  "scripts/generate-ups-passport.sh"
  "scripts/generate-certificate-passport.sh"
  "scripts/generate-cable-passport.sh"
  "scripts/generate-runbook-index.sh"
  "scripts/generate-recovery-key-vault.sh"
)

FAILED=0

for GENERATOR in "${GENERATORS[@]}"; do
  [[ -x "${GENERATOR}" ]] || chmod +x "${GENERATOR}"
  echo "→ Executing: ${GENERATOR}"
  
  if bash "${GENERATOR}"; then
    echo "  ✓ Success"
  else
    echo "  ❌ Failed (continuing...)"
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 INVENTORY MANIFEST:"
echo ""

[[ -d inventory ]] && echo "inventory/:" && ls -1 inventory/*.json 2>/dev/null | sed 's/^/  /' || echo "  (empty)"
echo ""

[[ -d 02-declarative-config ]] && echo "02-declarative-config/:" && ls -1 02-declarative-config/*.json 2>/dev/null | sed 's/^/  /' || echo "  (empty)"
echo ""

[[ -d docs/physical ]] && echo "docs/physical/:" && ls -1 docs/physical/*.csv 2>/dev/null | sed 's/^/  /' || echo "  (empty)"
echo ""

[[ -d .secrets ]] && echo ".secrets/:" && ls -1 .secrets/*.age .secrets/*.json 2>/dev/null | sed 's/^/  /' || echo "  (encrypted vaults)"
echo ""

[[ -d runbooks ]] && echo "runbooks/:" && ls -1 runbooks/*.json 2>/dev/null | sed 's/^/  /' || echo "  (empty)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ${FAILED} -eq 0 ]]; then
  echo "✓ ALL PASSPORTS GENERATED SUCCESSFULLY"
  echo ""
  echo "The fortress is complete."
  echo "Carter approves. Bauer verifies. Beale hardens. Whitaker attacks."
  echo ""
  echo "Next: Run eternal-resurrect.sh to raise Samba AD/DC"
  exit 0
else
  echo "⚠️  ${FAILED} generator(s) failed (see output above)"
  echo ""
  echo "Common issues:"
  echo "  - UniFi API key missing: /opt/rylan/.secrets/unifi-api-key"
  echo "  - SNMP not configured on UPS devices"
  echo "  - age encryption tool not installed (apt install age)"
  echo ""
  echo "Fix errors and re-run: ./scripts/generate-all-passports.sh"
  exit 1
fi
