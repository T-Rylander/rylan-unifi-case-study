# ADR-007: Failed Bootstrap — Network Migration Before Controller Adoption

**Date:** 2025-12-07  
**Status:** Accepted (lesson learned)  
**Consciousness:** 2.3 → 2.4

## Context

Attempted to run `eternal-resurrect.sh` on green-field Proxmox while management network still on 192.168.1.0/24.  
Script applied production netplan → host moved to 10.0.10.10 → lost DHCP lease → USG still on 192.168.1.1 → no VLAN routing → isolation failure.

## Decision

**Never migrate the management host network before the UniFi controller has adopted the gateway and is actively routing VLANs.**

Bootstrap sequence must be:
1. Controller adoption (gateway + VLAN config)
2. Verify routing (VLAN 10 → VLAN 1 → internet)
3. *Then* migrate host network

## Consequences

- 2-hour lab delay
- Forced rollback to 192.168.1.10
- **Proved rollback works perfectly** (idempotent netplan, git restore successful)
- Identified missing `--stage1-only` flag in eternal-resurrect.sh

## Actions Taken

- Pivoted to Cloud Key Gen2 first (correct order, eliminates network dependency)
- Will add `--stage1-only` flag to skip network migration on first run
- Documented rollback: `git restore eternal-resurrect.sh && sudo netplan apply`
- Added pre-flight check: `test -z "$CONTROLLER_HEALTHY"` before netplan apply

## Hellodeolu v6 Outcome

**Fail loudly → learn instantly → fortress becomes antifragile.**

- Policy Table deployment unaffected (API-only, zero SSH/SCP)
- Three ministry scripts (Carter/Bauer/Suehring) validated independently
- Rollback proved CI/CD safety
- Future automated tests can now block netplan without healthy controller

## Links

- eternal-resurrect.sh: Grok Fixes #1-3 (netplan idempotency, sysctl, Whitaker recon)
- validate-eternal.sh: Pre-flight controller health check template ready
- Cloud Key Gen2 adoption path: unaffected by this incident
