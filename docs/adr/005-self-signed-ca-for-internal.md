# ADR 005: Self-Signed CA for Internal Services

## Status
Accepted

## Context
RYLAN internal services require TLS encryption. Public CA certificates are not practical for internal-only endpoints. A self-signed CA provides control and flexibility for issuing and revoking certificates.

## Decision
Deploy a self-signed CA for all internal TLS endpoints. CRLDistributionPoints will be published via nginx for certificate revocation.

## Consequences
- Full control over certificate issuance and revocation
- No dependency on external CA providers
- CRL endpoint available for automated revocation
