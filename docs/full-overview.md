# Full project overview

The long version of the [README](../README.md): the design in detail and the evidence tables. For the short version start with the [README](../README.md) and the [troubleshooting page](../TROUBLESHOOTING.md).

## Summary

A four-site enterprise network (HQ campus, data center and two branches) built device by device in Cisco Packet Tracer and connected through a simulated WAN. Configured routing, redundancy, wireless and management/access controls, tested three failover scenarios, and documented 13 troubleshooting cases using a structured NOC-style workflow.

The point of this repo is not only the final design. It is the **evidence trail**: 13 incident reports (symptom → evidence → root cause → fix → verification), a verification report that separates *output reviewed in session* from *operator-observed* results, and a list of what the platform could not do.

---

## At a glance

| | |
|---|---|
| **Platform** | Cisco Packet Tracer (ISR4321/4331 routers, 3560-24PS L3 switches, 2960 access switches, WLC 3504, LAPs) |
| **Devices** | 22 IOS devices (HQ 8, DC 5, WAN 3, Branch A 4, Branch B 2) + WLC + 4 APs + 3 servers + end hosts |
| **Sites** | HQ (10.10.0.0/16), DC (10.20.0.0/16), Branch A (10.30.0.0/16), Branch B (10.40.0.0/16) |
| **Routing** | OSPFv2 multi-area (Area 0 WAN core, Areas 1–4 per site, Branch B totally stubby) |
| **First-hop redundancy** | HSRP on every redundant gateway pair, STP root aligned with HSRP active per VLAN |
| **Layer 2** | Manual VLANs (no VTP), Rapid PVST+, LACP EtherChannel, PortFast + BPDU Guard on the access switches, Root Guard on the HQ downlinks, port security |
| **Security** | SSH-only management + VTY ACL on the 19 managed devices, `DATA-IN` and `DC-SERVER-ACCESS` ACLs, DHCP snooping + DAI at HQ and Branch A, TACACS+ (two-router pilot), SNMPv2c RO |
| **WAN edge** | PAT with destination-scoped ACL, floating static defaults (AD 130), GRE-over-IPsec backup to both branches |
| **Services** | DHCP/DNS (10.20.20.10), AAA (10.20.20.11), Syslog/NTP (10.20.20.12), all in DC VLAN 20 |
| **Wireless** | One WLC at HQ, one AP per site, single SSID `CORP-WIFI`, WPA2-Enterprise (PEAP-MSCHAPv2) against RADIUS, FlexConnect local switching |

---

## Design in one page

**Layer 2.** VLAN 10 DATA (HQ, Branch A, Branch B), VLAN 20 SERVERS (DC only), VLAN 50 WIRELESS (all sites), VLAN 99 MGMT (all sites), VLAN 999 NATIVE (unused; the native VLAN on all inter-switch trunks, while AP-facing ports use native 99). VLAN 1 is unused. VTP was rejected in favour of manual per-switch VLAN config to avoid revision-number propagation risk. Distribution pairs are joined by LACP bundles at HQ and Branch A; the DC pair uses a single routed link.

**Gateway redundancy.** HSRP with the convention **VIP = .1, SW1 = .2, SW2 = .3, group number = VLAN ID** (except Branch A VLAN 99, whose VIP is .10; see INC-01). For every VLAN with an HSRP group (10, 20, 50 and 99) the STP root and HSRP active are deliberately aligned and alternated between the two switches so each carries one share of the traffic. Priorities and roots are tabulated in [`docs/addressing.md`](addressing.md).

**Routing.** OSPF area design follows the site boundaries. ABRs: HQ_EDGE_RTR1 (Area 1), DC-EDGE-RTR1 (Area 2), BR_A_RTR1 (Area 3), BR_B_RT1 (Area 4, totally stubby). BR-A-RTR2 becomes an ABR through the IPsec tunnel. Floating static defaults (AD 130) via INET_RTR1 exist on HQ_EDGE_RTR1, BR-A-RTR2 and BR_B_RT1 and sit behind OSPF.

**WAN and failover.** Each branch has a primary ISP path and a backup path over INET_RTR1 carried in GRE-over-IPsec, with OSPF running inside the tunnel. HQ and the DC each have a single edge router, and Branch B has a single router (accepted single points of failure); the DC has no independent backup WAN path.

**NAT.** PAT overload on each site's primary edge router using an **extended** `NAT-PAT` ACL that excludes inter-site destinations (10.0.0.0/8, 172.16.0.0/16, 192.168.200.0/24). A source-only ACL here broke inter-site TCP — see [INC-07](../incidents/INC-07-nat-pat-translating-inter-site-traffic.md).

