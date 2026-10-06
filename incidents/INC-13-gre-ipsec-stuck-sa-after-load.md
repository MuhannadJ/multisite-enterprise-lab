# INC-13 — GRE-over-IPsec tunnel stuck after load (OPEN)

| | |
|---|---|
| **Severity** | P2 — backup path to one branch unavailable after each load; primary paths unaffected |
| **Type** | Unplanned defect, cause **unproven** |
| **Dates** | Oct 2–3 |
| **Devices** | HQ_EDGE_RTR1 (Tunnel1, Tunnel2), BR-A-RTR2, BR_B_RT1; underlay INET_RTR1 |
| **Status** | **Open.** Workaround documented and observed to work once ([runbooks R2](../docs/runbooks.md#r2--recover-a-stuck-gre-over-ipsec-tunnel)) |

## Symptom

After loading the `.pkt`, exactly **one** of HQ's two GRE-over-IPsec tunnels was stuck while the other was healthy. It happened on two loads, and the stuck branch was **different each time**.

| Load | Stuck | HQ_EDGE_RTR1 `show crypto isakmp sa` | Spoke |
|---|---|---|---|
| 1 | Branch A (192.168.200.5) | `MM_KEY_EXCH`, connection ID 1015. Branch B (.9) `QM_IDLE`, ID 1060 | BR-A-RTR2: ISAKMP table **empty** |
| 2 (after a Packet Tracer crash and reopen) | Branch B (192.168.200.9) | `MM_KEY_EXCH`, ID 1056. Branch A healthy | BR_B_RT1: `MM_NO_STATE`, connection ID 0 |

In both cases the stuck entry was the **lower connection ID, the first negotiation**. While a pair was stuck, plain pings between the two physical interfaces (for example 192.168.200.5 ↔ 192.168.200.1) failed, although an extended ping sourced from the spoke's LAN-side address (10.30.2.2 → 192.168.200.1) succeeded. HQ's `GRE-TO-BRA` ACL showed 219 matches and BR-A-RTR2's `GRE-TO-HQ` 413, so GRE traffic was being generated and matched the crypto ACLs but never completed.

## Impact

The tunnel is the backup path, so users saw nothing. But every failover test is invalid until both tunnels are healthy, and the stuck state appeared on both loads tested.

## What was ruled out

| Hypothesis | Evidence against |
|---|---|
| Key or policy mismatch (as in [INC-04](INC-04-ipsec-psk-mismatch-hq-branch-b.md)) | Keys byte-identical; ISAKMP policy, transform set, crypto maps and interesting-traffic ACLs mirror each other on both ends |
| Different model or licence on the stuck router | `show version \| begin Technology` identical on INET_RTR1, BR-A-RTR2 and BR_B_RT1: same model, `securityk9` permanent, same board ID |
| INET_RTR1 mishandling tunnel traffic | It has only static routes (three /16s), no ACL, NAT or crypto, and forwards normally; its ARP table and routes are correct |
| Missing default route on the spoke | `ip route 0.0.0.0 0.0.0.0 192.168.200.6 130` is installed and the route is in the table |
| The spoke's crypto map dropping the underlay pings | Removing the map from Gi0/0/1 did not restore the pings (0/5) |
| Stale single map entry on HQ | Removing and re-adding that one `crypto map VPN-MAP` entry left the stale SA (ID 1015) in place |

## Workaround

Observed once, on Branch B (load 2). Full steps in [runbooks R2](../docs/runbooks.md#r2--recover-a-stuck-gre-over-ipsec-tunnel): shut the stuck tunnel on both ends, bounce `crypto map VPN-MAP` on the physical interface of both stuck ends and HQ, bring HQ's tunnel up **alone**, then the spoke's. After this both ISAKMP SAs were `QM_IDLE` and both OSPF neighbours were FULL.

## Hypothesis (unproven)

HQ negotiates both tunnels at about the same time after a load. Both observed failures hit the **first** negotiation, which fits a startup collision or race between the two negotiations on the shared interface and crypto map. This is a hypothesis only: it was not reproduced on demand, and staggering the start was observed to work once.

## Open observations

- The spoke's ISAKMP state differed between the two loads: an empty table on BR-A-RTR2 (load 1) versus a `MM_NO_STATE` entry with connection ID 0 on BR_B_RT1 (load 2). Unexplained.
- BR-A-RTR2's ISAKMP entry shows `ACTIVE (deleted)` while Tunnel1 is FULL. Meaning not established.
- The behaviour appeared with the legacy crypto-map method, which was used because `tunnel protection` and IPsec profiles are rejected on this image.

## What to do in practice

- After every load, run the two checks in R2 before trusting either backup path.
- If a tunnel is in `MM_KEY_EXCH` and the keys match, suspect stale state before changing config again.
- Record the fault as a reproducible, characterised, unexplained simulator behaviour with a documented recovery.
