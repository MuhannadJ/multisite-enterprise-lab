# Verification report

This report records what was tested, how, and how strong the evidence is. Results are labelled:

- **Captured** — CLI output was pasted into the working session and reviewed against the expected behaviour.
- **Operator-observed** — the lab owner ran the test and reported the result; no output was reviewed.

Tests that failed or were inconclusive are included. Items with no evidence are listed at the end rather than left out.

## Summary

| ID | Test | Result | Evidence |
|---|---|---|---|
| V1 | Branch A primary WAN link down → IPsec tunnel carries traffic | Pass | Captured |
| V2 | Branch B primary WAN link down → IPsec tunnel carries traffic | Pass | Captured |
| V3 | HQ HSRP failover: control plane and preemption | Pass | Captured |
| V4 | HQ HSRP failover: data plane forwarding and ACL enforcement by the standby switch | Pass with platform caveat | Captured |
| V5 | `DC-SERVER-ACCESS` final state | Pass (`deny ip any any` = 0 hits) | Captured |
| V6 | `DATA-IN` blocks VLAN 10 → VLAN 99 | Pass | Captured at HQ-DIST-SW1; blocked ping at HQ |
| V7 | DHCP relay and lease across HQ, Branch A, Branch B | Pass after INC-05/06/07 | Operator-observed |
| V8 | TACACS+ authentication on the two pilot routers | Pass, logins land at `>` | Operator-observed |
| V9 | Wireless: AP join (4 of 4) | Pass | Operator-observed (WLC monitor summary) |
| V10 | Wireless: WPA2-Enterprise client login | Pass at HQ, DC, Branch A, Branch B | Operator-observed (Branch A: phone IP-configuration screenshot reviewed) |
| V11 | VTY ACL denies non-MGMT sources | Pass on HQ_EDGE_RTR1 and HQ-DIST-SW1 | Operator-observed (deny counters rising, SSH refused) |
| V12 | GRE-over-IPsec stuck-SA fault and recovery | Reproduced twice, recovered once | Captured |

---

## V1 — Branch A WAN failover

**Objective.** With the primary ISP link down, Branch A traffic to the DC must move onto the GRE-over-IPsec tunnel to HQ and continue to reach the servers.

**Method.** Shut BR_A_RTR1 Gi0/0/0 (link to ISP-RTR1). Wait for OSPF to converge (about 40 seconds). Trace from Branch A to 10.20.20.10 and read the IPsec counters on BR-A-RTR2. Restore the link.

**Evidence.**
- Traceroute hops after the failure: 10.30.50.3, 10.30.2.2, 172.16.100.1, 172.16.1.2, 172.16.0.2, 172.16.2.1, 10.20.3.1, 10.20.20.10. The path crosses BR-A-RTR2, then the HQ end of Tunnel1 (172.16.100.1), then ISP-RTR1, ISP_RTR2 and the DC edge.
- OSPF routing-table entry used the tunnel path at metric 1007.
- IPsec counters on BR-A-RTR2 (local 192.168.200.5 ↔ 192.168.200.1): encaps 84 → 129, decaps 118 → 178.

**Result.** Pass.

**Caveat.** The two counter captures show different outbound SPIs, so they are not guaranteed to belong to a single SA. The reliable evidence is the traceroute path and the routing-table change.

## V2 — Branch B WAN failover

**Method.** Shut BR_B_RT1 Gi0/0/2 (link to ISP_RTR2). Trace from BR_B_SW1 and read the IPsec counters on BR_B_RT1. Restore the link.

**Evidence.**
- Route before: next hop 172.16.4.2 (ISP_RTR2), metric 4. Route after: next hop 172.16.101.1 (HQ end of Tunnel2), metric 1005.
- IPsec counters on BR_B_RT1 (local 192.168.200.9 ↔ 192.168.200.1): encaps 35 → 125, decaps 50 → 168. SPIs and connection IDs were unchanged and the remaining SA lifetime moved 3174 → 2981 s, so this is the same SA carrying the extra traffic.
- Traceroute after: 10.40.1.2, 172.16.101.1, 172.16.1.2, 172.16.0.2, 172.16.2.1, 10.20.3.1, 10.20.20.10.

