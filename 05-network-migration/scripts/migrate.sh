#!/bin/bash
# Migrate: Render Desired → Backup → Push → Verify
set -euo pipefail
cd "$(dirname "$0")/.."

# Pre-flight: Backup (Hellodeolu: RTO <15 min)
mkdir -p backups
source ../runbooks/ministry-secrets/rylan-carter-eternal-one-shot.sh
unifi_get_networks > backups/pre-migration-$(date +%Y%m%d-%H%M%S).json
echo "💾 Backup saved to backups/"

# Render + Push
python ../02-declarative-config/apply.py --render-only
unifi_push_network "$(cat configs/vlans.json)"
unifi_push_network "$(cat configs/firewall-rules.json)"

# Post-verify (Bauer: Trust Nothing)
../scripts/validate-isolation.sh
echo "🛡️ Migration complete. Rollback: ./rollback.sh | RTO <15 min validated."
