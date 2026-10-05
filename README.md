# Multi-Site Enterprise Network Lab

A four-site enterprise network (HQ, data center, two branches, WAN) built in Cisco Packet Tracer, then **troubleshot, hardened and failover-tested** the way a NOC would run it.

**Read next:** [Troubleshooting](TROUBLESHOOTING.md) · [Key findings](docs/key-findings.md) · [Full overview](docs/full-overview.md) · [All 13 incident reports](incidents/README.md) · [Device configs](configs/README.md)

![Packet Tracer topology](docs/img/topology.png)

*Topology as built in Packet Tracer. The dotted lines are wireless associations; some phones joined an AP at another site (see [known limitations](docs/known-limitations.md)).*

---

## What was built

| | |
|---|---|
| **Scale** | 22 routers and switches, a wireless controller, 4 access points, 3 servers, 4 sites |
| **Routing** | OSPF in 5 areas (Branch B totally stubby), floating static backup routes |
| **Redundancy** | HSRP gateway pairs aligned with STP roots, LACP EtherChannel, GRE-over-IPsec backup tunnels to both branches (a stretch goal beyond CCNA) |
| **Security** | SSH-only management with a VTY ACL on 19 devices, two traffic ACLs, DHCP snooping and DAI (not at Branch B), port security |
| **Services** | Central DHCP/DNS, AAA, syslog/NTP, SNMPv2c, PAT on all four edge routers |
| **Wireless** | WPA2-Enterprise (802.1X): one controller, four access points, one per site |

## What was proven

| Test | Result | Evidence |
|---|---|---|
| Branch A and Branch B primary WAN link down | Traffic moves to the IPsec tunnel | Captured output |
| HQ gateway failover | Pass, including the data plane (switch isolated at port level) | Captured output |
| `DATA-IN` ACL blocks user VLAN → management VLAN | Pass | Blocked ping + counters (tested on HQ-DIST-SW1) |
| `DC-SERVER-ACCESS` ACL final state | 0 hits on the closing `deny ip any any` | Captured output |
| DHCP relay and leases at HQ, Branch A, Branch B | Pass | Operator-observed |
| Wireless client login at HQ, DC, Branch B | Pass (Branch A not confirmed) | Operator-observed |

## What did not work

- **Packet Tracer cannot do** VRRP, GLBP, IP SLA or modern IPsec profiles. HSRP and crypto maps replaced them.
- **One backup tunnel can get stuck after the file is loaded.** The cause is unproven; a recovery procedure is documented ([INC-13](incidents/INC-13-gre-ipsec-stuck-sa-after-load.md)).
- **Wireless AP selection is not controlled.** At an AP range of 20–30 m most phones could not associate; at 100 m they do, but some join an AP at another site. Cause not isolated. A Branch A client login was not confirmed.
- **TACACS+** is a two-router pilot only.

Full list: [known limitations](docs/known-limitations.md).

---

**Skills shown:** OSPF · HSRP · STP and EtherChannel · VLANs and trunking · ACLs · NAT/PAT · DHCP snooping and DAI · GRE-over-IPsec · RADIUS 802.1X · structured troubleshooting

*Method: the design brief, build configurations and seeded faults were prepared with Claude (an AI assistant). I built the network in Packet Tracer, ran the tests and troubleshot the faults.*

*Author: Muhannad · CCNA 200-301. Contact details are on my GitHub profile.*