**Result.** Pass. BR_B_RT1 also remained an OSPF ABR through the tunnel (Area 0 over Tunnel1).

## V3 — HQ HSRP: control plane and preemption

**Result.** Pass (captured `show standby brief`). The standby switch became Active when the Active switch's SVI was shut, and the original Active switch regained the role on restore because of `preempt`.

## V4 — HQ HSRP: data plane

**Objective.** Show that when HQ-DIST-SW1 stops being the gateway, HQ-DIST-SW2 actually forwards user traffic and enforces `DATA-IN`.

**What happened first (inconclusive).** Shutting HQ-DIST-SW1's VLAN 10 SVI changed HSRP state, but SW1 **kept forwarding and kept enforcing its ACL**: its `DATA-IN` deny counters kept rising while SW2 was Active. This was reproduced twice. The "destination unreachable" replies seen during the test came from SW1's own SVI addresses, which explained an earlier unexplained observation. PC0's ARP entry for the gateway stayed at the HSRP virtual MAC (0000.0c07.ac0a for group 10) throughout, so a stale ARP entry was ruled out.

**Method that worked.** Isolate SW1 at port level: `interface range fastethernet 0/1 - 5` → `shutdown`. This removes SW1 from the user-facing Layer 2 domain (three access links and the two Port-channel members) while leaving its routed core links up.

**Evidence.**
- SW2's `DATA-IN` deny line for 10.20.99.0 showed 4 matches, so SW2 was forwarding and enforcing the ACL.
- Ping from the HQ PC to 10.20.20.10 succeeded 4/4.
- CDP map used to choose the ports: Fa0/1 → HQ_ACC_SW1, Fa0/2 → HQ_ACC_SW2, Fa0/3 → HQ_ACC_SW3, Po1 (Fa0/4–5) → HQ-DIST-SW2, Fa0/6 → HQ_CORE_RTR1, Fa0/7 → HQ_CORE_RTR2.

**Result.** Pass, with the caveat that this simulator does not stop an SVI from forwarding when the SVI is shut. The design's failover was tested; the simulator's SVI-shutdown shortcut is not a valid failover test.

## V5 — DC-SERVER-ACCESS final state

**Evidence.** `show access-lists DC-SERVER-ACCESS` on both DC_CORE/DIST switches: the final `deny ip any any` line showed **no matches** on either switch. Lines that matched traffic (SW1 / SW2): DHCP relay `bootps` 2 / 2, syslog from 10.0.0.0/8 52 / 56, NTP from 10.0.0.0/8 327 / 467, NTP from 172.16.0.0/16 140 / 114, ICMP `echo` 9 / 11.

**Zero-hit lines.** The DNS lines, both TACACS+ lines, all eight RADIUS lines, the 172.16.0.0/16 syslog line and the `echo-reply` line show no matches in the final capture. The operator reported those flows during testing, but they were **not captured in the final counters**, so this report does not claim counter evidence for them.

**Binding.** `show ip interface vlan 20` on this image reports "Outgoing access list is not set" even when the ACL is enforcing. The binding was confirmed from match counters and a Simulation Mode PDU trace (after a reload the running-config does not list SVI bindings on this image; see V6). See [INC-08](../incidents/INC-08-acls-configured-but-never-bound.md).

## V6 — DATA-IN

A PC at HQ (10.10.10.101) could ping the HQ MGMT gateway 10.10.99.1 before the ACL was bound and could not after. `show access-lists DATA-IN` on HQ-DIST-SW1 was captured with the permit line carrying a match count. The ACL is configured on BR_A_SW1, BR_A_SW2 and BR_B_SW1; counter evidence is captured for HQ-DIST-SW1 only.

