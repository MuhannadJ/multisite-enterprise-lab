# INC-05 — Wrong DHCP helper address on HQ-DIST-SW2 (Lab ticket 1)

| | |
|---|---|
| **Severity** | P3 — latent; no user impact while both HQ distribution switches are up |
| **Type** | Planted fault, found by NOC-style diagnosis |
| **Lab ticket** | 1 |
| **Build day** | Day 5 (services and wireless) |
| **Devices** | HQ-DIST-SW2 (VLAN 10 SVI) |
| **Status** | Resolved |

## Reported symptom

HQ DHCP clients fell back to a link-local 169.254.x.x address, but only under one condition: with HQ-DIST-SW1 down.

## Impact

None while HQ-DIST-SW1 (the HSRP Active gateway) is up, because both distribution switches relay DHCP independently and SW1 relays correctly. DHCP breaks for VLAN 10 only when SW1 is down and SW2 is the only relay.

## Diagnosis

1. Scope: the failure followed *which gateway switch was relaying for the VLAN*, not the user or the access switch. That points at the per-gateway DHCP relay, not the DHCP server or the pool.
2. Compared `ip helper-address` on VLAN 10 of HQ-DIST-SW1 and HQ-DIST-SW2 (`show running-config | include helper-address`).
3. SW1 pointed at 10.20.20.10 (the DHCP/DNS server). SW2 pointed at **10.20.20.101**, an address that does not exist.

## Root cause

HQ-DIST-SW2 VLAN 10 had `ip helper-address 10.20.20.101` instead of `10.20.20.10`. A typo in the last octet; the relay forwarded DHCP broadcasts to a non-existent host.

## Fix

On IOS, helper addresses accumulate, so the wrong one must be removed first:

```
interface Vlan10
 no ip helper-address 10.20.20.101
 ip helper-address 10.20.20.10
```

## Verification

`show running-config | include helper-address` on both HQ distribution switches shows only 10.20.20.10 on VLAN 10 (and VLAN 50 and 99).

## Prevention

- When a service works for some users and not others on one VLAN, compare the **redundant gateway pair** line by line; redundancy hides one-sided faults.
- Dormant faults on the standby device are only found by comparing peers or by failing over, so compare configs of HSRP peers as a routine check.
