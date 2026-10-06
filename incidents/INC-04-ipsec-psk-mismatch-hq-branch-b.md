# INC-04 — IPsec pre-shared key mismatch, HQ ↔ Branch B

| | |
|---|---|
| **Severity** | P2 — backup path to Branch B unavailable (primary path unaffected) |
| **Type** | Planted fault, found by NOC-style diagnosis |
| **Build day** | Day 3 (WAN, NAT and VPN) |
| **Devices** | HQ_EDGE_RTR1, BR_B_RT1 |
| **Status** | Resolved |

## Reported symptom

The GRE-over-IPsec tunnel between HQ and Branch B (Tunnel2 at HQ, Tunnel1 at Branch B) did not come up; ISAKMP negotiation did not complete.

## Impact

No redundancy for Branch B: if its primary ISP link failed, there was no working backup path. The primary path was unaffected, so users saw nothing until a failover.

## Diagnosis

1. Scope: the fault was specific to the Branch B negotiation. The ISAKMP policy, transform set and underlay design are shared with the Branch A tunnel, so the Branch B-specific lines were compared first.
2. Compared the Branch B-specific pieces on both ends: tunnel source and destination, the `crypto isakmp key … address …` lines, and the crypto map entry.
3. Compared the two `crypto isakmp key` lines **character by character**. The keys contained the same characters in a different order, so they looked identical at a glance.

## Root cause

The pre-shared key for the peer differed between HQ_EDGE_RTR1 and BR_B_RT1 (same characters, different order). Phase 1 authentication cannot complete with mismatched keys.

## Fix

Made the pre-shared key for the HQ ↔ Branch B peer pair identical on both ends.

## Verification

Phase 1 reached `QM_IDLE` to the Branch B peer, Tunnel2 came up, and OSPF formed a FULL adjacency across it. Branch B failover was later tested end to end ([V2](../docs/verification-report.md#v2--branch-b-wan-failover)).

## Lesson, linked to INC-13

A `MM_KEY_EXCH` state on one side is consistent with a key mismatch **but is not proof of one**. In [INC-13](INC-13-gre-ipsec-stuck-sa-after-load.md) the same symptom appeared with byte-identical keys and a different cause. Compare keys first, and if they match, look at stale state before changing config again.

## Prevention

- Copy-paste the key from one source instead of retyping it on each end.
- Compare secrets with a character-by-character diff (`show running-config | include crypto isakmp key` on both ends), not by eye.
- Never print the real key in tickets; the repo's published configs are redacted.
