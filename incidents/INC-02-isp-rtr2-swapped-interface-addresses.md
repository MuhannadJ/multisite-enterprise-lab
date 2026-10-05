# INC-02 — ISP_RTR2 interface addresses swapped

| | |
|---|---|
| **Severity** | P1 — a WAN core router could not form adjacencies on two links |
| **Type** | Planted fault, found by NOC-style diagnosis |
| **Build day** | Day 2 (L3 core and redundancy) |
| **Devices** | ISP_RTR2 (Gi0/0/1, Gi0/0/2) |
| **Status** | Resolved |

## Reported symptom

During the Day 2 verification, loopback pings between sites did not complete: inter-area reachability was missing across the WAN core.

## Impact

ISP_RTR2 carries the DC and Branch B primary paths and half of the WAN backbone. With two interfaces addressed for each other's subnets, the DC and the ISP-RTR1 side could not form OSPF adjacencies with it, which split the backbone.

## Diagnosis

1. Checked the WAN core adjacencies with `show ip ospf neighbor` on the routers either side of ISP_RTR2 and compared them with the expected neighbour list.
2. Compared each ISP_RTR2 interface address (`show ip interface brief`) with the /30 it is cabled into and with the neighbour's address on the same link. Gi0/0/1 faces ISP-RTR1 (172.16.0.0/30) and Gi0/0/2 faces DC-EDGE-RTR1 (172.16.2.0/30).
3. The addresses on Gi0/0/1 and Gi0/0/2 were each valid, but belonged to the other interface's subnet.

## Root cause

The IP addresses on ISP_RTR2 Gi0/0/1 and Gi0/0/2 were swapped relative to the cabling. Neighbours on each link were therefore in a different subnet from the address facing them, so no adjacency could form.

## Fix

Re-assigned each interface the address of the subnet it is actually cabled into: Gi0/0/1 → 172.16.0.2/30 (to ISP-RTR1), Gi0/0/2 → 172.16.2.2/30 (to DC-EDGE-RTR1). Gi0/0/0 (172.16.4.2/30, to BR_B_RT1) was unaffected.

## Verification

OSPF adjacencies formed on both links and loopback pings succeeded across HQ, DC, Branch A and Branch B. A separate Packet Tracer OSPF defect then still blocked inter-area routes until the OSPF process was removed and re-added (see [minor findings](minor-findings.md)).

## Prevention

- Keep one authoritative link table (see [addressing.md](../docs/addressing.md#4-point-to-point-links)) and check every interface against it with `show ip interface brief` and `show cdp neighbors`.
- When two adjacencies fail on one router, suspect that router's addressing before the protocol.
