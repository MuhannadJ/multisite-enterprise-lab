# Minor findings

Smaller defects and quirks that did not need a full incident report.

| Finding | Build day | Resolution |
|---|---|---|
| **Packet Tracer OSPF defect:** inter-area routes missing even with FULL adjacencies. `clear ip ospf process` and a device reload did not help. | Day 2 | `no router ospf 1` and re-adding the process cleared it |
| **INET_RTR1 addressing:** two of three interfaces held addresses outside their own /30. One held an address that belongs to a different /30; another held `.10` in a /30 that only spans .4–.7. | Day 2 | Found by checking each address against the /30 it is cabled into; each interface reassigned (Gi0/0/0 .10, Gi0/0/1 .2, Gi0/0/2 .6) |
| **DHCP pool typo:** the Branch A DATA pool's default gateway was `110.30.10.1` instead of `10.30.10.1`. | Build | Corrected; leases then carried the right gateway |
| **SSH credentials with `@` failed** to authenticate over SSH on this image; root cause not found. | Day 4 | Fleet-wide credentials changed to alphanumeric only |
| **ISR4331 third Gigabit port** is unavailable until a GLC-T module is added while the router is powered off. | Build | Module added where a third interface was needed |
| **New devices start powered off** (WLC and APs). | Day 5 | Powered on and confirmed in the WLC |
| **Port security `protect` mode fails silently on a trunk**, and the per-VLAN `maximum <N> vlan <id>` syntax is rejected. | Day 5 | AP-facing trunks use `violation restrict` with a port-wide `maximum` (values in the final exports: 11 at HQ and DC, 20 at Branch B, 100 at Branch A) |
| **Trust commands rejected on Port-channel interfaces** (`ip dhcp snooping trust`, `ip arp inspection trust`). | Day 4 | Applied on each physical member port |
| **DHCP snooping on BR_B_SW1 dropped every DHCP DISCOVER in VLAN 10**: the switch has no trusted port in that VLAN (its only uplink is routed). Found by a failed lease on PC1 and the Simulation Mode message. | Oct 5 | Global snooping disabled on BR_B_SW1; PC1 then leased 10.40.10.100 and pinged its gateway |
| **TACACS+ logins land at user EXEC (`>`)** rather than privileged EXEC. | Day 5 | Accepted and documented as an open limitation |
| **`show ip interface vlan X` unreliable for ACL bindings** (reports "not set" while enforcing). | Day 5 | Confirm bindings by counters and behaviour (the running-config does not list them after a reload) ([INC-08](INC-08-acls-configured-but-never-bound.md)) |
