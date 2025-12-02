# ADR 004: PEAP-MSCHAPv2 over EAP-TLS

## Status
Accepted

## Context
RYLAN requires secure wireless authentication for trusted devices. PEAP-MSCHAPv2 is widely supported and integrates with Samba AD for user credentials. EAP-TLS is considered, but device certificate management is not feasible for all endpoints.

## Decision
Implement PEAP-MSCHAPv2 for 802.1X wireless authentication, backed by Samba AD. EAP-TLS is reserved for future expansion if device certificate management becomes practical.

## Consequences
- Immediate compatibility with most enterprise devices
- Centralized user management via Samba AD
- Device certificate management deferred
