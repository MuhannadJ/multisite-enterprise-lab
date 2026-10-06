# Known limitations

Three kinds of limitation, kept separate on purpose:

- **Platform** — the Packet Tracer image cannot do it.
- **Design** — an accepted trade-off.
- **Open** — a defect or behaviour with an unproven cause.

## Platform limitations

| Limitation | Impact | What was done instead |
|---|---|---|
| VRRP and GLBP commands rejected on the 3560 image (every subcommand returns `% Invalid input detected`) | Cannot demonstrate open-standard FHRP (intended at DC) or active/active load sharing (intended at Branch A) | HSRP everywhere; VRRP and GLBP rationale kept in [design decisions](design-decisions.md) |
| `ip sla` not supported | The intended SLA-tracked HSRP priority decrement at Branch A (BR_A_SW1 probing 172.16.3.2, decrement 60 on VLAN 10) could not be built | Documented as intended; Branch A relies on routing convergence to the tunnel |
| `crypto ipsec profile` and `tunnel protection` rejected | Modern IPsec-on-tunnel method unavailable | Legacy crypto map `VPN-MAP` on the physical interface |
| `clear crypto isakmp` / `clear crypto sa` rejected | No clean way to flush a stale SA | Procedure in [runbooks R2](runbooks.md#r2--recover-a-stuck-gre-over-ipsec-tunnel) |
| `log` keyword on ACL lines rejected (whole line invalid) | No ACL logging | Plain `deny ip any any` and `show access-lists` counters |
| `logging trap informational`, SNMP contact/location/host/traps, ACL suffix on the SNMP community rejected | No SNMP traps; no ACL-restricted community | Single `snmp-server community … RO` line |
| `aaa group server tacacs+` and `ip tacacs source-interface` rejected; only legacy `tacacs-server host/key` syntax | Source address of AAA traffic unpredictable | Broad source ranges in `DC-SERVER-ACCESS` |
| `ip dhcp snooping trust` / `ip arp inspection trust` rejected on Port-channel interfaces | Trust must be set on each member port | Applied per physical port |
| `show ip interface vlan X` unreliably reports "access list is not set" | Cannot confirm SVI ACL binding with that command | Confirm with counters or a blocked/permitted test; after a reload the running-config does not list the binding either (next row) |
| `terminal length 0` and `show spanning-tree root` unavailable | Minor | — |
| Shutting an SVI does not stop that switch forwarding or enforcing its ACL | SVI shutdown is not a valid HSRP data-plane failover test | Isolate the switch at port level ([V4](verification-report.md#v4--hq-hsrp-data-plane)) |
| ISR4331 exposes only two built-in Gigabit ports plus an SFP slot; a GLC-T module added while powered off unlocks the third | A ceiling of three interfaces per router drove the HQ core cabling | GLC-T module added to the routers that needed a third interface |
| New devices start powered off | Easy to miss on the WLC and APs | Checked at build |
| Wireless AP range: at 20–30 m most phones did not associate; at 100 m they do, but some join an AP at another site (cause not isolated; Packet Tracer's help ties wireless range to its Physical workspace, which was not examined) | Per-site AP selection, multi-AP roaming and failover could not be demonstrated | Range left at 100 m; AP join confirmed via the WLC; client logins shown at HQ, DC, Branch B |
| Routes from other areas are sometimes labelled "intra area" | Display quirk | Noted only |
| SSH logins whose password contains `@` failed | Credentials limited to alphanumerics | See [minor findings](../incidents/minor-findings.md) |
| After loading or reopening the `.pkt`, SVI ACL bindings are not in effect, and after re-applying them this image still does not list the `ip access-group` line in the running-config (tested on HQ-DIST-SW1) | Security controls silently absent after a reload; the files in `configs/` show the ACLs defined but not their bindings | Re-apply script in [runbooks R1](runbooks.md#r1--re-apply-svi-acl-bindings-after-loading-the-pkt); the ACL definitions themselves persist. `write` does not keep the binding (saved, closed and reopened: gone). Enforcement is evidenced by counters and pings ([V6](verification-report.md#v6--data-in)), not by the configs |

## Design limitations (accepted)

| Limitation | Rationale |
|---|---|
| One edge router at HQ and at the DC; one router at Branch B | A second edge router at HQ and the DC was considered and reverted; Branch B was kept deliberately small, consistent with its totally stubby area |
| DC has no independent backup WAN path and no GRE-over-IPsec tunnel | The DC relies on rerouting through the WAN core; INET_RTR1 is wired only to HQ and the two branches |
| HQ_EDGE_RTR1 is single-homed to HQ_CORE_RTR1 | All three of its interfaces are in use (core, ISP, INET) |
| GRE-over-IPsec is beyond CCNA scope | Included as a stretch goal; documented as such rather than presented at the same mastery tier |
| TACACS+ is a pilot on two routers (HQ_EDGE_RTR1, BR_B_RT1); logins land at `>` | Piloted on two test devices; all others use local accounts |
| PAT ACLs cover DATA and MGMT only; WIRELESS (VLAN 50) is not translated | The topology contains no Internet-facing host, so the PAT behaviour demonstrated is the exclusion of inter-site traffic ([INC-07](../incidents/INC-07-nat-pat-translating-inter-site-traffic.md)) |
| DC-SERVER-ACCESS permits TACACS+, syslog and NTP from broad 10.0.0.0/8 and 172.16.0.0/16 ranges | No source-interface option for these on the platform |
| Port-level hardening is uneven on the distribution layer: unused ports are left up on the HQ and DC distribution switches, and the PortFast/BPDU Guard defaults are set only on the L2 access switches | Not hardened; listed so it is not mistaken for coverage |
| Unused FastEthernet ports are shut on the L2 access and branch switches, but their two Gigabit ports (Gi0/1–2) are left up and unconfigured; the HQ and Branch A SVIs are not set passive for OSPF (the DC and Branch B SVIs are) | Not hardened; listed so it is not mistaken for coverage |
| ISP-RTR1, ISP_RTR2 and INET_RTR1 are unhardened | They model provider equipment outside the enterprise's control |
| Management only via VLAN 99 sources; device-to-device SSH is mostly denied by `VTY-ACL` | Intentional trade-off of the SSH-only policy |
| DHCP snooping and DAI run on VLAN 10 only; DC access switches excluded | VLAN 20 carries static servers and has no DHCP clients |
| DHCP snooping is disabled globally on BR_B_SW1; its VLAN 10 snooping and DAI lines remain configured | Branch B has no working DHCP snooping. With snooping on, Packet Tracer dropped every DHCP DISCOVER in VLAN 10 ("not configured with a functional and trusted port"), because the switch's only uplink is a routed port and the VLAN has no trusted port. HQ and Branch A keep snooping and DAI |

## Open items

| Item | Status |
|---|---|
| GRE-over-IPsec: after loading the `.pkt`, one of HQ's two tunnels can be stuck on a stale half-open ISAKMP SA | Seen on both loads tested, a different branch each time. Config verified correct (keys, policy, transform set, maps and ACLs mirror each other; identical model and licence on all routers). Cause unproven; a startup race between the two negotiations is a hypothesis only. Workaround in [runbooks R2](runbooks.md#r2--recover-a-stuck-gre-over-ipsec-tunnel) |
| `ACTIVE (deleted)` flag on BR-A-RTR2's ISAKMP entry while Tunnel1 is FULL | Meaning not established |
| HQ RADIUS permit line on the rebuilt `DC-SERVER-ACCESS` | Rule is present; no match counter captured |
| Five rule groups with zero hits in the final capture (DNS, TACACS+, RADIUS, 172.16.0.0/16 syslog, `echo-reply`) | Reported by the operator during testing, not captured in the final counters ([V5](verification-report.md#v5--dc-server-access-final-state)) |
