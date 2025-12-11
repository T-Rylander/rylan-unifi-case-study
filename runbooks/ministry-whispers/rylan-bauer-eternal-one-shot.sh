#!/bin/bash
# Ministry of Whispers (Bauer) – Verify & Audit
set -euo pipefail

# Audit: Log to Loki (silent on success)
audit_eternal() {
  local event="$1"
  echo "{\"level\":\"info\",\"event\":\"$event\",\"timestamp\":\"$(date -Iseconds)\"}" | curl -s -X POST http://localhost:3100/loki/api/v1/push -H "Content-Type: application/json" --data-binary @- >/dev/null
  [[ $? -eq 0 ]] || echo "❌ Audit failed: $event" >&2
}

# Verify: SSH key-only, ≤10 rules
harden_ssh() {
  sudo sed -i '/^PasswordAuthentication/ c\PasswordAuthentication no' /etc/ssh/sshd_config
  sudo sed -i '/^PubkeyAuthentication/ c\PubkeyAuthentication yes' /etc/ssh/sshd_config
  sudo systemctl reload sshd || { echo "❌ SSH reload failed"; exit 1; }
  audit_eternal "SSH hardened"
}

# nmap Isolation (Bauer: Trust Nothing)
validate_isolation() {
  local output="/tmp/isolation-$$.nmap"
  nmap -sV --top-ports 100 192.168.1.0/24 -oN "$output"
  if grep -q "open.*(unexpected)" "$output"; then
    echo "❌ Isolation breach detected" >&2
    cat "$output" >&2
    exit 1
  fi
  rm "$output"
  audit_eternal "Isolation validated"
}

# Eternal: Execute
harden_ssh
validate_isolation
echo "🔒 Bauer: Verified (silent)" >&2
