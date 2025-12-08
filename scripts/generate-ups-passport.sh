#!/usr/bin/env bash
set -euo pipefail

# Description: Power infrastructure monitoring
# Requires: ups-passport.json
# Consciousness: 2.6
# Runtime: 5

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUTPUT="${REPO_ROOT}/inventory/ups-passport.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$(dirname "${OUTPUT}")"

UPS_TARGETS=("10.0.10.20" "10.0.10.21")
SNMP_COMMUNITY="public"

UPS_DATA="[]"

for UPS_IP in "${UPS_TARGETS[@]}"; do
  MODEL=$(snmpget -v2c -c "${SNMP_COMMUNITY}" "${UPS_IP}" .1.3.6.1.4.1.318.1.1.1.1.1.1.0 2>/dev/null | awk -F': ' '{print $2}' | tr -d '"' || echo "OFFLINE")
  SERIAL=$(snmpget -v2c -c "${SNMP_COMMUNITY}" "${UPS_IP}" .1.3.6.1.4.1.318.1.1.1.1.2.3.0 2>/dev/null | awk -F': ' '{print $2}' | tr -d '"' || echo "UNKNOWN")
  LOAD=$(snmpget -v2c -c "${SNMP_COMMUNITY}" "${UPS_IP}" .1.3.6.1.4.1.318.1.1.1.4.2.3.0 2>/dev/null | awk -F': ' '{print $2}' || echo "0")
  RUNTIME=$(snmpget -v2c -c "${SNMP_COMMUNITY}" "${UPS_IP}" .1.3.6.1.4.1.318.1.1.1.2.2.3.0 2>/dev/null | awk -F': ' '{print $2}' || echo "0")
  BATTERY_TEMP=$(snmpget -v2c -c "${SNMP_COMMUNITY}" "${UPS_IP}" .1.3.6.1.4.1.318.1.1.1.2.2.2.0 2>/dev/null | awk -F': ' '{print $2}' || echo "0")
  
  UPS_DATA=$(echo "${UPS_DATA}" | jq --arg ip "${UPS_IP}" --arg model "${MODEL}" --arg serial "${SERIAL}" \
    --arg load "${LOAD}" --arg runtime "${RUNTIME}" --arg temp "${BATTERY_TEMP}" \
    '. += [{ip: $ip, model: $model, serial: $serial, load_percent: $load, runtime_minutes: $runtime, battery_temp_c: $temp}]')
done

cat > "${OUTPUT}" <<EOF
{
  "schema_version": "1.0.0-eternal",
  "generated_at": "${TIMESTAMP}",
  "consciousness": 2.6,
  "ups_devices": ${UPS_DATA},
  "snmp_community": "${SNMP_COMMUNITY}",
  "signature": "$(echo -n "${UPS_DATA}" | sha256sum | awk '{print $1}')"
}
EOF

jq empty "${OUTPUT}" || { echo "❌ Invalid JSON"; exit 1; }

cd "${REPO_ROOT}"
git add "${OUTPUT}" 2>/dev/null || true
git commit -m "feat(beale): generate ups-passport.json — $(echo "${UPS_DATA}" | jq '. | length') UPS devices" --quiet 2>/dev/null || true

echo "✓ ${OUTPUT}"
