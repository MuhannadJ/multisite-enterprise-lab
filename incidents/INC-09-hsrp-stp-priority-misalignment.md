# INC-09 — HSRP priorities misaligned with STP roots

| | |
|---|---|
| **Severity** | P3 — suboptimal traffic path, no outage |
| **Type** | Unplanned defect in the build (not planted), found by auditing live configs against the design rule |
| **Build day** | Day 5 (Sept 27) |
| **Devices** | HQ-DIST-SW1, HQ-DIST-SW2 (VLAN 10); BR_A_SW1 (VLAN 99) |
| **Status** | Resolved |

## Design rule being checked

For each VLAN, the switch that is **STP root** must also be the **HSRP Active** gateway, and the roles alternate between the two switches per VLAN so each carries one share of the load ([design decisions](../docs/design-decisions.md)).

## Findings

| Device / VLAN | Observed | Should be |
|---|---|---|
| HQ-DIST-SW1/SW2, VLAN 10 | HSRP priorities backwards: **SW2 was winning** although SW1 is the STP root for VLAN 10 | SW1 160, SW2 150 |
| BR_A_SW1, VLAN 99 | No HSRP priority or preempt configured (default 100) while SW2 had 150 | SW1 110 with `preempt`, SW2 150 |

## Impact

At HQ the HSRP Active gateway for VLAN 10 (SW2) was not the STP root (SW1), so user traffic could take an extra hop across the inter-switch Port-channel. At Branch A, BR_A_SW1 sat outside the documented priority scheme (default 100 and no `preempt` instead of 110 with `preempt`), so its behaviour through a failure and recovery sequence would not match the design.

## Diagnosis

Compared the live `standby` and `spanning-tree vlan … priority` lines of each pair side by side against the rule, rather than waiting for a symptom (`show standby brief` for the Active/Standby role and `show spanning-tree vlan 10` for the root).

## Fix

```
! HQ-DIST-SW1                    ! HQ-DIST-SW2
interface Vlan10                 interface Vlan10
 standby 10 priority 160          standby 10 priority 150
 standby 10 preempt               standby 10 preempt

! BR_A_SW1
interface Vlan99
 standby 99 priority 110
 standby 99 preempt
```

## Verification

`show standby brief` on both switches shows the expected Active switch per VLAN. Current priorities are tabulated in [addressing.md](../docs/addressing.md#5-hsrp-and-stp).

## Prevention

- Write the design rule as a table (VLAN → STP root → HSRP Active) and audit it after every HSRP or STP change.
- Always set `preempt` together with a priority; a priority without `preempt` does nothing after the first election.
