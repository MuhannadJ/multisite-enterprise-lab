# INC-01 — HSRP virtual-IP mismatch, Branch A VLAN 99

| | |
|---|---|
| **Severity** | P2 — partial loss of gateway service for the Branch A management VLAN |
| **Type** | Planted fault, found by NOC-style diagnosis |
| **Build day** | Day 2 (L3 core and redundancy) |
| **Devices** | BR_A_SW1, BR_A_SW2 (VLAN 99 HSRP group 99) |
| **Status** | Resolved; one follow-up decision recorded below |

## Reported symptom

Branch A management VLAN (VLAN 99) unreachable beyond its own subnet; the default gateway did not respond.

## Impact

Devices in 10.30.99.0/24 had no working gateway, so nothing outside the subnet was reachable.

## Diagnosis

1. Scope first: the symptom was confined to VLAN 99 at Branch A, which pointed at the VLAN 99 SVI or its HSRP group rather than routing or the WAN.
2. `show standby brief` on both switches for group 99: the two switches listed **different virtual IPs** for the same group.
3. The log on the standby side carried `%HSRP-4-DIFFVIP1`, which IOS raises when a hello arrives for the same group with a different virtual IP.

## Root cause

BR_A_SW2 had `standby 99 ip 10.30.99.10` while BR_A_SW1 used the documented convention (.1). Two switches in one HSRP group with different VIPs do not form an Active/Standby pair; each hello from the peer is rejected and logged.

## Fix

Both switches were made to advertise the same VIP, which restored gateway service. In the saved configs both now use **10.30.99.10**.

## Verification

`show standby brief` on both switches shows one VIP for group 99, one Active and one Standby; the `%HSRP-4-DIFFVIP1` messages stop.

## Follow-up

The end state uses **.10**, while every other VLAN and site uses the convention **VIP = .1**. Either document Branch A VLAN 99 as an intentional exception (done in [addressing.md](../docs/addressing.md#5-hsrp-and-stp)) or re-address both switches to .1 and update the VLAN 99 DHCP pool's default router for that site to match.

## Prevention

- Configure the VIP once from the design table and paste the same line on both peers.
- After any HSRP change, run `show standby brief` on **both** peers and compare, and check the log for `DIFFVIP`.
- Treat a convention exception as a finding: either fix it or write it down.
