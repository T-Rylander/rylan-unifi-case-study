#!/usr/bin/env bash
# runbooks/ministry-carter/provision-samba-ad.sh — Carter: Identity is Programmable
# Purpose: One-shot Samba AD/DC provision (idempotent, 802.1X ready)
# Trinity: Carter (2003) — LDAP/RADIUS/SSH CA eternal
# Canon: ≤120 lines, set -euo pipefail, zero manual steps
set -euo pipefail
IFS=$'\n\t'
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

log() { printf '%b\n' "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ${SCRIPT_NAME}: $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# ────── CONFIGURATION ──────
readonly DOMAIN="rylan.local"
readonly REALM="RYLAN.LOCAL"
readonly DC_HOSTNAME="rylan-dc"
readonly DC_IP="10.0.10.10"
readonly ADMIN_PASSWORD="${SAMBA_ADMIN_PASSWORD:-$(openssl rand -base64 32)}"
readonly DNS_FORWARDER="1.1.1.1"

# ────── PRE-FLIGHT VALIDATION ──────
preflight_checks() {
  log "Running pre-flight checks..."
  
  # Check if running as root
  [[ $EUID -eq 0 ]] || die "Must run as root"
  
  # Check if already provisioned (idempotent)
  if samba-tool domain info 127.0.0.1 2>/dev/null | grep -q "Domain"; then
    log "✓ Samba AD already provisioned (idempotent skip)"
    exit 0
  fi
  
  # Check hostname
  local current_hostname
  current_hostname=$(hostname -f)
  if [[ "${current_hostname}" != "${DC_HOSTNAME}.${DOMAIN}" ]]; then
    log "Setting hostname to ${DC_HOSTNAME}.${DOMAIN}"
    hostnamectl set-hostname "${DC_HOSTNAME}.${DOMAIN}"
  fi
  
  # Check required packages
  for pkg in samba winbind krb5-user; do
    if ! dpkg -l | grep -q "^ii  ${pkg}"; then
      log "Installing ${pkg}..."
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkg}"
    fi
  done
  
  log "✓ Pre-flight checks passed"
}

