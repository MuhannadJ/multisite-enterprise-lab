# Device configurations

Sanitized `show running-config` exports of all 22 IOS devices, one file per device, named `<hostname>.txt` (a `/` in a hostname becomes `-`, so `DC_CORE/DIST_SW1` is `DC_CORE-DIST_SW1.txt`).

| Site | Devices |
|---|---|
| HQ (8) | HQ_CORE_RTR1, HQ_CORE_RTR2, HQ_EDGE_RTR1, HQ-DIST-SW1, HQ-DIST-SW2, HQ_ACC_SW1, HQ_ACC_SW2, HQ_ACC_SW3 |
| DC (5) | DC-EDGE-RTR1, DC_CORE/DIST_SW1, DC_CORE/DIST_SW2, DC_ACC_SW1, DC_ACC_SW2 |
| WAN (3) | ISP-RTR1, ISP_RTR2, INET_RTR1 |
| Branch A (4) | BR_A_RTR1, BR-A-RTR2, BR_A_SW1, BR_A_SW2 |
| Branch B (2) | BR_B_RT1, BR_B_SW1 |

Not included: the WLC configuration and the three server configurations (DHCP/DNS, AAA, Syslog/NTP). Packet Tracer does not export these as text; their relevant settings are documented in [`../docs/addressing.md`](../docs/addressing.md).

## What is redacted

`scripts/sanitize-configs.sh` replaces pre-shared keys, TACACS+/RADIUS keys, SNMP community strings, `enable secret` and `username … secret` hashes with `<REDACTED>`. IP addressing, ACLs, routing and all other settings are unchanged. All values were lab-only.

## How these were produced

```
# on each device
end
write
show running-config        # copy the output into <hostname>.txt in a folder outside the repo

# on the workstation
scripts/sanitize-configs.sh raw-exports/ configs/
```

The script refuses to finish cleanly if anything that looks like a secret survives.

**SVI ACL bindings do not appear in these files.** `DATA-IN` and `DC-SERVER-ACCESS` are defined in the configs, but after a `.pkt` reload this image does not list the `ip access-group` line in the running-config, even when the ACL is enforcing. Enforcement is evidenced by counters and pings in [V6](../docs/verification-report.md#v6--data-in) and by [runbook R1](../docs/runbooks.md#r1--re-apply-svi-acl-bindings-after-loading-the-pkt).
