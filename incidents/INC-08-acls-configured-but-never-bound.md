# INC-08 — ACLs configured but never bound to interfaces

| | |
|---|---|
| **Severity** | P2 — security controls appeared configured but were not enforced |
| **Type** | Unplanned defect in the build (not planted) |
| **Build days** | Day 5 |
| **Devices** | HQ-DIST-SW1/SW2, BR_A_SW1/SW2, BR_B_SW1 (`DATA-IN`); DC_CORE/DIST_SW1/SW2 (`DC-SERVER-ACCESS`) |
| **Status** | Resolved; a reload behaviour is documented in [runbooks R1](../docs/runbooks.md#r1--re-apply-svi-acl-bindings-after-loading-the-pkt) |

## Symptom

- **`DATA-IN`:** a PC at HQ (10.10.10.101) could ping the HQ MGMT gateway 10.10.99.1, which the ACL was supposed to block.
- **`DC-SERVER-ACCESS`:** the ACL existed on both DC switches but the VLAN 20 SVI showed "Outgoing access list is not set".

## Diagnosis

1. For `DATA-IN`, the permitted ping showed the ACL was **not in effect** on the HQ gateway. The ACL text was correct; the `ip access-group` line was missing from the VLAN 10 SVI.
2. After `ip access-group DATA-IN in` was applied on VLAN 10 of HQ-DIST-SW1 and SW2, the same ping failed, and the matching deny line in `show access-lists DATA-IN` showed hits.
3. The same omission was then fixed on BR_A_SW1, BR_A_SW2 and BR_B_SW1.
4. For `DC-SERVER-ACCESS`, `show running-config` confirmed the binding was missing on both DC switches.

## Complication: the status output is unreliable in this Packet Tracer image

On this image `show ip interface vlan X` keeps saying **"access list is not set"** even when the ACL is demonstrably enforcing (seen on HQ-DIST-SW2 while a ping was being blocked, and on DC_CORE/DIST_SW1 after the fix). Binding was therefore confirmed by three independent methods, never by that line:

- `show running-config` (the `ip access-group` line was present at that time; after a reload it is not listed, see below),
- match counters in `show access-lists`,
- a Simulation Mode PDU trace (on DC_CORE/DIST_SW1).

## Root cause

The ACLs were defined but the build step that binds them to an interface (`ip access-group … in|out`) was omitted. A defined ACL does nothing until it is applied.

## Fix

```
interface Vlan10                      ! HQ/Branch gateway switches
 ip access-group DATA-IN in
interface Vlan20                      ! both DC switches
 ip access-group DC-SERVER-ACCESS out
```

## Related finding after a reload

After loading or reopening the `.pkt`, SVI-bound ACLs are not in effect until re-applied (`no ip access-group …` then `ip access-group …`). The ACL definitions persist, but no `ip access-group` lines appeared in the configs exported after a reload. On Oct 4 this was re-tested on HQ-DIST-SW1: R1 restored enforcement (counters and a blocked ping) but `show running-config | include ip access` still listed only the ACL definitions, so the exported configs cannot show the bindings. A save followed by closing and reopening the `.pkt` also lost the binding on HQ-DIST-SW1, so `write` does not protect it. The re-apply script is in [runbooks R1](../docs/runbooks.md#r1--re-apply-svi-acl-bindings-after-loading-the-pkt).

## Prevention

- **A defined ACL is not an enforced ACL.** Every ACL change ends with a traffic test that must fail (or pass) and a counter check.
- Never trust a single status display; use configuration, counters and behaviour together.
- After any reload, re-verify security controls before trusting the lab.