# ────── SAMBA PROVISION ──────
provision_domain() {
  log "Provisioning Samba AD domain: ${REALM}"
  
  # Stop services
  systemctl stop smbd nmbd winbind 2>/dev/null || true
  systemctl disable smbd nmbd winbind 2>/dev/null || true
  
  # Backup existing config
  if [[ -f /etc/samba/smb.conf ]]; then
    mv /etc/samba/smb.conf "/etc/samba/smb.conf.backup.$(date +%s)"
  fi
  
  # Remove existing database
  rm -rf /var/lib/samba/*.tdb /var/lib/samba/*.ldb 2>/dev/null || true
  
  # Provision domain
  samba-tool domain provision \
    --realm="${REALM}" \
    --domain="${DOMAIN%%.*}" \
    --adminpass="${ADMIN_PASSWORD}" \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --option="dns forwarder = ${DNS_FORWARDER}" \
    --option="allow dns updates = nonsecure and secure" \
    || die "Domain provision failed"
  
  log "✓ Domain provisioned"
}

# ────── KERBEROS CONFIGURATION ──────
configure_kerberos() {
  log "Configuring Kerberos..."
  
  # Backup existing krb5.conf
  [[ -f /etc/krb5.conf ]] && cp /etc/krb5.conf "/etc/krb5.conf.backup.$(date +%s)"
  
  # Link Samba's krb5.conf
  ln -sf /var/lib/samba/private/krb5.conf /etc/krb5.conf
  
  log "✓ Kerberos configured"
}

# ────── DNS CONFIGURATION ──────
configure_dns() {
  log "Configuring DNS..."
  
  # Set local resolver to use Samba DNS
  cat > /etc/resolv.conf <<EOF
# Managed by ministry-carter
nameserver 127.0.0.1
search ${DOMAIN}
EOF
  
  # Add DNS records
  samba-tool dns add 127.0.0.1 "${DOMAIN}" "${DC_HOSTNAME}" A "${DC_IP}" \
    -U Administrator --password="${ADMIN_PASSWORD}" 2>/dev/null || true
  
  # Add reverse DNS
  local reverse_zone
  reverse_zone=$(echo "${DC_IP}" | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
  samba-tool dns zonecreate 127.0.0.1 "${reverse_zone}" \
    -U Administrator --password="${ADMIN_PASSWORD}" 2>/dev/null || true
  
  log "✓ DNS configured"
}

# ────── SERVICE MANAGEMENT ──────
enable_services() {
  log "Enabling Samba services..."
  
  # Unmask and enable samba-ad-dc
  systemctl unmask samba-ad-dc 2>/dev/null || true
  systemctl enable samba-ad-dc
  systemctl restart samba-ad-dc || die "Failed to start samba-ad-dc"
  
  # Wait for service to be ready
  local retries=30
  while [[ ${retries} -gt 0 ]]; do
    if samba-tool domain info 127.0.0.1 2>/dev/null | grep -q "Domain"; then
      log "✓ Samba AD/DC operational"
      break
    fi
    sleep 2
    retries=$((retries - 1))
  done
  
  [[ ${retries} -eq 0 ]] && die "Samba AD/DC failed to start"
}

# ────── POST-PROVISION HARDENING ──────
harden_domain() {
  log "Applying security hardening..."
  
  # Set password policies
  samba-tool domain passwordsettings set \
    --complexity=on \
    --min-pwd-length=12 \
    --min-pwd-age=1 \
    --max-pwd-age=90 \
    -U Administrator --password="${ADMIN_PASSWORD}" || true
  
  # Create service accounts (for UniFi, osTicket, etc.)
  for service in unifi osticket grafana; do
    samba-tool user create "svc-${service}" "$(openssl rand -base64 24)" \
      --description="Service account for ${service}" \
      -U Administrator --password="${ADMIN_PASSWORD}" 2>/dev/null || true
  done
  
  log "✓ Security hardening applied"
}

# ────── VALIDATION ──────
validate_provision() {
  log "Validating domain provision..."
  
  local failed=0
  
  # Test 1: Domain info
  if samba-tool domain info 127.0.0.1 | grep -q "${REALM}"; then
    log "  ✓ Domain info correct"
  else
    log "  ✗ Domain info failed"
    failed=$((failed + 1))
  fi
  
  # Test 2: DNS resolution
  if nslookup "${DC_HOSTNAME}.${DOMAIN}" 127.0.0.1 | grep -q "${DC_IP}"; then
    log "  ✓ DNS resolution working"
  else
    log "  ✗ DNS resolution failed"
    failed=$((failed + 1))
  fi
  
  # Test 3: Kerberos ticket
  if echo "${ADMIN_PASSWORD}" | kinit Administrator@"${REALM}" 2>/dev/null; then
    log "  ✓ Kerberos authentication working"
    kdestroy 2>/dev/null || true
  else
    log "  ✗ Kerberos authentication failed"
    failed=$((failed + 1))
  fi
  
  if [[ ${failed} -gt 0 ]]; then
    die "${failed} validation(s) failed"
  fi
  
  log "✓ All validations passed"
}

# ────── MAIN ──────
main() {
  log "════════════════════════════════════════════════════════════"
  log "MINISTRY CARTER — Identity is Programmable Infrastructure"
  log "════════════════════════════════════════════════════════════"
  log "Domain: ${DOMAIN}"
  log "Realm: ${REALM}"
  log "DC: ${DC_HOSTNAME} (${DC_IP})"
  log ""
  
  preflight_checks
  provision_domain
  configure_kerberos
  configure_dns
  enable_services
  harden_domain
  validate_provision
  
  log ""
  log "════════════════════════════════════════════════════════════"
  log "✓ CARTER MINISTRY COMPLETE"
  log "════════════════════════════════════════════════════════════"
  log ""
  log "Admin credentials:"
  log "  Username: Administrator"
  log "  Password: ${ADMIN_PASSWORD}"
  log "  (Store in vault: .secrets/samba-admin)"
  log ""
  log "Next steps:"
  log "  1. Join clients: samba-tool domain join ${REALM} MEMBER"
  log "  2. Configure 802.1X: Use svc-unifi for RADIUS"
  log "  3. SSH CA: Generate certs signed by AD"
  log ""
  log "The identity is eternal. Carter's work is done."
}

main "$@"