**Security.**
- SSH v2 only and `VTY-ACL` (allowing only the four site MGMT subnets) on all 19 enterprise-managed devices. The three provider/WAN devices (ISP-RTR1, ISP_RTR2, INET_RTR1) are intentionally unhardened.
- `DATA-IN` blocks VLAN 10 → every site's VLAN 99 (applied inbound on the VLAN 10 SVI of each gateway switch).
- `DC-SERVER-ACCESS` (outbound on VLAN 20 SVI of both DC switches) is a per-service allow-list to the three servers with an explicit `deny ip any any`: [`docs/addressing.md`](addressing.md#dc-server-access-acl).
- DHCP snooping + DAI on VLAN 10 at the HQ access switches and the Branch A switches; at Branch B global snooping is disabled, its VLAN 10 snooping and DAI lines remain in the config, and DAI was not tested there (see known limitations); none at the DC (VLAN 20 has no DHCP clients).
- Port security with mixed violation modes; PortFast + BPDU Guard by default on the L2 access switches; Root Guard on the HQ distribution-to-access downlinks.
- Unused FastEthernet ports shut on the access and branch switches (the Gi0/1–2 ports are left up and unconfigured; see [known limitations](known-limitations.md)).
- TACACS+ is a **two-router pilot** (HQ_EDGE_RTR1, BR_B_RT1); all other devices use local accounts.

**Wireless.** WLC at HQ (chosen over the DC because HQ has the more resilient path), one LAP per site, client VLAN 50 per site, WPA2-Enterprise with PEAP-MSCHAPv2 against RADIUS at 10.20.20.11, FlexConnect local switching with local authentication. See [INC-12](../incidents/INC-12-wireless-rollout-defects.md).

Design rationale for every non-obvious choice: [`docs/design-decisions.md`](design-decisions.md).

---

## What was tested, and how

Full detail and raw evidence summaries: [`docs/verification-report.md`](verification-report.md).

| Test | Result | Evidence |
|---|---|---|
| Branch A primary WAN link down → traffic moves to the IPsec tunnel | Pass | Output reviewed in session: IPsec counters rose, traceroute path via tunnel |
| Branch B primary WAN link down → traffic moves to the IPsec tunnel | Pass | Output reviewed in session: route change, same SA, counters rose |
| HQ HSRP failover — control plane and preemption | Pass | Output reviewed in session |
| HQ HSRP failover — data plane (traffic actually forwarded by SW2 with ACL enforced) | Pass, **with a platform caveat** | Output reviewed in session; required isolating SW1 at port level |
| `DC-SERVER-ACCESS` final state | Pass: `deny ip any any` = 0 hits on both DC switches | Output reviewed in session |
| `DATA-IN` blocking VLAN 10 → VLAN 99 | Pass | Blocked ping + counters on HQ-DIST-SW1 |
| DHCP across HQ, Branch A, Branch B | Pass after INC-05, INC-06, INC-07 fixes | Operator-observed |
| WPA2-Enterprise client login (HQ, DC, Branch A, Branch B) | Pass | Operator-observed |

Evidence labels: **Output reviewed in session** means the CLI output was pasted into the working session and reviewed. **Operator-observed** means the lab owner ran the test and reported the result.

---

## Incident log

Thirteen reports in [`incidents/`](../incidents/README.md). Six were silently planted faults found through normal NOC diagnosis; seven were unplanned defects found in the build itself.

| ID | Title | Type | Lab severity |
|---|---|---|---|
| [INC-01](../incidents/INC-01-hsrp-vip-mismatch-branch-a.md) | HSRP virtual-IP mismatch, Branch A VLAN 99 | Planted | P2 |
| [INC-02](../incidents/INC-02-isp-rtr2-swapped-interface-addresses.md) | ISP_RTR2 interface addresses swapped | Planted | P1 |
| [INC-03](../incidents/INC-03-nat-inside-outside-misassigned.md) | DC edge NAT inside/outside misassigned | Planted | P2 |
| [INC-04](../incidents/INC-04-ipsec-psk-mismatch-hq-branch-b.md) | IPsec pre-shared key mismatch, HQ ↔ Branch B | Planted | P2 |
| [INC-05](../incidents/INC-05-dhcp-helper-address-wrong-hq-dist-sw2.md) | Wrong DHCP helper address on HQ-DIST-SW2 (Lab ticket 1) | Planted | P3 |
| [INC-06](../incidents/INC-06-branch-b-dhcp-blocked-by-dc-acl.md) | Branch B DHCP blocked by the DC server ACL (Lab ticket 2) | Planted | P2 |
| [INC-07](../incidents/INC-07-nat-pat-translating-inter-site-traffic.md) | PAT translating inter-site traffic; TACACS+ connections reset | Unplanned | P2 |
| [INC-08](../incidents/INC-08-acls-configured-but-never-bound.md) | ACLs configured but never bound to interfaces | Unplanned | P2 |
| [INC-09](../incidents/INC-09-hsrp-stp-priority-misalignment.md) | HSRP priorities misaligned with STP roots | Unplanned | P3 |
| [INC-10](../incidents/INC-10-hq-vlan50-split-brain.md) | HQ VLAN 50 HSRP and STP split-brain | Unplanned | P2 |
| [INC-11](../incidents/INC-11-dc-root-guard-blocking-root-election.md) | Root Guard blocking root election at the DC | Unplanned | P2 |
| [INC-12](../incidents/INC-12-wireless-rollout-defects.md) | Wireless rollout defects (a recurring omission class) | Unplanned | P2 |
| [INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md) | GRE-over-IPsec tunnel stuck after load | Unplanned | P2 |

The best cases are summarised on the [troubleshooting page](../TROUBLESHOOTING.md).

Smaller findings (OSPF process bug, SSH credential quirk, DHCP pool typo, INET addressing, hardware-slot quirk) are in [`incidents/minor-findings.md`](../incidents/minor-findings.md).

---

## Known limitations

Short version; the full list with impact and workaround is in [`docs/known-limitations.md`](known-limitations.md).

- **The Packet Tracer device images used here did not support** VRRP, GLBP, IP SLA, `tunnel protection`/IPsec profiles, ACL `log`, SNMP traps/hosts, several AAA/TACACS source options. HSRP replaced VRRP/GLBP everywhere; crypto maps replaced IPsec profiles.
- **GRE-over-IPsec fault on load:** after loading the `.pkt`, one of HQ's two tunnels can be stuck on a stale ISAKMP SA (seen on both loads tested). Root cause is unproven; a recovery procedure is in [`docs/runbooks.md`](runbooks.md) ([INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md)).
- **SVI ACL bindings are not in effect after reloading the `.pkt`.** The ACL definitions persist, but the bindings must be re-applied, and this image does not list them in the running-config afterwards, so they are evidenced by counters and pings rather than by the exported configs ([`docs/runbooks.md`](runbooks.md#r1--re-apply-svi-acl-bindings-after-loading-the-pkt)).
- **Shutting an SVI does not stop that switch forwarding or enforcing its ACL** in this simulator; HSRP data-plane failover was therefore tested by isolating the switch at port level.
- **Wireless AP selection is not controlled.** At an AP range of 20–30 m most phones could not associate; at 100 m they do, but some join an AP at another site. The cause was not isolated. All four APs joined the WLC; client logins were confirmed at all four sites.
- **TACACS+** is a two-router pilot and logins land at user EXEC (`>`), not privileged EXEC.
- **Single points of failure by design:** one edge router at HQ and at the DC, one router at Branch B, and the DC has no backup WAN path.

---

## Repository layout

```
README.md                 Page 1: the project in one screen
TROUBLESHOOTING.md        Page 2: the best troubleshooting cases
docs/
  full-overview.md        This file: the long version of the README
  addressing.md           IP plan, VLANs, HSRP/STP tables, OSPF, NAT, ACL contents
  design-decisions.md     Why each non-obvious choice was made
  verification-report.md  Tests run, evidence level, results
  known-limitations.md    Platform limits and accepted gaps
  key-findings.md         The ten findings that took the most diagnostic reasoning
  runbooks.md             Reload re-apply script, tunnel recovery, failover test steps
  img/                    Screenshots
incidents/
  README.md               Severity scale and index
  INC-01 … INC-13         One report per incident
  minor-findings.md
configs/                  Sanitized running-configs of all 22 devices (see configs/README.md)
scripts/
  sanitize-configs.sh     Redacts keys, community strings and password hashes before publishing
```

---

## Reproducing the lab

1. Open the `.pkt` in a current Packet Tracer build.
2. Re-apply the SVI ACL bindings from [`docs/runbooks.md`](runbooks.md#r1--re-apply-svi-acl-bindings-after-loading-the-pkt).
3. Check both tunnels with `show crypto isakmp sa` (expect `QM_IDLE` to each branch). If one is stuck, follow [`docs/runbooks.md`](runbooks.md#r2--recover-a-stuck-gre-over-ipsec-tunnel).
4. Run the failover tests in [`docs/runbooks.md`](runbooks.md#r3--failover-test-procedures).

All keys, SNMP community strings and password hashes in `configs/` are lab-only values and are redacted by `scripts/sanitize-configs.sh` before publishing.

---

## What this demonstrates for a NOC L1 role

- **Structured troubleshooting:** every incident follows symptom → hypothesis → evidence → root cause → fix → verification, using `show` output rather than guesses.
- **Scope discipline:** checking *where* a fault lives (one device, one site, one path) before changing anything; incidents INC-05, INC-06 and INC-13 are scope problems as much as config problems.
- **Packet-level reasoning:** INC-07 was solved by tracing a TCP handshake hop by hop in Simulation Mode and noticing a rewritten source address.
- **Evidence over assertion:** results are labelled by how they were obtained, and failed or inconclusive tests are written up rather than dropped.
- **Write-ups:** each report states impact, what was ruled out, and what remains unknown.

---

*Author: Muhannad · CCNA 200-301. Contact details are on my GitHub profile.*
