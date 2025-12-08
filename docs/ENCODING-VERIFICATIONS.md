# Encoding Verifications

This file documents verified UTF-8 + LF encodings for critical scripts.

- `runbooks/ministry-secrets/rylan-carter-eternal-one-shot.sh` — Verified 2025-12-08 UTC
  - Encoding: UTF-8 (no BOM)
  - Line endings: LF (Unix)
  - File size: 4310 bytes
  - Verification method: raw byte inspection on Windows PowerShell (`[System.IO.File]::ReadAllBytes`) — checked for BOM bytes `239 187 191` and CR (13) presence.

If you need more files validated, add them to this document and request verification.
