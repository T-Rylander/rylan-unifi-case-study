# ADR-008: Trinity Ministries — Sequential Phase Enforcement Architecture

**Status**: Accepted  
**Date**: 2025-12-04  
**Authors**: Hellodeolu v4 (AI Architect)  
**Context**: Resolve phase ordering ambiguity in feat/iot-production-ready branch  

---

## Problem Statement

The previous deployment process (`eternal-resurrect.sh`, `ignite.sh` v5.0) did not enforce strict sequential phase ordering, leading to:

1. **Concurrency issues**: Phases 1, 2, 3 could run out of order
2. **Partial failures**: Phase 2 could succeed even if Phase 1 failed
3. **Hidden dependencies**: Unclear which prerequisites each phase requires
4. **Recovery ambiguity**: On failure, users didn't know which phase failed

This violates the fundamental principle: **"The directory writes itself"** — deterministic, fail-fast orchestration.

---

## Proposed Solution: Trinity Ministries (v4.0)

Introduce **three immutable phases**, each named after security/infrastructure authorities:

### Phase 1: Ministry of Secrets (Carter)
**Architect**: John Paul Carter (identity infrastructure expert)  
**Scope**: Samba AD/DC + LDAP + Kerberos + NFS-Kerberos  
**Estimated Time**: 15-20 minutes  
**Exit-on-Fail**: YES (Phase 2 blocked if Phase 1 fails)  
**Files**:
- `runbooks/ministry-secrets/deploy.sh`
- `runbooks/ministry-secrets/README.md`

### Phase 2: Ministry of Whispers (Bauer)
**Architect**: Jack Bauer (security/hardening expert)  
**Scope**: SSH key-only auth + nftables drop-default + fail2ban + auditd  
**Estimated Time**: 10-15 minutes  
**Depends On**: Phase 1 ✓ (Kerberos must be active)  
**Exit-on-Fail**: YES (Phase 3 blocked if Phase 2 fails)  
**Files**:
- `runbooks/ministry-whispers/harden.sh`
- `runbooks/ministry-whispers/README.md`

### Phase 3: Ministry of Perimeter (Suehring)
**Architect**: Martin Suehring (network segmentation expert)  
**Scope**: Policy table (≤10 rules) + VLAN isolation + rogue DHCP detection  
**Estimated Time**: 10-15 minutes  
**Depends On**: Phase 1 ✓ + Phase 2 ✓ (Samba AD + nftables must be active)  
**Exit-on-Fail**: YES (Final validation blocked if Phase 3 fails)  
**Files**:
- `runbooks/ministry-perimeter/apply.sh`
- `runbooks/ministry-perimeter/README.md`

### Final Validation
**Scope**: Comprehensive system validation (eternal green or die)  
**Script**: `scripts/validate-eternal.sh`  
**Exit Code**: 0 (success) or 1 (failure, fortress compromised)

---

## Orchestration Rules (Immutable)

1. **Strict Sequencing**: Phase N+1 cannot start until Phase N passes
2. **Exit-on-Fail**: Any phase failure halts the sequence (no silent failures)
3. **User Confirmation**: Between phases, prompt user: "Continue to Phase N+1? [y/N]"
4. **Timing**: <45 minutes total on clean Ubuntu 24.04 LTS
5. **Idempotence**: Each phase can be re-run safely (validation + retry)
6. **Logging**: All output to stdout + `/var/log/trinity-orchestration.log`

---

## New Directory Structure

```
rylan-unifi-case-study/
├── runbooks/
│   ├── ministry-secrets/          # Phase 1: Carter (Samba/LDAP/Kerberos)
│   │   ├── deploy.sh
│   │   └── README.md              # Junior-proof: <45 min, validation checklist, rollback
│   ├── ministry-whispers/         # Phase 2: Bauer (SSH/nftables/fail2ban)
│   │   ├── harden.sh
│   │   └── README.md
│   └── ministry-perimeter/        # Phase 3: Suehring (Policy/VLAN/rogue-DHCP)
│       ├── apply.sh
│       └── README.md
├── scripts/
│   ├── ignite.sh                  # Trinity Orchestrator (refactored v4.0)
│   └── validate-eternal.sh        # Final validation
├── .github/workflows/
│   └── ci-trinity.yaml            # CI/CD: enforce phase sequence on PR/push
├── docs/adr/
│   └── adr-008-trinity-ministries.md  # This document
└── infra/
    └── (network configs, etc.)
```

