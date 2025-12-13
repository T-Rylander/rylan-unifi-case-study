# Operations Guide

## Bootstrap Phase
1. Install controller (`01_bootstrap/install-unifi-controller.sh`).
2. Run adoption script once devices appear (`adopt_devices.py`).
3. Import baseline VLAN stubs (`vlan-stubs.json`) if needed.

## Declarative Apply
Use `02_declarative_config/apply.py --dry-run` to view drift then apply VLANs.
Policy routes and QoS configured manually referencing `policy-table.yaml` and `qos-smartqueue.yaml`.

## Validation
Scripts under `03_validation_ops/`:
- `validate-isolation.sh` zero-trust enforcement checks.
- `phone_reg_test.py` SIP peer health placeholder.
- `backup-cron.sh` scheduled archival.

## DR / Recovery
Restore latest `unifi-*.tgz` to `/var/lib/unifi/data` and restart service.
