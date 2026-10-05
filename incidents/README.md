# Incident reports

One report per incident, written in NOC style: **symptom → impact → diagnosis → root cause → fix → verification → prevention**.

## How to read these

- **Planted faults (INC-01 to INC-06)** were introduced silently into the build and found through normal troubleshooting. Where a ticket existed it is referenced (NOC-0924-03, NOC-0925-01).
- **Real defects (INC-07 to INC-13)** were found in the build itself, not planted.
- Reports are reconstructed from the working notes of the lab. Commands listed in *Diagnosis* are the ones that expose each fault; command output is quoted only where it was captured.
- Pre-shared keys, community strings and passwords are deliberately not reproduced.
- **Severity** is assigned in this write-up from observed impact:

| Level | Meaning |
|---|---|
| P1 | A site or a core service is down |
| P2 | Service degraded, a security control is not enforced, or redundancy is lost |
| P3 | Latent or cosmetic; no current user impact |

## Index

| ID | Title | Type | Sev | Status |
|---|---|---|---|---|
| [INC-01](INC-01-hsrp-vip-mismatch-branch-a.md) | HSRP virtual-IP mismatch, Branch A VLAN 99 | Planted | P2 | Resolved |
| [INC-02](INC-02-isp-rtr2-swapped-interface-addresses.md) | ISP_RTR2 interface addresses swapped | Planted | P1 | Resolved |
| [INC-03](INC-03-nat-inside-outside-misassigned.md) | DC edge NAT inside/outside misassigned | Planted | P2 | Resolved |
| [INC-04](INC-04-ipsec-psk-mismatch-hq-branch-b.md) | IPsec pre-shared key mismatch, HQ ↔ Branch B | Planted | P2 | Resolved |
| [INC-05](INC-05-dhcp-helper-address-wrong-hq-dist-sw2.md) | Wrong DHCP helper address on HQ-DIST-SW2 (NOC-0924-03) | Planted | P3 | Resolved |
| [INC-06](INC-06-branch-b-dhcp-blocked-by-dc-acl.md) | Branch B DHCP blocked by the DC server ACL (NOC-0925-01) | Planted | P2 | Resolved |
| [INC-07](INC-07-nat-pat-translating-inter-site-traffic.md) | PAT translating inter-site traffic; TACACS+ connections reset | Real | P2 | Resolved |
| [INC-08](INC-08-acls-configured-but-never-bound.md) | ACLs configured but never bound to interfaces | Real | P2 | Resolved |
| [INC-09](INC-09-hsrp-stp-priority-misalignment.md) | HSRP priorities misaligned with STP roots | Real | P3 | Resolved |
| [INC-10](INC-10-hq-vlan50-split-brain.md) | HQ VLAN 50 HSRP and STP split-brain | Real | P2 | Resolved |
| [INC-11](INC-11-dc-root-guard-blocking-root-election.md) | Root Guard blocking root election at the DC | Real | P2 | Resolved |
| [INC-12](INC-12-wireless-rollout-defects.md) | Wireless rollout defects (a recurring omission class) | Real | P2 | Resolved |
| [INC-13](INC-13-gre-ipsec-stuck-sa-after-load.md) | GRE-over-IPsec tunnel stuck after load | Real | P2 | **Open** |

Smaller findings: [minor-findings.md](minor-findings.md).

## Cross-incident lessons

1. **Scope before change.** INC-04, INC-05, INC-06 and INC-13 were all solved by asking *which device, site or path* before touching a line of config.
2. **A defined control is not an enforced control** (INC-08). Test with traffic and read the counters.
3. **A status display can be wrong** (INC-08, `show ip interface`; INC-10, simulator state). Use at least two independent sources.
4. **The same symptom can have different causes** (INC-04 vs INC-13: `MM_KEY_EXCH` with a bad key, then with a good one).
5. **"Platform limitation" is a conclusion, not a starting point** (INC-07 was labelled a limitation until a packet trace found a NAT bug).
6. **Run one checklist per site** (INC-12). Missing steps are random across sites unless the sequence is fixed.
