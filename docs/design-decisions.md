# Design decisions

Each entry: **decision**, **why**, **trade-off**. Decisions marked *(reversed)* changed during the build.

## Platform

**Cisco Packet Tracer instead of EVE-NG.** No image sourcing or host setup, and the CCNA feature set is covered. *Trade-off:* the simulator's gaps shaped the design; see [known limitations](known-limitations.md).

**HSRP everywhere.** VRRP and GLBP were tested on a throwaway switch pair and rejected on every subcommand. VRRP (open standard, multi-vendor, intended at the DC) and GLBP (active/active load sharing, intended at Branch A) are kept on paper as the original intent. *Trade-off:* the active/standby model is simpler than the original design; load sharing is achieved by alternating HSRP active and STP root per VLAN.

**IP SLA tracking not built.** The plan was an ICMP probe from BR_A_SW1 to 172.16.3.2 (one hop past BR_A_RTR1), tracked into the VLAN 10 HSRP group with a decrement of 60 so BR_A_SW2 takes over if BR_A_RTR1's WAN path fails. `ip sla` does not exist on this image. *Trade-off:* at Branch A the HSRP active switch does not follow WAN health; routing convergence to the tunnel handles it ([V1](verification-report.md#v1--branch-a-wan-failover)).

## Layer 2

**Manual VLAN configuration, no VTP.** Avoids the revision-number overwrite risk. *Trade-off:* every VLAN is entered on every switch, which is exactly where later omissions crept in ([INC-12](../incidents/INC-12-wireless-rollout-defects.md)).

**VLAN scheme.** 10 DATA, 20 SERVERS (DC only), 50 WIRELESS, 99 MGMT, 999 unused native VLAN on inter-switch trunks (AP-facing ports use native 99), VLAN 1 unused with its SVI shut down. VLAN 50 follows the site third-octet convention (10.x.50.0/24).

**Alternating STP root and HSRP active per VLAN.** SW1 is root and HSRP active for the heavier VLAN (10 at HQ and Branch A, 20 at the DC) and secondary for VLAN 99; SW2 is the reverse. Root and gateway stay on the same switch so traffic does not take an extra hop across the inter-switch link. *Trade-off:* the two sets of numbers must be kept aligned by hand ([INC-09](../incidents/INC-09-hsrp-stp-priority-misalignment.md)).

**LACP bundles at HQ and Branch A, a single routed link at the DC.** The DC pair's interconnect is routed, so there is no direct Layer 2 path between the DC switches. This later mattered for Root Guard ([INC-11](../incidents/INC-11-dc-root-guard-blocking-root-election.md)).

**Port security with mixed violation modes.** `protect` fails silently on a trunk, so AP-facing trunk ports use `restrict` with a port-wide `maximum` (this platform rejects per-VLAN maximums). Final values in the exports: 11 at HQ and DC, 20 at Branch B, 100 at Branch A; the Branch A value was set during wireless troubleshooting (see [INC-12](../incidents/INC-12-wireless-rollout-defects.md)).

**DHCP snooping and DAI on VLAN 10 only.** The DC's VLAN 20 holds static servers and has no DHCP clients, so DC access switches are excluded. Branch B is the exception: snooping is disabled globally there because its only uplink is a routed port, which leaves VLAN 10 without a trusted port ([known limitations](known-limitations.md)). Trust is set on each physical member of a Port-channel because the platform rejects it on the logical interface. Option 82 insertion is disabled on the Branch switches so already-relayed requests are not dropped ([INC-12](../incidents/INC-12-wireless-rollout-defects.md)).

## Routing and WAN

**OSPF multi-area following site boundaries, Branch B totally stubby.** Keeps routing tables small at the smallest site and demonstrates the area types. BGP is out of scope.

**Floating static defaults at AD 130.** Subordinate to OSPF and any default OSPF later originates, so they act as the last resort over INET_RTR1. Applied at HQ_EDGE_RTR1, BR-A-RTR2 and BR_B_RT1. The DC is excluded because there is no backup path to point at.

