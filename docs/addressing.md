# Addressing and design tables

Everything below is taken from the device configurations and the final topology. Hostnames are shown as they appear in the configs; the lab uses a mix of hyphens and underscores (for example `HQ-DIST-SW1` but `HQ_EDGE_RTR1`).

## 1. VLANs

| VLAN | Name | Where | Notes |
|---|---|---|---|
| 10 | DATA | HQ, Branch A, Branch B | User access; `DATA-IN` ACL applied inbound on the SVI |
| 20 | SERVERS | DC only | DHCP/DNS, AAA, Syslog/NTP; `DC-SERVER-ACCESS` applied outbound on the SVI |
| 50 | WIRELESS | All four sites | Client VLAN for `CORP-WIFI` |
| 99 | MGMT | All sites | Device management, APs, WLC |
| 999 | NATIVE | Inter-switch trunks | Unused; native VLAN on all inter-switch trunks. AP-facing ports use native 99 |
| 1 | — | — | Unused; SVI shut down |

## 2. Site subnets

| Site | Supernet | DATA (10) | SERVERS (20) | WIRELESS (50) | MGMT (99) |
|---|---|---|---|---|---|
| HQ | 10.10.0.0/16 | 10.10.10.0/24 | — | 10.10.50.0/24 | 10.10.99.0/24 |
| DC | 10.20.0.0/16 | — | 10.20.20.0/24 | 10.20.50.0/24 | 10.20.99.0/24 |
| Branch A | 10.30.0.0/16 | 10.30.10.0/24 | — | 10.30.50.0/24 | 10.30.99.0/24 |
| Branch B | 10.40.0.0/16 | 10.40.10.0/24 | — | 10.40.50.0/24 | 10.40.99.0/24 |

### Access-switch management addresses (VLAN 99)

The five L2 access switches are managed over VLAN 99 with a static address and the site HSRP VIP as default gateway. The distribution and branch L3 switches use their own VLAN 99 SVI addresses (section 5).

| Switch | Vlan99 address | Default gateway |
|---|---|---|
| HQ_ACC_SW1 | 10.10.99.11 | 10.10.99.1 |
| HQ_ACC_SW2 | 10.10.99.12 | 10.10.99.1 |
| HQ_ACC_SW3 | 10.10.99.13 | 10.10.99.1 |
| DC_ACC_SW1 | 10.20.99.11 | 10.20.99.1 |
| DC_ACC_SW2 | 10.20.99.12 | 10.20.99.1 |

## 3. Loopbacks and OSPF router IDs

Router ID equals Loopback0. INET_RTR1 and the five L2 access switches have no loopback; INET_RTR1 does not run OSPF.

| Device | Loopback0 | Loopback in OSPF area |
|---|---|---|
| HQ_CORE_RTR1 | 10.255.1.1 | 1 |
| HQ_CORE_RTR2 | 10.255.1.2 | 1 |
| HQ-DIST-SW1 | 10.255.1.3 | 1 |
| HQ-DIST-SW2 | 10.255.1.4 | 1 |
| HQ_EDGE_RTR1 | 10.255.1.5 | 0 |
| DC_CORE/DIST_SW1 | 10.255.2.1 | 2 |
| DC_CORE/DIST_SW2 | 10.255.2.2 | 2 |
| DC-EDGE-RTR1 | 10.255.2.3 | 0 |
| ISP-RTR1 | 10.255.0.1 | 0 |
| ISP_RTR2 | 10.255.0.2 | 0 |
| BR_A_SW1 | 10.255.3.1 | 3 |
| BR_A_SW2 | 10.255.3.2 | 3 |
| BR_A_RTR1 | 10.255.3.3 | 0 |
| BR-A-RTR2 | 10.255.3.4 | 3 |
| BR_B_SW1 | 10.255.4.1 | 4 |
| BR_B_RT1 | 10.255.4.2 | 0 |

## 4. Point-to-point links

### Inside the sites

