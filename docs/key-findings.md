# Key findings

Ten findings from the 13 incident reports, selected for the clearest troubleshooting evidence, not for severity. Each links to its full report. "Planted" means the fault was seeded into the build for NOC-style diagnosis; "Unplanned" means it was a defect in the build itself.

| # | Finding | Type | Report | What it shows |
|---|---|---|---|---|
| 1 | A "platform limitation" that was NAT rewriting server replies | Unplanned | [INC-07](../incidents/INC-07-nat-pat-translating-inter-site-traffic.md) | Tested the platform-limitation hypothesis with packet tracing and ruled it out |
| 2 | Security controls that existed but enforced nothing | Unplanned | [INC-08](../incidents/INC-08-acls-configured-but-never-bound.md) | Testing enforcement, not configuration |
| 3 | One symptom, two causes: a config fault, then a simulator bug | Unplanned | [INC-10](../incidents/INC-10-hq-vlan50-split-brain.md) | Knowing when to stop editing config |
| 4 | A security feature that blocked its own network | Unplanned | [INC-11](../incidents/INC-11-dc-root-guard-blocking-root-election.md) | Topology-aware reasoning |
| 5 | The pattern behind twelve wireless defects | Unplanned | [INC-12](../incidents/INC-12-wireless-rollout-defects.md) | Root cause of a recurring class, turned into a checklist |
| 6 | An unexplained tunnel fault, characterised instead of guessed | Unplanned, open | [INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md) | Write-up of an open issue: what was ruled out and what is unknown |
| 7 | Same symptom, different cause: key mismatch vs stuck SA | Planted + unplanned | [INC-04](../incidents/INC-04-ipsec-psk-mismatch-hq-branch-b.md), [INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md) | MM_KEY_EXCH appeared with mismatched keys (INC-04) and with byte-identical keys (INC-13) |
| 8 | One site's DHCP outage, and two ACL gaps found beside it | Planted | [INC-06](../incidents/INC-06-branch-b-dhcp-blocked-by-dc-acl.md) | Scope-first diagnosis |
| 9 | Misalignment found by audit, before any symptom | Unplanned | [INC-09](../incidents/INC-09-hsrp-stp-priority-misalignment.md) | Auditing against a written design rule |
| 10 | Addressing faults found by subnet arithmetic | Planted + unplanned | [INC-02](../incidents/INC-02-isp-rtr2-swapped-interface-addresses.md), [minor findings](../incidents/minor-findings.md) | Subnet fundamentals applied to live faults |

---

## 1. A "platform limitation" that was NAT rewriting server replies

**Found.** TACACS+ logins from Branch B to the AAA server failed at the TCP level, survived a full server rebuild and a router reload, and the image rejected `ip tacacs source-interface` and `aaa group server tacacs+`. The working conclusion was "platform limitation" and TACACS+ was rolled back.

**How.** The conclusion was reopened and the TCP handshake was followed hop by hop in Simulation Mode. The server's SYN-ACK left the DC with source 10.20.20.11 and arrived with source **172.16.2.1**, the DC edge router's own outside address. The client had never contacted that address and sent a **RST**.

**Cause.** A source-only standard ACL on the PAT statement translated replies from the DC to other sites as if they were Internet-bound. Pings were unaffected, which hid it.

