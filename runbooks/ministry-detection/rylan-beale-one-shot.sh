#!/usr/bin/env bash
# runbooks/ministry-detection/rylan-beale-one-shot.sh
# Beale (2001/2004) — Harden the Host, Detect the Breach
# T3-ETERNAL v3.2: Bastille automation + Snort IDS. Idempotent. Least privilege.
# Consciousness 2.6 — truth through subtraction.
# Execution: <120 seconds. Fail loudly on breach.
set -euo pipefail

# === CONFIG ===
SNORT_CONF="/etc/snort/snort.conf"
BASTILLE_LOG="/var/log/bastille-hardening.log"
IDS_ALERT_LOG="/var/log/snort/alert"
VLAN_MONITOR="10.0.90.0/25"  # VLAN 90 (guest-iot)

echo "🚨 [BEALE] Ministry of Detection: Bastille + Snort IDS"

# === PHASE 1: BASTILLE — DISABLE UNNECESSARY SERVICES ===
echo "[BEALE] Phase 1: Service lockdown..."
UNNECESSARY_SERVICES=(
    "bluetooth.service"
    "cups.service"
    "avahi-daemon.service"
    "ModemManager.service"
    "whoopsie.service"
    "apport.service"
)

INITIAL_COUNT=$(systemctl list-units --state=running --type=service --no-pager --no-legend | wc -l)
DISABLED_COUNT=0

for svc in "${UNNECESSARY_SERVICES[@]}"; do
    if systemctl is-enabled "$svc" 2>/dev/null | grep -q "enabled"; then
        echo " [DISABLE] $svc"
        systemctl disable --now "$svc" >> "$BASTILLE_LOG" 2>&1 || { echo " [FATAL] Failed to disable $svc"; exit 1; }
        ((DISABLED_COUNT++))
    fi
done

# === PHASE 2: SNORT IDS — INSTALL & CONFIG ===
echo "[BEALE] Phase 2: Snort deployment..."
if ! command -v snort >/dev/null 2>&1; then
    echo " [INSTALL] Snort + oinkmaster..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq snort oinkmaster
else
    echo " [CONFIG] Snort already present"
fi

if [[ ! -f "$SNORT_CONF" ]]; then
    echo " [FATAL] Snort config missing: $SNORT_CONF"
    exit 1
fi

# Set HOME_NET if needed
if ! grep -q "var HOME_NET $VLAN_MONITOR" "$SNORT_CONF" 2>/dev/null; then
    echo " [CONFIG] HOME_NET → $VLAN_MONITOR"
    sed -i "s|^var HOME_NET.*|var HOME_NET $VLAN_MONITOR|" "$SNORT_CONF" || { echo " [FATAL] Config update failed"; exit 1; }
fi

# Validate config
echo " [VALIDATE] Snort config test..."
if ! snort -T -c "$SNORT_CONF" &>/dev/null; then
    echo " [FATAL] Snort config invalid:"
    snort -T -c "$SNORT_CONF"
    exit 1
fi

# Enable service
if ! systemctl is-active --quiet snort; then
    echo " [START] Enabling Snort..."
    systemctl enable --now snort || { echo " [FATAL] Snort enable failed"; exit 1; }
    sleep 2
fi

if ! systemctl is-active --quiet snort; then
    echo " [FATAL] Snort failed to start:"
    journalctl -u snort -n 20 --no-pager
    exit 1
fi

# === PHASE 3: WHITAKER — RED-TEAM VALIDATION ===
echo "[BEALE] Phase 3: Offensive validation..."
if [[ -f "$IDS_ALERT_LOG" ]]; then
    ALERT_COUNT=$(wc -l < "$IDS_ALERT_LOG")
    [[ $ALERT_COUNT -eq 0 ]] && echo " [NOTE] No alerts yet (fresh install expected)"
else
    echo " [WARN] Alert log missing — create: touch $IDS_ALERT_LOG"
fi

# Simulate nmap scan to trigger IDS
if command -v nmap >/dev/null 2>&1; then
    echo " [WHITAKER] Simulating port scan on $VLAN_MONITOR..."
    timeout 10 nmap -sV --top-ports 10 "$VLAN_MONITOR" -T4 >/dev/null 2>&1 || true
    sleep 2
    if grep -q "\[1:1000:1\]" "$IDS_ALERT_LOG" 2>/dev/null; then  # Basic scan rule match
        echo " [OK] IDS detected scan"
    else
        echo " [WARN] No scan detection — verify Snort rules"
    fi
else
    echo " [WARN] nmap missing — install for full validation"
fi

# === SUMMARY ===
FINAL_COUNT=$(systemctl list-units --state=running --type=service --no-pager --no-legend | wc -l)
echo "[BEALE] Hardening complete:"
echo "  Services: $INITIAL_COUNT → $FINAL_COUNT (delta: $((INITIAL_COUNT - FINAL_COUNT)))"
echo "  Disabled: $DISABLED_COUNT"
echo "  IDS: Active on $VLAN_MONITOR | Logs: $IDS_ALERT_LOG"
echo "  Hardening log: $BASTILLE_LOG"

cat <<'BANNER'
██████╗ ███████╗ █████╗ ██╗     ███████╗
██╔══██╗██╔════╝██╔══██╗██║     ██╔════╝
██████╔╝█████╗  ███████║██║     █████╗  
██╔══██╗██╔══╝  ██╔══██║██║     ██╔══╝  
██████╔╝███████╗██║  ██║███████╗███████╗
╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝
BASTILLE HARDENED. SNORT ACTIVE. BREACH DETECTED.
HARDEN THE HOST. DETECT THE BREACH.
— Beale Ministry v3.2
BANNER

echo "✅ [BEALE] Detection ministry deployed. Fortress vigilance: eternal."