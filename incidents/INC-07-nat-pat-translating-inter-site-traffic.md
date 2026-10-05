# INC-07 — PAT translating inter-site traffic; TACACS+ connections reset

| | |
|---|---|
| **Severity** | P2 — TCP services between sites failed; ICMP hid the problem |
| **Type** | Real defect in the build (not planted) |
| **Build days** | Day 4 (first seen), Day 5 (HQ manifestation and final fix) |
| **Devices** | DC-EDGE-RTR1, HQ_EDGE_RTR1, BR_A_RTR1, BR_B_RT1 |
| **Status** | Resolved on all four edge routers |

## Symptom

TACACS+ logins from BR_B_RT1 to the AAA server (10.20.20.11) failed at the TCP level. The failure survived a full rebuild of the AAA server and a router reload. Both `ip tacacs source-interface` and `aaa group server tacacs+` were rejected by the image, so the first conclusion was **"platform limitation"** and TACACS+ was rolled back to local-only login.

## Diagnosis

The "platform limitation" conclusion was reopened and tested at packet level in Packet Tracer **Simulation Mode**, following the TCP handshake hop by hop:

1. BR_B_RT1's SYN reached the AAA server.
2. The server's SYN-ACK left the DC.
3. At DC-EDGE-RTR1 the SYN-ACK's **source address was rewritten** from 10.20.20.11 to **172.16.2.1**, DC-EDGE-RTR1's own outside address.
4. BR_B_RT1 received a SYN-ACK from an address it had never contacted, did not match it to its connection, and sent a **TCP RST**.

## Root cause

`ip nat inside source list 1 interface GigabitEthernet0/0/2 overload` used a standard ACL (`access-list 1`, permitting 10.20.20.0/24 and 10.20.99.0/24) that matches on **source only**. DC-EDGE-RTR1's Gi0/0/2 is the DC's only path to both the Internet and the other sites, so replies from the DC servers to other sites were translated like Internet-bound traffic.

ICMP was unaffected, which is why basic pings looked healthy; only TCP sessions started *from another site toward the DC* broke.

## Same bug, other routers

- **HQ_EDGE_RTR1:** a DC-initiated ping to 172.16.1.1 showed HQ's replies rewritten by the HQ NAT table while DC's fixed router translated nothing on the same ping. HQ was initially left as a known suspect (ICMP unaffected), then fixed.
- **HQ DHCP relay (Day 5 closing):** HQ's DHCP relay traffic to the DC was translated to 172.16.1.1, so it never matched `DC-SERVER-ACCESS`'s permit lines and fell through to the deny. The same fault class, shown by a different service.
- **BR_A_RTR1, BR_B_RT1:** same source-only pattern; fixed with the same template.

## Fix

Replace the standard ACL with an extended `NAT-PAT` ACL that **denies translation to private destinations first**, then permits the site's DATA and MGMT subnets, and rebind the NAT statement:

```
ip access-list extended NAT-PAT
 deny   ip <site DATA /24> 10.0.0.0 0.255.255.255
 deny   ip <site DATA /24> 172.16.0.0 0.0.255.255
 deny   ip <site DATA /24> 192.168.200.0 0.0.0.255
 deny   ip <site MGMT /24> 10.0.0.0 0.255.255.255
 deny   ip <site MGMT /24> 172.16.0.0 0.0.255.255
 deny   ip <site MGMT /24> 192.168.200.0 0.0.0.255
 permit ip <site DATA /24> any
 permit ip <site MGMT /24> any
!
no ip nat inside source list 1 interface <outside> overload
ip nat inside source list NAT-PAT interface <outside> overload
no access-list 1
```

Full per-router values: [addressing.md](../docs/addressing.md#7-natpat).

## Verification

- TACACS+ retested after the DC fix and worked.
- At HQ: DHCP leases succeeded and a PDU capture in Simulation Mode showed the **untranslated source address** on the relayed request.
- The final `DC-SERVER-ACCESS` capture shows 0 matches on its `deny ip any any` ([V5](../docs/verification-report.md#v5--dc-server-access-final-state)).

## Prevention

- A NAT ACL on a router that is also the inter-site path must be **destination-scoped**: exclude every internal range before permitting the rest.
- Testing with ICMP only proves routing, not NAT behaviour. Test with TCP and UDP from the **far side**.
- Do not accept "platform limitation" for a TCP failure before a packet-level look. A RST with an unexpected source address is a NAT clue.
