#!/usr/bin/env bash
# Ministry of Whispers — Bauer Hardening (Phase 2)
# SSH key-only auth + nftables drop-default + fail2ban + audit logging
# Depends on: Ministry of Secrets (Phase 1) ✓
# Sequential exit-on-fail execution

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Ministry of Whispers — Bauer Hardening (Phase 2)          ║"
echo "║  SSH key-only + nftables drop-default + fail2ban + audit  ║"
echo "║  Depends on Phase 1: Ministry of Secrets (REQUIRED)       ║"
echo "╚════════════════════════════════════════════════════════════╝"

set -euo pipefail

# Load environment
if [[ ! -f .env ]]; then
  echo "❌ .env not found."
  exit 1
fi
source .env

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_TIME=$(date +%s)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_step() { echo -e "${GREEN}[WHISPERS]${NC} $1"; }
log_error() { echo -e "${RED}[WHISPERS-ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WHISPERS-WARN]${NC} $1"; }

trap 'ELAPSED=$(($(date +%s) - START_TIME)); echo -e "${GREEN}Phase 2 duration: ${ELAPSED}s${NC}"' EXIT

# =============================================================================
# PRE-FLIGHT: Verify Phase 1 Completion
# =============================================================================

log_step "Pre-flight: Verifying Phase 1 (Ministry of Secrets) completion..."

if ! systemctl is-active --quiet samba-ad-dc; then
  log_error "Phase 1 prerequisite FAILED: Samba AD/DC not active"
  exit 1
fi

if [[ ! -f /etc/krb5.keytab ]] || [[ ! -s /etc/krb5.keytab ]]; then
  log_error "Phase 1 prerequisite FAILED: Kerberos keytab missing"
  exit 1
fi

log_step "✓ Phase 1 prerequisites verified"

# =============================================================================
# PHASE 2.1: SSH Hardening (Key-Only Auth)
# =============================================================================

log_step "Phase 2.1: SSH Hardening (Key-only authentication)"

# Backup sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d-%H%M%S)

# Deploy hardened sshd_config
cat > /etc/ssh/sshd_config << 'EOF'
# Hardened SSH Configuration — Ministry of Whispers
# Key-only authentication, no password login, no root

# Port
Port 22

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
PermitUserEnvironment no
Compression delayed
AllowAgentForwarding no
AllowTcpForwarding no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2

# Key types (modern)
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Ciphers (FIPS-compliant, strong)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Restrict to specific users (if defined)
AllowUsers *@rylan.internal root@localhost

# Banner
Banner /etc/ssh/banner
EOF

# Create SSH banner
cat > /etc/ssh/banner << 'EOF'
╔════════════════════════════════════════════════════════════╗
║     ETERNAL FORTRESS — Ministry of Whispers (Bauer)       ║
║  Key-only SSH access. Unauthorized access prohibited.     ║
║  All activity is logged and monitored via audit-eternal.  ║
╚════════════════════════════════════════════════════════════╝
EOF

# Validate sshd config
if ! sshd -t > /dev/null 2>&1; then
  log_error "SSH config validation failed"
  cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
  exit 1
fi

systemctl reload ssh || systemctl restart ssh
log_step "✓ SSH hardened (key-only, no password)"

# =============================================================================
# PHASE 2.2: nftables Firewall (Drop-Default)
# =============================================================================

log_step "Phase 2.2: nftables Firewall (drop-default policy)"

# Install nftables
if ! command -v nft &> /dev/null; then
  apt-get update -qq
  apt-get install -y -qq nftables > /dev/null 2>&1
  log_step "nftables installed"
fi

# Disable ufw if active
if systemctl is-active --quiet ufw; then
  systemctl disable ufw
  systemctl stop ufw
  log_step "UFW disabled (using nftables)"
fi

# Deploy minimal nftables config (drop-default)
cat > /etc/nftables.conf << 'EOF'
#!/usr/bin/nft -f
# Minimal nftables ruleset — Ministry of Whispers
# Default DROP policy, whitelist SSH + DHCP (if applicable)

flush ruleset

table inet firewall {
	chain ingress {
		type filter hook input priority filter; policy drop;
		
		# Loopback
		iif "lo" accept
		
		# ICMP (ping)
		icmp type echo-request accept
		icmpv6 type echo-request accept
		
		# SSH (port 22) — key-only from anywhere
		tcp dport 22 accept
		
		# DHCP (if DHCP server)
		udp dport 67 accept
		udp sport 68 accept
		
		# Established connections
		ct state established,related accept
		ct state invalid drop
		
		# Drop the rest
		counter drop
	}
	
	chain forward {
		type filter hook forward priority filter; policy drop;
	}
	
	chain egress {
		type filter hook output priority filter; policy accept;
	}
}
EOF