| Link | Subnet | Side A | Side B |
|---|---|---|---|
| HQ_EDGE_RTR1 ↔ HQ_CORE_RTR1 | 10.10.5.0/30 | HQ_EDGE Gi0/0/0 .2 | CORE_RTR1 Gi0/0/0 .1 |
| HQ_CORE_RTR1 ↔ HQ_CORE_RTR2 | 10.10.1.0/30 | CORE_RTR1 Gi0/0/1 .1 | CORE_RTR2 Gi0/0/0 .2 |
| HQ_CORE_RTR1 ↔ HQ-DIST-SW1 | 10.10.2.0/30 | CORE_RTR1 Gi0/0/2 .1 | DIST-SW1 Fa0/6 .2 |
| HQ_CORE_RTR2 ↔ HQ-DIST-SW1 | 10.10.3.0/30 | CORE_RTR2 Gi0/0/1 .1 | DIST-SW1 Fa0/7 .2 |
| HQ_CORE_RTR2 ↔ HQ-DIST-SW2 | 10.10.4.0/30 | CORE_RTR2 Gi0/0/2 .1 | DIST-SW2 Fa0/7 .2 |
| DC-EDGE-RTR1 ↔ DC_CORE/DIST_SW1 | 10.20.2.0/30 | DC-EDGE Gi0/0/0 .2 | SW1 Fa0/3 .1 |
| DC-EDGE-RTR1 ↔ DC_CORE/DIST_SW2 | 10.20.3.0/30 | DC-EDGE Gi0/0/1 .2 | SW2 Fa0/3 .1 |
| DC_CORE/DIST_SW1 ↔ SW2 (routed) | 10.20.1.0/30 | SW1 Fa0/4 .1 | SW2 Fa0/4 .2 |
| BR_A_RTR1 ↔ BR_A_SW1 | 10.30.1.0/30 | BR_A_RTR1 Gi0/0/1 .2 | BR_A_SW1 Fa0/1 .1 |
| BR-A-RTR2 ↔ BR_A_SW2 | 10.30.2.0/30 | BR-A-RTR2 Gi0/0/0 .2 | BR_A_SW2 Fa0/1 .1 |
| BR_B_RT1 ↔ BR_B_SW1 | 10.40.1.0/30 | BR_B_RT1 Gi0/0/0 .2 | BR_B_SW1 Fa0/1 .1 |

HQ-DIST-SW1 ↔ HQ-DIST-SW2 and BR_A_SW1 ↔ BR_A_SW2 are two-port LACP EtherChannels (Po1; Fa0/4–5 at HQ, Fa0/3–4 at Branch A).

### WAN (primary paths, OSPF Area 0)

| Link | Subnet | Side A | Side B |
|---|---|---|---|
| HQ_EDGE_RTR1 ↔ ISP-RTR1 | 172.16.1.0/30 | HQ_EDGE Gi0/0/2 .1 | ISP-RTR1 Gi0/0/0 .2 |
| ISP-RTR1 ↔ ISP_RTR2 | 172.16.0.0/30 | ISP-RTR1 Gi0/0/2 .1 | ISP_RTR2 Gi0/0/1 .2 |
| DC-EDGE-RTR1 ↔ ISP_RTR2 | 172.16.2.0/30 | DC-EDGE Gi0/0/2 .1 | ISP_RTR2 Gi0/0/2 .2 |
| BR_A_RTR1 ↔ ISP-RTR1 | 172.16.3.0/30 | BR_A_RTR1 Gi0/0/0 .1 | ISP-RTR1 Gi0/0/1 .2 |
| BR_B_RT1 ↔ ISP_RTR2 | 172.16.4.0/30 | BR_B_RT1 Gi0/0/2 .1 | ISP_RTR2 Gi0/0/0 .2 |

### Backup underlay via INET_RTR1 (not in OSPF)

| Link | Subnet | Edge router | INET_RTR1 |
|---|---|---|---|
| HQ | 192.168.200.0/30 | HQ_EDGE Gi0/0/1 .1 | Gi0/0/1 .2 |
| Branch A | 192.168.200.4/30 | BR-A-RTR2 Gi0/0/1 .5 | Gi0/0/2 .6 |
| Branch B | 192.168.200.8/30 | BR_B_RT1 Gi0/0/1 .9 | Gi0/0/0 .10 |

INET_RTR1 has only static routes: `10.10.0.0/16` via .1, `10.30.0.0/16` via .5, `10.40.0.0/16` via .9. No ACL, NAT or crypto.

