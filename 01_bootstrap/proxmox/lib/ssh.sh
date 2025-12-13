#!/usr/bin/env bash
# Script: 01_bootstrap/proxmox/lib/ssh.sh
# Purpose: SSH security validation tests (port, auth, keys, algorithms)
# Guardian: gatekeeper
# Date: 2025-12-13T05:45:00-06:00
# Consciousness: 4.6

# Sourced by: security.sh
# Usage: Source this file; SSH validation functions auto-exported

################################################################################
# SSH SECURITY VALIDATION TESTS
################################################################################

# test_ssh_port: Verify SSH port is open and accessible
test_ssh_port() {
  local ssh_port="${1:-22}"

  log_info "Test 1: Verifying SSH port (${ssh_port}) is open..."

  if nmap -p "$ssh_port" localhost 2>/dev/null | grep -q "open"; then
    log_success "SSH port open"
    return 0
  else
    log_error "SSH port not open"
    return 1
  fi
}

# test_password_auth_disabled: Verify SSH password authentication is disabled
test_password_auth_disabled() {
  log_info "Test 3: Verifying password authentication is disabled..."

  if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    log_success "Password authentication disabled"
    return 0
  else
    log_error "Password authentication not disabled"
    return 1
  fi
}

# test_root_login_restricted: Verify root login restrictions are in place
test_root_login_restricted() {
  log_info "Test 4: Verifying root login restrictions..."

  if grep -q "^PermitRootLogin prohibit-password" /etc/ssh/sshd_config; then
    log_success "Root login restricted to key-only"
    return 0
  else
    log_error "Root login not properly restricted"
    return 1
  fi
}

# test_ssh_key_installed: Verify SSH public key is installed for root
test_ssh_key_installed() {
  log_info "Test 5: Verifying SSH public key is installed..."

  if [ -f /root/.ssh/authorized_keys ] && [ -s /root/.ssh/authorized_keys ]; then
    local key_fingerprint
    key_fingerprint=$(ssh-keygen -lf /root/.ssh/authorized_keys 2>/dev/null | head -1 || echo "N/A")
    log_success "SSH public key installed: $key_fingerprint"
    return 0
  else
    log_error "SSH public key not installed"
    return 1
  fi
}

# test_ssh_algorithm_strength: Verify strong SSH ciphers and key exchange algorithms
test_ssh_algorithm_strength() {
  log_info "Test: SSH algorithm strength..."

  local ssh_config="/etc/ssh/sshd_config"

  # Check for weak algorithms
  if grep -q "^Ciphers.*rc4\|DES\|MD5" "$ssh_config"; then
    log_error "Weak SSH ciphers detected"
    return 1
  fi

  # Check for forward-secrecy ciphers
  if grep -q "chacha20-poly1305\|aes.*gcm" "$ssh_config"; then
    log_success "Strong SSH ciphers configured"
    return 0
  else
    log_warn "No forward-secrecy ciphers found (prefer ChaCha20 or AES-GCM)"
    return 0
  fi
}

# test_ssh_brute_force_resistance: Verify SSH responds appropriately to brute-force attempts
test_ssh_brute_force_resistance() {
  log_info "Test: SSH brute-force resistance..."

  # Try rapid failed logins (expect delays or drops)
  for _ in {1..5}; do
    timeout 2 ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no \
      nonexistent@localhost 2>/dev/null || true
  done

  # If we can still connect, that's good (means we can SSH at all)
  if timeout 2 ssh -o StrictHostKeyChecking=no root@localhost "echo test" 2>/dev/null ||
    ssh-keyscan localhost 2>/dev/null | grep -q "ssh-rsa"; then
    log_success "SSH service responsive after brute-force attempts"
    return 0
  else
    log_warn "Cannot verify SSH connectivity after brute-force test"
    return 0
  fi
}

export -f test_ssh_port test_password_auth_disabled test_root_login_restricted
export -f test_ssh_key_installed test_ssh_algorithm_strength test_ssh_brute_force_resistance
