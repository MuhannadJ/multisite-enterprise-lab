# Troubleshooting

**Method:** scope first (which device, site or path), evidence from `show` commands, change one thing, then verify.

| Problem reported | What I did | Root cause and fix |
|---|---|---|
| **TACACS+ logins to the data-center server failed between sites**<br>[INC-07](incidents/INC-07-nat-pat-translating-inter-site-traffic.md) | Questioned the "platform limitation" conclusion. Followed the TCP handshake hop by hop in Simulation Mode. | PAT rewrote the server's replies (source 10.20.20.11 became 172.16.2.1), so the client sent a TCP reset. Replaced the NAT ACL with a destination-scoped one on all four edge routers. TACACS+ then worked. |
| **Tunnel to Branch B would not come up**<br>[INC-04](incidents/INC-04-ipsec-psk-mismatch-hq-branch-b.md) | Scoped the fault to the Branch B pair, then compared the two pre-shared keys character by character. | Same characters in a different order. Made the keys identical: tunnel up, OSPF neighbour FULL. |
| **Core WAN router could not form OSPF adjacencies on two links**<br>[INC-02](incidents/INC-02-isp-rtr2-swapped-interface-addresses.md) (P1) | Checked every interface address against the /30 it is cabled into. | Two interfaces held each other's addresses. Reassigned them and the adjacencies formed. The same check later found two out-of-range addresses on another router. |
| **New devices at Branch B got no IP address**<br>[INC-06](incidents/INC-06-branch-b-dhcp-blocked-by-dc-acl.md) | Scoped first: HQ and Branch A worked, so the server and the OSPF path were unlikely. Reviewed the data-center server ACL. | Branch B's relay address was missing from the ACL. Two more gaps found beside it (no final deny, a truncated line). Rebuilt the ACL on both data-center switches. |
| **HQ users got 169.254.x.x addresses, but only when one switch was down**<br>[INC-05](incidents/INC-05-dhcp-helper-address-wrong-hq-dist-sw2.md) | Saw that the failure followed the gateway switch doing the relaying. Compared the DHCP relay line on the redundant pair. | HQ-DIST-SW2 pointed at 10.20.20.101 instead of 10.20.20.10, a typo hidden while SW1 was up. Fixed; redundant peers are now compared as a routine check. |

**Also documented:** 8 more incidents, including ACLs that were configured but never applied (confirmed by counters, blocked pings and a packet trace, because the status command was wrong), a spanning-tree root blocked by Root Guard, and a wireless rollout step missed at different sites.

One issue is still open. After loading the lab, one GRE-over-IPsec tunnel can stick. The cause is unproven, six hypotheses were ruled out, and the recovery steps are documented ([INC-13](incidents/INC-13-gre-ipsec-stuck-sa-after-load.md)).

All reports: [incidents/](incidents/README.md) · Ten selected findings: [key findings](docs/key-findings.md) · [Back to the README](README.md)