**Why it matters.** The same fault class showed up later as HQ's DHCP relay traffic falling through the DC ACL's deny. The fix, an extended destination-scoped `NAT-PAT` ACL, went onto all four edge routers. Evidence: TACACS+ worked after the fix; a PDU capture at HQ showed the untranslated source; the final DC ACL shows 0 hits on its `deny ip any any` ([V5](verification-report.md#v5--dc-server-access-final-state)).

## 2. Security controls that existed but enforced nothing

**Found.** A host in VLAN 10 could ping the HQ management gateway that `DATA-IN` was written to block. The ACL text was correct; the `ip access-group` line was missing. The same omission existed for `DC-SERVER-ACCESS` on both DC switches, so **seven switches** in total.

**How.** Enforcement was confirmed by match counters in `show access-lists`, blocked and permitted pings, and a Simulation Mode PDU trace. `show ip interface vlan X` was not used, because on this image it reports "access list is not set" while the ACL is demonstrably enforcing. After a reload the running-config does not list the binding either, so the exported configs show the ACLs but not their bindings ([V6](verification-report.md#v6--data-in)).

**Why it matters.** A defined control is not an enforced control, and a status display can be wrong. The reload behaviour of these bindings was characterised too, and a re-apply script is in [runbook R1](runbooks.md#r1--re-apply-svi-acl-bindings-after-loading-the-pkt).

## 3. One symptom, two causes: a config fault, then a simulator bug

**Found.** HQ's VLAN 50 had both distribution switches Active in HSRP. After that was fixed, three switches each claimed to be the STP root for the same VLAN.

**How.** Phase 1 was a real fault: the Port-channel and its member ports disagreed on whether VLAN 50 was allowed, in opposite directions on each switch. Phase 2 was different: a side-by-side config comparison found no discrepancy, and the fault survived a link bounce, deleting and re-creating the VLAN, and reloading both switches. Only restarting Packet Tracer cleared it.

**Why it matters.** The report names the point at which the config is cleared and the simulator becomes the suspect, and keeps the two phases apart. See [INC-10](../incidents/INC-10-hq-vlan50-split-brain.md).

## 4. A security feature that blocked its own network

**Found.** DC_CORE/DIST_SW1 could never converge on the intended root for VLAN 99.

**How.** The same symptom class had just been a simulator bug, and this time that was **not assumed**. Comparing the DC with HQ showed the DC's two core switches are linked by a routed interconnect, not a trunk, so SW1's only Layer 2 path to the root runs through its two access-facing ports. Root Guard was configured on both.

**Why it matters.** Removing Root Guard from those two ports fixed it with configuration alone, no reload and no restart. This is the check that separates a topology error from corrupted engine state ([INC-11](../incidents/INC-11-dc-root-guard-blocking-root-election.md)).

## 5. The pattern behind twelve wireless defects

**Found.** Bringing up VLAN 50 and VLAN 99 at four sites produced twelve entries (two are their own incidents): a WLAN mapped to the wrong interface, a RADIUS port mismatch, missing DHCP pools and helper-addresses, a VLAN 50 subnet missing from OSPF (Branch B again after it had been assumed correct), the wrong native VLAN on AP ports, a sticky port-security MAC learned under the old native VLAN that caused a violation once traffic moved to VLAN 99, and DHCP snooping dropping relayed requests that already carried Option 82.

**How.** One fix was reversed when evidence showed it was wrong: FlexConnect local authentication was disabled to make the WLC the RADIUS client, which left only the HQ AP able to authenticate clients, so it was re-enabled.

**Why it matters.** The real finding was the pattern. No single checklist was run across all four sites, so different steps were missed at different sites and surfaced only when a real client arrived. The report ends with a **10-step per-site rollout checklist** ([INC-12](../incidents/INC-12-wireless-rollout-defects.md)).

## 6. An unexplained tunnel fault, characterised instead of guessed

**Found.** After loading the lab, exactly one of HQ's two GRE-over-IPsec tunnels was stuck (`MM_KEY_EXCH` on HQ's side). It happened on two loads, and the stuck branch was different each time. In both cases it was the first negotiation, the lower connection ID.

**How.** Six hypotheses were ruled out with evidence: key or policy mismatch, a different model or licence, the underlay router mishandling traffic, a missing default route, the spoke's crypto map dropping the pings, and a stale map entry. A recovery sequence that worked once is documented ([runbook R2](runbooks.md#r2--recover-a-stuck-gre-over-ipsec-tunnel)).

**Why it matters.** The cause is **unproven** and the report says so. It lists the open observations and keeps the status as Open ([INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md)).

## 7. Same symptom, different cause: key mismatch vs stuck SA

**Found.** At HQ ↔ Branch B the tunnel did not come up because the two pre-shared keys held **the same characters in a different order**. They looked identical at a glance and were found by a character-by-character comparison ([INC-04](../incidents/INC-04-ipsec-psk-mismatch-hq-branch-b.md)).

**Why it matters.** Later, `MM_KEY_EXCH` appeared again with **byte-identical** keys and a different cause ([INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md)). The lesson recorded in both reports: that state is consistent with a key mismatch but is not proof of one. Compare keys first, and if they match, look at stale state before changing config again.

## 8. One site's DHCP outage, and two ACL gaps found beside it

**Found.** Branch B hosts could not lease an address; HQ and Branch A could. The scope pointed at what is unique to Branch B: its relay address and the ACL line that must permit it. That line was missing from `DC-SERVER-ACCESS`.

**How.** Reviewing the ACL turned up two more gaps: the closing `deny ip any any` was missing and a TACACS+ line had been truncated. The ACL was rebuilt on **both** DC switches so they stay identical.

**Why it matters.** The final design replaced the per-relay DHCP permits with one `permit udp any host 10.20.20.10 eq bootps`, which removes the "forgotten relay address" class of fault. The report states the trade-off, a slightly broader rule ([INC-06](../incidents/INC-06-branch-b-dhcp-blocked-by-dc-acl.md)).

## 9. Misalignment found by audit, before any symptom

**Found.** At HQ, the HSRP Active gateway for VLAN 10 was not the STP root, so traffic could take an extra hop across the Port-channel. At Branch A, one switch sat outside the documented priority scheme: default priority and no `preempt`.

**How.** No symptom triggered this. The live `standby` and `spanning-tree` lines were compared side by side against the written rule "STP root = HSRP Active, alternating per VLAN" ([INC-09](../incidents/INC-09-hsrp-stp-priority-misalignment.md)).

## 10. Addressing faults found by subnet arithmetic

**Found.** Two WAN routers had addresses that did not fit the links they were cabled into.
- **ISP_RTR2 (P1):** Gi0/0/1 and Gi0/0/2 each held a valid address that belonged to the other interface's /30, so two OSPF adjacencies could not form ([INC-02](../incidents/INC-02-isp-rtr2-swapped-interface-addresses.md)).
- **INET_RTR1:** two of three interfaces held addresses outside their own /30. One belonged to a different /30 entirely; another held `.10` in a /30 that only spans .4–.7 ([minor findings](../incidents/minor-findings.md)).

**How.** Each address was checked against the /30 it is cabled into and against its neighbour on the same link.

**Why it matters.** When two adjacencies fail on one router, suspect that router's addressing before the protocol.

---

More: [minor findings](../incidents/minor-findings.md) (including a port-security mode that fails silently on trunks) and [known limitations](known-limitations.md).
