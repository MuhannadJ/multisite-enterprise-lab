# INC-12 — Wireless rollout defects (a recurring omission class)

| | |
|---|---|
| **Severity** | P2 — wireless clients could not complete login or obtain an address at several sites |
| **Type** | Unplanned defects in the build (not planted) |
| **Build days** | Sept 27–30 |
| **Devices** | WLC, AP1–AP4, DC/Branch distribution and access switches, DHCP server |
| **Status** | Resolved except AP selection: with the final AP range the phones associate, but some join an AP at another site (see [known limitations](../docs/known-limitations.md)) |

## Summary

Bringing up VLAN 50 (wireless clients) and VLAN 99 (AP management and discovery) at four sites produced a series of separate defects. Individually each was small. The pattern was the real finding: **the same class of step was missed at different sites**, and each omission surfaced only when a real client reached that site.

## Defects found

| # | Defect | Where | Fix |
|---|---|---|---|
| 1 | WLAN mapped to the management interface instead of the VLAN 50 interface | WLC | Re-mapped the WLAN to the client VLAN |
| 2 | RADIUS port mismatch between the WLC and the AAA server | WLC / server | Aligned the authentication port |
| 3 | FlexConnect local authentication: disabled to make the WLC the RADIUS client, which then left only the HQ AP able to authenticate clients | WLAN | Local authentication **re-enabled** and kept on ([design decisions](../docs/design-decisions.md)) |
| 4 | Missing DHCP pools for the wireless and management VLANs | DHCP server | Pools added per site, including the controller address for AP discovery |
| 5 | Missing `ip helper-address` on the DC VLAN 50 SVIs | DC_CORE/DIST_SW1/SW2 | Added |
| 6 | VLAN 50 subnet not advertised into OSPF, so DHCP replies had no return route to the relay | All sites; Branch B again on Sept 30 after being assumed correct | `network … area N` added per site |
| 7 | AP-facing port native VLAN 999 instead of 99 | HQ, Branch B, then DC (AP1) and Branch A (AP3) | Native VLAN set to 99 |
| 8 | Sticky port-security MAC learned under the old native VLAN caused a violation once traffic reclassified into VLAN 99 | BR_A_SW1 Fa0/2 | Cleared the sticky MAC and cycled the port; same step applied preemptively at the DC |
| 9 | DHCP snooping dropped relayed requests already carrying Option 82 on an untrusted port | BR_A_SW2 | `no ip dhcp snooping information option` on the Branch switches; trust set on each Port-channel member |
| 10 | Clients preferring a farther AP over the nearest | All APs | Dot11Radio0 coverage range lowered to about 20–30 m. At that range most phones then failed to associate at all, so it was raised to 100 m. At 100 m the phones associate, but some association lines run to an AP at another site. **Not resolved**; cause not isolated |
| 11 | VLAN 50 STP/HSRP split-brain at HQ | HQ | See [INC-10](INC-10-hq-vlan50-split-brain.md) |
| 12 | Root Guard preventing root election on VLAN 99 | DC | See [INC-11](INC-11-dc-root-guard-blocking-root-election.md) |

## Root cause of the pattern

No single checklist was run consistently across all four sites when VLAN 50 and VLAN 99 were stood up, so different individual steps were missed at different sites.

## Verification

All four APs joined the WLC (4 total, 4 up, 0 down). WPA2-Enterprise client login, DHCP and OSPF-routed replies were confirmed at HQ (laptop and phone), the DC and Branch B. At Branch A a phone placed next to AP3 obtained a lease from the Branch A VLAN 50 pool (10.30.50.123, Oct 6; [V9–V10](../docs/verification-report.md#v9v10--wireless)). At the final AP range (100 m) the phones associate (operator-observed), but the AP each phone joined was not confirmed in the WLC. The running-configs support the cross-site picture: the sticky MAC tables on the AP-facing ports at HQ, DC and Branch B share 6 to 8 of the same client MAC addresses with each other, which is consistent with phones having associated with APs at more than one site.

## Prevention — per-site VLAN rollout checklist

Run this in full for every site, in this order, and tick it off before any client test:

1. VLAN exists on every switch in the path; trunks allow it; Port-channel **and** members agree.
2. SVI up with the HSRP group, priority and `preempt` per the design table.
3. STP root priority set per the design table.
4. `ip helper-address 10.20.20.10` on the SVI of every gateway switch.
5. `network` statement for the subnet in the site's OSPF area.
6. DHCP pool exists with the correct gateway and options.
7. AP-facing ports: native VLAN 99, allowed VLANs, port-security sized and cleared of stale MACs.
8. DHCP snooping: trust on uplinks and Port-channel members; Option 82 handling consistent.
9. `DC-SERVER-ACCESS` permits the relay, DNS and RADIUS sources for the new subnet.
10. Test from a **real client**, not only from an AP join.