# Enable and start nftables
systemctl enable nftables
systemctl restart nftables

if systemctl is-active --quiet nftables; then
  log_step "✓ nftables loaded with drop-default policy"
else
  log_error "nftables failed to start"
  exit 1
fi

# =============================================================================
# PHASE 2.3: Fail2Ban Intrusion Prevention
# =============================================================================

log_step "Phase 2.3: Fail2Ban intrusion prevention"

# Install fail2ban
if ! command -v fail2ban-server &> /dev/null; then
  apt-get install -y -qq fail2ban > /dev/null 2>&1
  log_step "fail2ban installed"
fi

# Deploy jail.local
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log

[sshd-aggressive]
enabled = true
filter  = sshd-aggressive
maxretry = 3
bantime = 86400
logpath = /var/log/auth.log
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log_step "✓ Fail2Ban configured (3600s ban, max 5 failures)"

# =============================================================================
# PHASE 2.4: Audit Logging Configuration
# =============================================================================

log_step "Phase 2.4: Audit logging (guardian/audit-eternal integration)"

# Install auditd
if ! command -v auditctl &> /dev/null; then
  apt-get install -y -qq auditd audispd-plugins > /dev/null 2>&1
  log_step "auditd installed"
fi

# Deploy audit rules
cat > /etc/audit/rules.d/ministry-whispers.rules << 'EOF'
# Ministry of Whispers Audit Rules — Bauer
# Monitor: SSH auth, firewall changes, user/group modifications

# SSH authentication attempts
-w /var/log/auth.log -p wa -k ssh_auth
-w /etc/ssh/sshd_config -p wa -k ssh_config

# User/group management
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes

# Firewall/nftables
-w /etc/nftables.conf -p wa -k firewall_config
-a always,exit -F dir=/etc/nftables.d/ -F perm=wa -k firewall_rules

# Fail2ban
-w /etc/fail2ban/ -p wa -k fail2ban_config

# System calls (authentication)
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/sudo -F key=sudo_exec
-a always,exit -F arch=b64 -S execve -F exe=/usr/sbin/ssh-* -F key=ssh_exec
EOF

augenrules --load
systemctl restart auditd
log_step "✓ Auditd rules deployed"

# =============================================================================
# PHASE 2.5: Guardians Audit Hook
# =============================================================================

log_step "Phase 2.5: Integration with guardian/audit-eternal.py"

# Create symlink to audit output (for guardian consumption)
mkdir -p /var/log/guardian
ln -sf /var/log/audit/audit.log /var/log/guardian/auth-audit.log 2>/dev/null || true

log_step "✓ Audit logging pipeline ready for guardian"

# =============================================================================
# VALIDATION: Ministry of Whispers
# =============================================================================

log_step "Validating Ministry of Whispers..."

VALIDATION_PASS=0

# Check 1: SSH key-only (no password)
if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
  log_step "✓ SSH password authentication disabled"
  ((VALIDATION_PASS++))
else
  log_error "SSH password auth still enabled"
fi

# Check 2: nftables running with DROP policy
if systemctl is-active --quiet nftables; then
  if nft list ruleset 2>/dev/null | grep -q "policy drop"; then
    log_step "✓ nftables running with drop-default policy"
    ((VALIDATION_PASS++))
  fi
fi

# Check 3: fail2ban running
if systemctl is-active --quiet fail2ban; then
  log_step "✓ Fail2Ban active"
  ((VALIDATION_PASS++))
fi

# Check 4: auditd running
if systemctl is-active --quiet auditd; then
  log_step "✓ auditd active"
  ((VALIDATION_PASS++))
fi

echo ""
log_step "Ministry of Whispers validation: ${VALIDATION_PASS}/4 checks passed"

if [[ $VALIDATION_PASS -lt 3 ]]; then
  log_error "Insufficient validation passes (${VALIDATION_PASS}/4)"
  exit 1
fi

log_step "═══════════════════════════════════════════════════════════"
log_step "Phase 2 COMPLETE: Ministry of Whispers hardening complete"
log_step "Next: Phase 3 (Ministry of Perimeter) — Policy enforcement"
log_step "═══════════════════════════════════════════════════════════"

exit 0
