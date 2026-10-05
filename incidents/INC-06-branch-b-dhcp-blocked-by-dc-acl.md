# INC-06 — Branch B DHCP blocked by the DC server ACL (NOC-0925-01)

| | |
|---|---|
| **Severity** | P2 — one site could not lease addresses |
| **Type** | Planted fault, found by NOC-style diagnosis |
| **Ticket** | NOC-0925-01 |
| **Build day** | Day 5 (services and wireless) |
| **Devices** | DC_CORE/DIST_SW1, DC_CORE/DIST_SW2 (`DC-SERVER-ACCESS`), BR_B_SW1 |
| **Status** | Resolved |

## Reported symptom

New devices at Branch B could not get an IP address. HQ and Branch A were not affected.

## Impact

Branch B end hosts silently failed to lease an address. No other site was affected.

## Diagnosis

1. Scope: only Branch B failed, so the DHCP server, the pools and the OSPF path (which Branch B shares with the other sites) were unlikely causes. What is unique to Branch B is its relay agent address and the ACL entry that must permit it.
2. The DHCP relay (BR_B_SW1, `ip helper-address 10.20.20.10`) was present and the SVI was up.
3. Reviewed `show access-lists DC-SERVER-ACCESS` on the DC switches. At that stage the ACL permitted DHCP by **relay-agent host address**: HQ and Branch A relays were listed, but **BR_B_SW1's relay address (10.40.10.1) was not**.
4. Packets from Branch B's relay hit the end of the list and were dropped by the implicit deny.

## Root cause

The permit line `permit udp host 10.40.10.1 host 10.20.20.10 eq bootps` was missing from `DC-SERVER-ACCESS`. Relayed DHCP requests from Branch B were dropped outbound on the DC's VLAN 20 SVI.

## Fix

Added the missing permit and re-applied the ACL outbound on VLAN 20. While reviewing the list, two further gaps were found: the explicit `deny ip any any` closer was missing, and a TACACS+ line had been truncated. The ACL was rebuilt cleanly (remove and re-create) on **both** DC switches so they stay identical.

## Verification

Branch B leases succeeded after the fix (operator-observed); HQ and Branch A were unaffected. The final rebuilt ACL shows **0 matches on `deny ip any any`** on both DC switches ([V5](../docs/verification-report.md#v5--dc-server-access-final-state)).

## Prevention

- In the final design the per-relay-host DHCP permits were replaced by one `permit udp any host 10.20.20.10 eq bootps`. This removes this class of fault (a forgotten relay address) at the cost of a slightly broader rule; the narrower rule is safe only when every new relay address is added at the same time as the SVI.
- Always keep an explicit `deny ip any any` as the last line so counters show what is being dropped. (The `log` keyword is rejected on this image, so counters are the only visibility.)
- Apply an ACL change to both redundant peers in the same step.
