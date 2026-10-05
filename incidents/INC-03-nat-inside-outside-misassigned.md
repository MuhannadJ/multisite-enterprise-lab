# INC-03 — DC edge NAT inside/outside misassigned

| | |
|---|---|
| **Severity** | P2 — partial NAT failure at the DC edge |
| **Type** | Planted fault, found by NOC-style diagnosis |
| **Build day** | Day 3 (WAN, NAT and VPN) |
| **Devices** | DC-EDGE-RTR1 (Gi0/0/0, Gi0/0/1, Gi0/0/2) |
| **Status** | Resolved |

## Reported symptom

Address translation at the DC edge did not apply consistently: only traffic entering through one of the two LAN-facing interfaces was affected.

## Impact

The DC edge is dual-homed to both DC core/distribution switches (Gi0/0/0 to SW1, Gi0/0/1 to SW2). Traffic arriving on one of them was translated; traffic arriving on the other was not. A single-path test would have passed or failed depending on which switch was carrying it.

## Diagnosis

1. Noted that the fault depended on the path, not on the source subnet, which pointed at interface-level NAT roles rather than the NAT ACL.
2. Compared the NAT role on all three interfaces (`show running-config` for the interfaces, `show ip nat statistics`). Gi0/0/0 was `ip nat inside` and Gi0/0/2 was `ip nat outside` as designed, but Gi0/0/1 was also marked `ip nat outside`.

## Root cause

`ip nat outside` was configured on DC-EDGE-RTR1 Gi0/0/1 instead of `ip nat inside`. NAT translates only traffic that enters an inside interface, so traffic arriving on Gi0/0/1 was never translated.

## Fix

```
interface GigabitEthernet0/0/1
 no ip nat outside
 ip nat inside
```

## Verification

Both LAN-facing interfaces show `ip nat inside` in the saved configuration (Gi0/0/0, Gi0/0/1), and Gi0/0/2 is the only `ip nat outside` interface.

## Prevention

- On any router with more than one LAN-facing interface, check **every** interface's NAT role, not just the first.
- A fault that depends on the path rather than the source is an interface-level fault until proven otherwise.