### GRE-over-IPsec tunnels (OSPF Area 0)

| Tunnel | Subnet | HQ end | Spoke end | Source / destination |
|---|---|---|---|---|
| Tunnel1 | 172.16.100.0/30 | HQ_EDGE Tunnel1 .1 | BR-A-RTR2 Tunnel1 .2 | 192.168.200.1 ↔ 192.168.200.5 |
| Tunnel2 | 172.16.101.0/30 | HQ_EDGE Tunnel2 .1 | BR_B_RT1 Tunnel1 .2 | 192.168.200.1 ↔ 192.168.200.9 |

- Tunnel MTU 1476. IPsec is applied with a **crypto map** `VPN-MAP` on Gi0/0/1 (not `tunnel protection`; see [known limitations](known-limitations.md)).
- Phase 1: AES-256, pre-shared key, DH group 5 (`crypto isakmp policy 10`). Phase 2: `esp-aes 256 esp-sha-hmac`, transform set `TS`, tunnel mode.
- Interesting-traffic ACLs, each a single line permitting GRE between the two underlay endpoints: `GRE-TO-BRA` and `GRE-TO-BRB` on HQ, `GRE-TO-HQ` on each spoke.
- Floating default routes (AD 130) on the three edge routers point to the INET_RTR1 address in their underlay /30.

## 5. HSRP and STP

Convention: **VIP .1, SW1 .2, SW2 .3, group number = VLAN ID.** For every VLAN that has an HSRP group the STP root priority is set explicitly (24576 on the intended root, 28672 on the other switch), so the HSRP active switch is also the STP root. All groups use `preempt`.

| Site | VLAN | VIP | SW1 (.2) priority | SW2 (.3) priority | STP root |
|---|---|---|---|---|---|
| HQ | 10 | 10.10.10.1 | 160 | 150 | SW1 |
| HQ | 50 | 10.10.50.1 | 160 | 150 | SW1 |
| HQ | 99 | 10.10.99.1 | 110 | 150 | SW2 |
| DC | 20 | 10.20.20.1 | 150 | 110 | SW1 |
| DC | 50 | 10.20.50.1 | 150 | 110 | SW1 |
| DC | 99 | 10.20.99.1 | 110 | 150 | SW2 |
| Branch A | 10 | 10.30.10.1 | 150 | 110 | SW1 |
| Branch A | 50 | 10.30.50.1 | 150 | 110 | SW1 |
| Branch A | 99 | **10.30.99.10** | 110 | 150 | SW2 |
| Branch B | — | single L3 switch, no HSRP: gateways 10.40.10.1, 10.40.50.1, 10.40.99.1 | | | |

The Branch A VLAN 99 VIP is **.10**, not .1 as at the other sites; both switches agree with each other. See [INC-01](../incidents/INC-01-hsrp-vip-mismatch-branch-a.md).

## 6. OSPF

| Area | Scope | ABR | Type |
|---|---|---|---|
| 0 | WAN core: ISP routers, each edge router's WAN-facing interface, the tunnels, and the loopbacks marked Area 0 in section 3 | — | Backbone |
| 1 | HQ internal L3 | HQ_EDGE_RTR1 | Normal |
| 2 | DC internal L3 | DC-EDGE-RTR1 | Normal |
| 3 | Branch A internal L3 | BR_A_RTR1 (BR-A-RTR2 is also an ABR via the tunnel) | Normal |
| 4 | Branch B internal L3 | BR_B_RT1 | Totally stubby (`stub no-summary` on the ABR, `stub` on BR_B_SW1) |

Each VLAN SVI subnet (10, 20, 50, 99) is advertised into its site's area with a `network` statement. The Packet Tracer routing table sometimes labels routes learned from other areas as "intra area"; this is a display quirk and not a design property.

## 7. NAT/PAT

PAT overload on the site's primary edge router, using an **extended** ACL named `NAT-PAT` that first denies translation to 10.0.0.0/8, 172.16.0.0/16 and 192.168.200.0/24, then permits the site's DATA and MGMT subnets.