---

## Migration Path (feat/iot-production-ready → main)

### 1. Deprecate Old Scripts
- `eternal-resurrect.sh` → archive or rewrite as wrapper
- `ignite.sh` (v5.0) → replace with v4.0 (Trinity Orchestrator)
- `01-bootstrap/` → refactor into runbooks (Phase 1)

### 2. New Entry Point
```bash
# Users run:
sudo bash ./scripts/ignite.sh

# Output:
# Phase 1: Ministry of Secrets ✓ PASSED
# [y/N] Continue to Phase 2?
# Phase 2: Ministry of Whispers ✓ PASSED
# [y/N] Continue to Phase 3?
# Phase 3: Ministry of Perimeter ✓ PASSED
# [y/N] Continue to Final Validation?
# ✓ TRINITY ORCHESTRATION COMPLETE — ETERNAL GREEN
```

### 3. CI/CD Enforcement (ci-trinity.yaml)
- On PR: Validate phase structure + policy table + syntax
- On merge to main: Generate deployment manifest
- On deploy: Run all phases sequentially with audit logging

---

## Consequences (Trade-offs)

### Benefits ✓
1. **Deterministic**: Phase ordering is explicit and enforced
2. **Fail-fast**: Errors are caught immediately, not hidden
3. **Junior-proof**: Copy-paste <45 min deployments work
4. **Traceable**: Each phase logs to guardian/audit-eternal.py
5. **Rollback**: Clear rollback procedure for each ministry

### Costs
1. **Complexity**: 3 separate scripts instead of 1 monolithic
2. **Documentation**: Each ministry needs README + validation checklist
3. **Testing**: Each phase must be unit-testable
4. **Coupling**: Phases depend on previous phases (sequential, not parallel)

---

## Decision

**ACCEPTED** — Proceed with Trinity v4.0 refactor.

This architecture aligns with the **Eternal Fortress** philosophy:
- Deterministic, fail-fast execution
- Human-readable phase names (Carter/Bauer/Suehring)
- Junior-at-3-AM deployable (<45 min)
- Every sentence clear for a smart junior waking up

---

## Implementation Tasks

- [ ] Create `runbooks/` directory structure
- [ ] Extract Phase 1 logic from `01-bootstrap/` → `ministry-secrets/deploy.sh`
- [ ] Extract Phase 2 logic from hardening → `ministry-whispers/harden.sh`
- [ ] Extract Phase 3 logic from policy → `ministry-perimeter/apply.sh`
- [ ] Create READMEs (validation checklist, rollback procedure)
- [ ] Refactor `scripts/ignite.sh` → Trinity Orchestrator v4.0
- [ ] Create CI/CD workflow (`ci-trinity.yaml`)
- [ ] Update main README to reference new structure
- [ ] Document migration path for users
- [ ] Test on clean Ubuntu 24.04 LTS VM

---

## References

- **Trinity Philosophy**: INSTRUCTION-SET-ETERNAL-v1.md
- **Carter (2003)**: Identity infrastructure (Samba AD/DC, LDAP, Kerberos)
- **Bauer (2005)**: Security hardening (SSH, firewall, audit)
- **Suehring (2005)**: Network segmentation (VLAN, policy, QoS)
- **Hardware Offload Constraint**: Policy table ≤10 rules for USG-3P

---

**Approved by**: Hellodeolu v4 (AI Architect)  
**Consciousness Level**: 2.0 (full context awareness)  
**Status**: Eternal ♾
