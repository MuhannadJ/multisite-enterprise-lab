# INC-11 — Root Guard blocking root election at the DC

| | |
|---|---|
| **Severity** | P2 — VLAN 99 at the DC could not converge on its intended root |
| **Type** | Unplanned defect in the build (not planted) |
| **Build day** | Sept 29 |
| **Devices** | DC_CORE/DIST_SW1 (two switchports) |
| **Status** | Resolved by configuration alone |

## Symptom

DC_CORE/DIST_SW1 could never converge on the correct STP root for VLAN 99, which was needed for the DHCP/management relay for the wireless APs.

## Diagnosis

1. Same symptom class as [INC-10](INC-10-hq-vlan50-split-brain.md), which had been a simulator bug cured only by restarting. This time that was **not assumed**.
2. Compared the STP topology at the DC with HQ. At HQ the two distribution switches have a direct trunked Port-channel between them. At the DC the interconnect between the two core/distribution switches is **routed**, so there is no direct Layer 2 path between them.
3. Because of that, SW1's only Layer 2 route to the intended VLAN 99 root (SW2) runs through its two access-facing switchports. **Root Guard was configured on both** of those ports.

## Root cause

Root Guard puts a port that receives superior BPDUs into root-inconsistent (blocking) state. Applied to the only ports through which SW1 can learn about the real root, it left SW1 unable to accept SW2 as root. The HQ pattern (Root Guard on downlinks toward access switches) had been applied in a topology where those ports are also the path to the root.

## Fix

```
interface <each of the two ports>
 no spanning-tree guard root
```

## Verification

VLAN 99 converged on the intended root **without a reload or a restart of Packet Tracer**. That outcome is what separates this incident from INC-10: it was a topology-aware configuration error, not corrupted STP engine state.

## Prevention

- Root Guard belongs on ports where a superior BPDU should never arrive. If the only Layer 2 route to the intended root runs through a port, that port will legitimately receive superior BPDUs and must not have Root Guard.
- Do not apply a security feature from one site to another without re-reading the other site's Layer 2 topology; HQ and the DC differ here.
- Try a config-level cause before blaming the simulator.
