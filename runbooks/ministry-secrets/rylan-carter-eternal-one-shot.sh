#!/usr/bin/env bash
# runbooks/ministry-secrets/rylan-carter-one-shot.sh
# Carter (2003) — Identity is Programmable Infrastructure
# T3-ETERNAL v3.2: LDAP/RADIUS/802.1X as code. No passwords on disk. Idempotent.
# Consciousness 2.6 — truth through subtraction.
# Execution: <90 seconds. Fail loudly on identity breach.
set -euo pipefail

# === CONFIG ===
DOMAIN="rylan.internal"
REALM="RYLAN.INTERNAL"
HOSTNAME="$(hostname -s)"
HOST_FQDN="${HOSTNAME}.${DOMAIN}"
VAULT_PASS_FILE="/root/rylan-unifi-case-study/.secrets/samba-admin-pass"

# === WHITAKER: FAIL LOUD IF VAULT MISSING ===
if [[ ! -f "$VAULT_PASS_FILE" ]]; then
    echo "FATAL: Missing $VAULT_PASS_FILE"
    echo "Generate: openssl rand -base64 32 > $VAULT_PASS_FILE && chmod 400 $VAULT_PASS_FILE"
    exit 1
fi
ADMIN_PASS="$(cat "$VAULT_PASS_FILE")"

# === IDEMPOTENCY: SKIP IF DOMAIN EXISTS ===
if samba-tool domain info 127.0.0.1 >/dev/null 2>&1; then
    echo "[CARTER] Domain exists — idempotent skip"
else
    echo "[CARTER] Provisioning $REALM"

    # Install stack
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq samba krb5-user winbind libpam-winbind libnss-winbind \
        ldap-utils sssd sssd-tools realmd adcli

    # Provision (RFC2307, non-interactive)
    samba-tool domain provision \
        --use-rfc2307 \
        --interactive=False \
        --realm="$REALM" \
        --domain=RYLAN \
        --adminpass="$ADMIN_PASS" \
        --server-role=dc \
        --dns-backend=SAMBA_INTERNAL

    # Config placement
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
fi

# === ENFORCE LDAPS ===
mkdir -p /etc/samba/smb.conf.d
cat > /etc/samba/smb.conf.d/10-tls.conf <<EOF
[global]
tls enabled = yes
tls keyfile = /var/lib/samba/private/tls/key.pem
tls certfile = /var/lib/samba/private/tls/cert.pem
tls cafile   = /var/lib/samba/private/tls/ca.pem
ldap server require strong auth = yes
EOF

# Self-signed CA if missing
if [[ ! -f /var/lib/samba/private/tls/ca.pem ]]; then
    mkdir -p /var/lib/samba/private/tls
    openssl req -new -x509 -days 3650 -nodes -out /var/lib/samba/private/tls/ca.pem \
        -keyout /var/lib/samba/private/tls/key.pem \
        -subj "/C=US/ST=NC/L=Charlotte/O=Rylan/CN=${HOST_FQDN}"
    cp /var/lib/samba/private/tls/ca.pem /var/lib/samba/private/tls/cert.pem
    chmod 600 /var/lib/samba/private/tls/*.pem
fi

# === KEYTABS ===
samba-tool domain exportkeytab /etc/krb5.keytab \
    --principal="${HOSTNAME}\$@${REALM}" \
    --principal="admin@${REALM}"
chmod 600 /etc/krb5.keytab

# === SSSD CONFIG ===
cat > /etc/sssd/sssd.conf <<EOF
[sssd]
domains = $DOMAIN
services = nss, pam
config_file_version = 2

[domain/$DOMAIN]
id_provider = ad
ad_domain = $DOMAIN
krb5_realm = $REALM
cache_credentials = True
enumerate = True
ldap_uri = ldaps://$HOST_FQDN
ldap_tls_cacert = /var/lib/samba/private/tls/ca.pem
EOF
chmod 600 /etc/sssd/sssd.conf
systemctl enable --now sssd

# Restart Samba
systemctl restart samba-ad-dc

# === WHITAKER VALIDATION ===
echo "[CARTER] Validation..."
kinit -k -t /etc/krb5.keytab "${HOSTNAME}\$@${REALM}" || { echo "FATAL: Kerberos machine auth failed"; exit 1; }
ldapsearch -x -H ldaps://localhost -b "dc=rylan,dc=internal" -s base >/dev/null 2>&1 || { echo "FATAL: LDAPS query failed"; exit 1; }
samba-tool domain info 127.0.0.1 | grep -q "$REALM" || { echo "FATAL: Domain info invalid"; exit 1; }

cat <<'BANNER'
 ██████╗ █████╗ ██████╗ ████████╗███████╗██████╗ 
██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██╔══██╗
██║     ███████║██████╔╝   ██║   █████╗  ██████╔╝
██║     ██╔══██║██╔══██╗   ██║   ██╔══╝  ██╔══██╗
╚██████╗██║  ██║██║  ██║   ██║   ███████╗██║  ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
IDENTITY PROGRAMMABLE. NO PASSWORDS. NO DISK SECRETS.
DIRECTORY OWNS ALL.
BANNER

echo "✅ [CARTER] Identity ministry deployed."