**Re-test after a reload (Oct 4, HQ-DIST-SW1).** From a VLAN 10 PC, `tracert 10.20.99.2` showed first hop 10.10.10.2 (HQ-DIST-SW1). Before R1: `ping 10.20.99.2` succeeded 4/4 and every `DATA-IN` line, including `permit ip any any`, had no matches after a successful ping to 10.20.20.10. After R1 (`no ip access-group DATA-IN in`, `ip access-group DATA-IN in` on Vlan10): the ping returned "Destination host unreachable" from 10.10.10.2, and `show access-lists DATA-IN` showed 4 matches on the `deny … 10.20.99.0` line and 15 on `permit ip any any`. `show running-config | include ip access` listed only the ACL definitions (`include standby` on the same interface did list its lines), so the enforced binding is not visible in the config. Only the active gateway was tested; the standby switches and the other sites were not.

**Persistence check (Oct 4 to 5, HQ-DIST-SW1).** `write` was run after R1, then Packet Tracer was closed. After reopening the `.pkt` on Oct 5, `tracert 10.20.99.2` from a VLAN 10 PC (first hop 10.10.10.2) ran through to 10.20.3.1 in 7 hops and `show access-lists DATA-IN` showed no matches on any line. The binding had to be re-applied; saving did not preserve it.

## V7 — DHCP

First HQ lease: 10.10.10.101, gateway 10.10.10.1, DNS 10.20.20.10. Branch B leases failed until INC-06 was fixed, and HQ relay traffic was mistranslated until INC-07 was fixed. HQ-DIST-SW2's wrong helper (INC-05) is dormant while HQ-DIST-SW1 is up, because both switches relay independently.

## V8 — TACACS+

HQ_EDGE_RTR1 and BR_B_RT1 use `aaa authentication login default group tacacs+ local`. After INC-07, TACACS+ sessions to 10.20.20.11 completed. Logins land at user EXEC (`>`) rather than privileged EXEC; this is documented as an open limitation. All other devices use local accounts only.

## V9–V10 — Wireless

All four APs joined the WLC (monitor summary: 4 total, 4 up, 0 down). WPA2-Enterprise client logins (PEAP-MSCHAPv2 via RADIUS), DHCP lease and OSPF-routed DHCP replies were confirmed at HQ (laptop and phone), the DC (AP1) and Branch B (AP4). At Branch A (Oct 6), a phone placed next to AP3 associated and obtained 10.30.50.123 from the Branch A VLAN 50 pool (gateway 10.30.50.1, DNS 10.20.20.10); a screenshot of its IP configuration was reviewed, and the lease range is consistent with association through AP3. At the final AP range of 100 m the phones associate (operator-observed), but in the Packet Tracer view some association lines run to an AP at another site, and the AP each phone joined was not confirmed in the WLC. At 20–30 m most phones did not associate at all. The cause was not isolated; Packet Tracer's help ties wireless range to the Physical workspace, which was not examined. See [known limitations](known-limitations.md).

## V11 — VTY ACL

SSH from a non-MGMT source was refused and the ACL deny counters rose on HQ_EDGE_RTR1 and HQ-DIST-SW1. The ACL is configured on every managed device; enforcement was not demonstrated on the remaining devices.

## V12 — GRE-over-IPsec stuck SA

See [INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md). Observed on two consecutive loads of the `.pkt` (Branch A stuck on the first, Branch B on the second). Recovered once with the procedure in [runbooks](runbooks.md#r2--recover-a-stuck-gre-over-ipsec-tunnel). Root cause is unproven.

---

## Not demonstrated in this report

- DHCP snooping binding-table contents and DAI drops: configured at HQ and Branch A (snooping is disabled at Branch B); no output captured here.
- SNMP polling: there is no network management system in the topology, so SNMPv2c is configured only.
- Syslog/NTP receipt on 10.20.20.12 from every device: the server and the client config exist; per-device receipt is not itemised.
- VTY ACL enforcement on devices other than HQ_EDGE_RTR1 and HQ-DIST-SW1.
- Which AP each wireless client joined (some association lines cross sites at an AP range of 100 m).
- Failover for the DC edge, HQ edge and Branch B router themselves (single points of failure by design).
