# INC-10 — HQ VLAN 50 HSRP and STP split-brain

| | |
|---|---|
| **Severity** | P2 — HQ wireless VLAN had no stable gateway or loop-free topology |
| **Type** | Real defect (config fault first, then a simulator state bug) |
| **Build days** | Sept 27–29 |
| **Devices** | HQ-DIST-SW1, HQ-DIST-SW2, HQ_ACC_SW3 |
| **Status** | Resolved (second phase only by restarting Packet Tracer) |

This incident has two phases with different causes. Keeping them apart was the hard part.

## Phase 1 — HSRP: both switches Active

**Symptom.** After building VLAN 50 at HQ, `show standby brief` showed **both** switches Active for VLAN 50 with `Standby: unknown`. HSRP hellos were not crossing the Port-channel between them even though `switchport trunk allowed vlan add 50` had been entered.

**Diagnosis.** Compared the Port-channel's logical interface with its physical members on each switch. Fa0/4 and Fa0/5 (the Po1 members) and Po1 itself **disagreed about whether VLAN 50 was allowed, in opposite directions on each switch**. The members had their own trunk allowed-VLAN lists, still reading 10, 99, 999.

**Fix.** Aligned the allowed-VLAN list on Po1 and on both member ports on both switches, then removed and re-added the channel-group on each switch so the bundle re-formed with consistent settings.

**Result.** HSRP for VLAN 50 formed a normal Active/Standby pair.

## Phase 2 — STP: three roots for one VLAN

**Symptom.** HQ-DIST-SW1, HQ-DIST-SW2 and HQ_ACC_SW3 **each showed themselves as the root bridge for VLAN 50 at the same time**, with contradictory Designated/Blocked port roles on the same links.

**What was ruled out.** The fault survived all of these:

- bouncing Port-channel1,
- deleting and re-creating VLAN 50,
- individually reloading HQ-DIST-SW1 and HQ-DIST-SW2.

A side-by-side comparison of the three switches' configs found **no discrepancy**, so it was not a configuration fault.

**Fix.** Only **closing and reopening Packet Tracer** cleared it. After the restart VLAN 50 had a single shared root across all three switches and consistent port roles. This matches a category of Packet Tracer STP bug reported in the wider community.

## Lesson

- When the config comparison is clean and the symptom survives reloads, stop editing config. Name the point at which the simulator itself becomes the suspect and restart it.
- Compare a bundle's logical interface **and** its members; they carry independent settings.
- A fix in one layer (HSRP) can expose a different fault in the next (STP). Re-verify at every layer after each change.

## Prevention

- After building a VLAN across a Port-channel, check `show interfaces trunk` on the members and the Port-channel on **both** switches.
- Keep the config-comparison step in the runbook before any destructive step (VLAN delete, reload).