| Router | Inside | Outside (PAT address) | Source subnets permitted |
|---|---|---|---|
| HQ_EDGE_RTR1 | Gi0/0/0 | Gi0/0/2 (172.16.1.1) | 10.10.10.0/24, 10.10.99.0/24 |
| DC-EDGE-RTR1 | Gi0/0/0, Gi0/0/1 | Gi0/0/2 (172.16.2.1) | 10.20.20.0/24, 10.20.99.0/24 |
| BR_A_RTR1 | Gi0/0/1 | Gi0/0/0 (172.16.3.1) | 10.30.10.0/24, 10.30.99.0/24 |
| BR_B_RT1 | Gi0/0/0 | Gi0/0/2 (172.16.4.1) | 10.40.10.0/24, 10.40.99.0/24 |

BR-A-RTR2 and the tunnels do not use NAT. WIRELESS (VLAN 50) is not in the PAT ACLs.

## 8. Services

| Service | Host | Address | Notes |
|---|---|---|---|
| DHCP + DNS | Server | 10.20.20.10 | Pools for VLAN 10 (HQ, A, B), VLAN 50 and VLAN 99 per site; relays via `ip helper-address` |
| AAA (TACACS+ and RADIUS) | Server | 10.20.20.11 | TACACS+ tcp/49 for device admin (pilot); RADIUS udp/1812 for wireless 802.1X |
| Syslog + NTP | Server | 10.20.20.12 | Fleet-wide `logging host` and `ntp server`; clock timezone AST (UTC+3) |
| WLC 3504 | HQ | 10.10.99.10 | Management GUI over HTTPS |

Domain name `lab.local` and name-server 10.20.20.10 are set on the 19 managed devices. SNMPv2c read-only is a single `snmp-server community … RO` line on each managed device (the image rejects ACL suffixes, contact, location, host and traps).

## 9. ACL contents

### DATA-IN

Applied **inbound on the VLAN 10 SVI** of HQ-DIST-SW1/SW2, BR_A_SW1/SW2 and BR_B_SW1. The source is that site's own VLAN 10 subnet.

```
deny   ip <site VLAN10 /24> 10.10.99.0 0.0.0.255
deny   ip <site VLAN10 /24> 10.20.99.0 0.0.0.255
deny   ip <site VLAN10 /24> 10.30.99.0 0.0.0.255
deny   ip <site VLAN10 /24> 10.40.99.0 0.0.0.255
permit ip any any
```

### VTY-ACL

Standard ACL on `line vty 0 15` (`access-class VTY-ACL in`) on all managed devices. Permits 10.10.99.0/24, 10.20.99.0/24, 10.30.99.0/24 and 10.40.99.0/24, then an explicit `deny any`. Note: device-originated SSH sources from the exit interface, not VLAN 99, so device-to-device SSH is denied unless sourced from a permitted subnet.

### DC-SERVER-ACCESS ACL

Applied **outbound on the VLAN 20 SVI** of both DC_CORE/DIST switches. 32 lines:

| Lines | Rule | Purpose |
|---|---|---|
| 1 | `permit udp any host 10.20.20.10 eq bootps` | DHCP relay traffic from any site |
| 14 | `permit udp` and `permit tcp` to 10.20.20.10 `eq domain` from 10.10.10.0, 10.10.50.0, 10.20.50.0, 10.30.10.0, 10.30.50.0, 10.40.10.0, 10.40.50.0 (/24 each) | DNS from the DATA and WIRELESS subnets |
| 2 | `permit tcp 10.0.0.0 0.255.255.255` and `172.16.0.0 0.0.255.255` to 10.20.20.11 `eq 49` | TACACS+ |
| 8 | `permit udp` ports 1645 and 1812 to 10.20.20.11 from the four 10.x.99.0/24 subnets | RADIUS from the VLAN 99 subnets (WLC and APs) |
| 4 | `permit udp` ports 514 and 123 to 10.20.20.12 from 10.0.0.0/8 and 172.16.0.0/16 | Syslog and NTP |
| 2 | `permit icmp 10.0.0.0 0.255.255.255 10.20.20.0 0.0.0.255` for `echo` and `echo-reply` | Reachability only |
| 1 | `deny ip any any` | Explicit closer (the image rejects the `log` keyword) |

TACACS+, syslog and NTP are permitted from broad source ranges because the platform has no source-interface option for them, so the source address of device-originated traffic is not predictable.
