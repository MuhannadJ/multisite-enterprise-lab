# Runbooks

Operational procedures for this lab. Each one exists because the lab needed it.

---

## R1 — Re-apply SVI ACL bindings after loading the .pkt

**Symptom.** After loading or reopening the `.pkt`, `DATA-IN` and `DC-SERVER-ACCESS` are no longer enforced. The ACL definitions are still there, but traffic that must be blocked is permitted. R1 restores enforcement, but this image does not list the SVI binding in `show running-config` afterwards (see the note under Verify), so the binding cannot be checked in the config or in an export.

**Cause.** SVI-bound ACL bindings are not in effect after a load in this simulator. Crypto maps and tunnels are not affected by this particular behaviour. `write` does not prevent it: on HQ-DIST-SW1 the binding was applied and saved on Oct 4, Packet Tracer was closed and the `.pkt` reopened, and on Oct 5 traffic that must be blocked passed again with no counter hits. Other users report the same on 3560/3650 switches ([Cisco Community thread](https://community.cisco.com/t5/switching/packet-tracer-acls-remain-in-config-but-stop-working-after/td-p/5378161)). The cause is not understood; the fix is to re-apply the binding.

**Fix.** On HQ-DIST-SW1, HQ-DIST-SW2, BR_A_SW1, BR_A_SW2 and BR_B_SW1:

```
configure terminal
 interface vlan 10
  no ip access-group DATA-IN in
  ip access-group DATA-IN in
 end
```

On DC_CORE/DIST_SW1 and DC_CORE/DIST_SW2:

```
configure terminal
 interface vlan 20
  no ip access-group DC-SERVER-ACCESS out
  ip access-group DC-SERVER-ACCESS out
 end
```

**Verify with traffic and counters, not with `show ip interface` or the config.** `show ip interface vlan X` reports "access list is not set" on this image even when the ACL is enforcing, and after a reload plus R1 `show running-config | include ip access` lists only the ACL definitions, not the `ip access-group` line (HQ-DIST-SW1, Oct 4, while the ACL was enforcing; see [V6](verification-report.md#v6--data-in)).

- `DATA-IN`: ping a host in any site's 10.x.99.0/24 from a VLAN 10 host. It must fail, and the matching `deny` line in `show access-lists DATA-IN` must show a count.
- `DC-SERVER-ACCESS`: renew a DHCP lease from a VLAN 10 host and ping 10.20.20.10. Both must work, and `show access-lists DC-SERVER-ACCESS` must show counts on the DHCP and ICMP lines with 0 on `deny ip any any`.

---

## R2 — Recover a stuck GRE-over-IPsec tunnel

**Status.** Observed to work once (Oct 2–3). Not yet reproduced a second time. The root cause of the fault is unproven ([INC-13](../incidents/INC-13-gre-ipsec-stuck-sa-after-load.md)).

**Detect.** After every load, check both tunnels from HQ_EDGE_RTR1:

```
show crypto isakmp sa
show ip ospf neighbor
```

Healthy: `QM_IDLE` to both 192.168.200.5 and 192.168.200.9, and a FULL OSPF neighbour on Tunnel1 and Tunnel2. Stuck: an entry in `MM_KEY_EXCH` on HQ while the spoke shows no entry or `MM_NO_STATE` with connection ID 0, and the tunnel neighbour missing. In both observed cases the stuck entry was the lower connection ID, the first negotiated.

**Recover** (shown for Branch A; for Branch B use BR_B_RT1 and HQ_EDGE_RTR1 Tunnel2):

1. Shut the tunnel on both ends.

```
! HQ_EDGE_RTR1
interface Tunnel1
 shutdown
! BR-A-RTR2
interface Tunnel1
 shutdown
```

2. Bounce the crypto map on the physical interface of **both stuck ends and HQ**. This briefly interrupts the healthy tunnel as well, because the map is applied to HQ's Gi0/0/1.

```
! BR-A-RTR2 and HQ_EDGE_RTR1
interface GigabitEthernet0/0/1
 no crypto map VPN-MAP
 crypto map VPN-MAP
```

3. Bring HQ's tunnel up **alone** and wait for `QM_IDLE` on HQ.

```
! HQ_EDGE_RTR1
interface Tunnel1
 no shutdown
```

4. Bring the spoke's tunnel up.

```
! BR-A-RTR2
interface Tunnel1
 no shutdown
```

5. Verify: `show crypto isakmp sa` shows `QM_IDLE` for both branches; `show ip ospf neighbor` shows FULL on both tunnels; ping the tunnel addresses (172.16.100.2 and 172.16.101.2 from HQ).

**What did not work.** Removing and re-adding only the single crypto-map entry for the stuck peer left the stale SA in place. `clear crypto isakmp` and `clear crypto sa` are rejected on this image.

---

## R3 — Failover test procedures

Run after R1 and R2 so the baseline is clean. Always restore the link and confirm adjacency before the next test.

### Branch A WAN failover

1. On BR-A-RTR2: `show crypto ipsec sa` (note encaps/decaps).
2. From a Branch A host or switch: `traceroute 10.20.20.10`.
3. On BR_A_RTR1: `interface gigabitethernet 0/0/0` → `shutdown`.
4. Wait about 40 seconds. Repeat the traceroute. Expect the path to cross 172.16.100.1 (HQ end of Tunnel1).
5. On BR-A-RTR2: `show crypto ipsec sa`. Counters must have risen.
6. Restore: `no shutdown` on BR_A_RTR1 Gi0/0/0.

### Branch B WAN failover

1. On BR_B_RT1: `show ip route` (OSPF routes via 172.16.4.2, ISP_RTR2) and `show crypto ipsec sa`.
2. On BR_B_RT1: `interface gigabitethernet 0/0/2` → `shutdown`.
3. Wait for OSPF to converge. The route must now use 172.16.101.1; the counters must rise on the same SA.
4. Traceroute from BR_B_SW1 to 10.20.20.10.
5. Restore: `no shutdown` on Gi0/0/2.

### HQ HSRP data-plane failover

Do **not** use `shutdown` on the SVI as the test: the switch keeps forwarding (see [known limitations](known-limitations.md)).

1. On HQ-DIST-SW1: `show standby brief` (Active for VLANs 10 and 50).
2. On HQ-DIST-SW1: `interface range fastethernet 0/1 - 5` → `shutdown`.
3. From the HQ PC: `ping 10.20.20.10` (must succeed) and ping an address in 10.20.99.0/24 (must fail).
4. On HQ-DIST-SW2: `show access-lists DATA-IN`. The `deny` line for 10.20.99.0 must show matches, which shows SW2 forwarded and enforced the ACL.
5. Restore: `no shutdown` on the range. After `preempt` HQ-DIST-SW1 regains Active.

---

## R4 — Save, export and sanitize

1. After opening the `.pkt` (or any reload), run R1 first and verify it with traffic and counters. `write` does not keep the bindings, and the exported configs will not show the `ip access-group` lines either way.
2. On every device: `end` then `write`.
3. Save the `.pkt` and keep a dated backup copy.
4. Export each running configuration to `<hostname>.txt` in a folder **outside** the repo (replace `/` in a hostname with `-`, so `DC_CORE/DIST_SW1` becomes `DC_CORE-DIST_SW1.txt`).
5. Run `scripts/sanitize-configs.sh <raw-folder> configs/` before committing. It redacts pre-shared keys, TACACS+ keys, SNMP community strings and password hashes.