**Backup tunnels as GRE over IPsec, hub and spoke through HQ, with OSPF inside the tunnels.** Tunnel-learned routes are preferred over the floating statics. The IPsec profile / `tunnel protection` method was the first choice and is rejected by the image, so the **legacy crypto map** is used. This is beyond CCNA scope and is documented as such. *Trade-off:* the crypto-map method is the less modern one; see [INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md) for the fault it coincides with.

**Extended `NAT-PAT` ACL that excludes private destinations.** A source-only standard ACL translated inter-site replies and broke TCP between sites ([INC-07](../incidents/INC-07-nat-pat-translating-inter-site-traffic.md)). The extended ACL denies translation to 10.0.0.0/8, 172.16.0.0/16 and 192.168.200.0/24 first.

**Accepted single points of failure.** One edge router at HQ and the DC and one router at Branch B. A second edge router at HQ and the DC was considered and reverted. Branch B stays small on purpose.

**HQ core cabling limited by a three-interface ceiling.** The reference design showed a full distribution-to-core mesh that cannot be built when the core routers have three interfaces each. Final: CORE_RTR1 to DIST-SW1, CORE_RTR2 and the edge; CORE_RTR2 to DIST-SW1, DIST-SW2 and CORE_RTR1. DIST-SW1 has two independent core paths; DIST-SW2 has one direct path plus the peer link.

## Security and management

**SSH-only management with `VTY-ACL`.** Only the four VLAN 99 subnets can reach VTY lines. Credentials are alphanumeric because passwords containing `@` failed over SSH on this image. *Trade-off:* device-originated SSH sources from the exit interface, so device-to-device SSH is denied unless sourced from a permitted subnet.

**TACACS+ for device administration, RADIUS reserved for wireless.** One protocol per job rather than both for admin. TACACS+ is a pilot on two test routers, and the platform supports only the legacy `tacacs-server host/key` syntax. *(reversed once: it was abandoned as a platform limitation, then reopened after a Simulation Mode trace found the real cause, [INC-07](../incidents/INC-07-nat-pat-translating-inter-site-traffic.md).)*

**`DATA-IN` blocks VLAN 10 from every VLAN 99.** Users cannot reach any management subnet at any site, including their own. Applied inbound on the VLAN 10 SVI so it is enforced at the first Layer 3 hop.

**`DC-SERVER-ACCESS` as a per-service allow-list.** DHCP relay from any site, DNS per site subnet, RADIUS only from the VLAN 99 subnets (where the APs live), ICMP echo/echo-reply only, explicit `deny ip any any`. TACACS+, syslog and NTP use broad source ranges because the platform has no source-interface option for them.

## Wireless

**WLC at HQ, not the DC.** The DC has no WAN backup path, while HQ has a floating default and is the hub for both IPsec tunnels. *Trade-off:* every 802.1X exchange depends on the HQ-to-DC path because RADIUS stays on the DC AAA server.

**One company-wide SSID mapped to each site's own VLAN 50.** The first assumption was a per-site SSID; a single SSID with per-site VLAN mapping is the real-world pattern.

**WPA2-Enterprise with PEAP-MSCHAPv2.** EAP-TLS was ruled out as requiring a PKI buildout beyond CCNA scope. WPA2-Personal was rejected because it contradicted the Enterprise design.

**FlexConnect local switching with local authentication ON.** *(reversed.)* Local authentication was first disabled to make the WLC the RADIUS client, then re-enabled after clients could associate only with the HQ AP. With local authentication on, the APs act as the RADIUS clients, which fits `DC-SERVER-ACCESS` permitting RADIUS from the VLAN 99 subnets where the APs live.

**DHCP-based AP discovery instead of static controller addresses.** *(reversed.)* The static `capwap ap controller ip address` plan was replaced by the WLC address in each site's DHCP pool, with VLAN 99 relays built at all four sites to support it.
