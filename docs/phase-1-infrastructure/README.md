# Phase 1 — Network Infrastructure & Active Directory

## Overview

This phase establishes the foundation for the entire lab environment: a segmented network with centralized identity management that mirrors a real business IT infrastructure. Every subsequent phase (backup, patching, hardening, monitoring) depends on this foundation being solid.

## Network Design

### IP Addressing Scheme

| Network | Subnet | VLAN | Purpose | VMware Network |
|---|---|---|---|---|
| WAN | DHCP from VMware NAT | — | Internet access via pfSense | VMnet10 (NAT) |
| LAN (Servers) | 192.168.10.0/24 | — | Production servers and clients | VMnet11 (Host-only) |
| Management | 192.168.20.0/24 | — | Administrative access (future use) | VMnet12 (Host-only) |

### Static IP Assignments

| Host | IP Address | Role | OS |
|---|---|---|---|
| pfSense | 192.168.10.1 | Gateway, firewall, DHCP server | FreeBSD (pfSense CE) |
| DC01 | 192.168.10.10 | Domain controller, DNS | Windows Server 2022 |
| SRV-LINUX01 | 192.168.10.20 | Linux application server | Ubuntu Server 24.04 LTS |
| BKP01 | 192.168.10.30 | Backup server (Veeam B&R) | Windows Server 2022 |
| WIN11-CLIENT | 192.168.10.103 | User workstation (DHCP reservation) | Windows 11 Enterprise |

### DHCP Configuration

- DHCP server: pfSense (LAN interface)
- Dynamic range: 192.168.10.100 – 192.168.10.200
- Static assignments: 192.168.10.1 – 192.168.10.99 (reserved for infrastructure)
- DHCP reservation for WIN11-CLIENT pinned by MAC address

## VM Specifications

| VM | vCPU | RAM | Disk | Network | Notes |
|---|---|---|---|---|---|
| pfSense | 1 | 1 GB | 20 GB | VMnet10 + VMnet11 | Dual NIC: WAN + LAN |
| DC01 | 2 | 4 GB | 60 GB | VMnet11 | Desktop Experience |
| SRV-LINUX01 | 2 | 2 GB | 40 GB | VMnet11 | OpenSSH enabled |
| BKP01 | 2 | 4–6 GB | 80 GB + 100 GB | VMnet11 | Second disk for backup repo |
| WIN11-CLIENT | 2 | 4 GB | 60 GB | VMnet11 | Domain-joined |

All virtual disks are thin-provisioned to conserve host storage.

## Build Sequence

The build order matters because of dependencies:

1. **pfSense** — everything else depends on it for DHCP, routing, and internet access
2. **DC01** — provides DNS and AD for domain-joining subsequent machines
3. **SRV-LINUX01** — Linux server, configured with static IP via netplan
4. **BKP01** — backup server, domain-joined, second disk added for repository
5. **WIN11-CLIENT** — user workstation, domain-joined, DHCP reservation configured

## Active Directory Configuration

- **Forest functional level:** Windows Server 2016
- **Domain:** lab.local
- **Domain controller:** DC01.lab.local
- **DNS:** Integrated with AD DS (DC01 serves as primary DNS for the LAN)

### Group Policy Objects

| GPO Name | Scope | Purpose |
|---|---|---|
| Lab-Firewall-Allow-ICMP | Domain-wide | Enables ICMP Echo Request on Domain, Private, and Public firewall profiles for all domain members |

## Linux Server Configuration (SRV-LINUX01)

### Netplan Static IP Configuration

File: `/etc/netplan/50-cloud-init.yaml`

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      addresses:
        - 192.168.10.20/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses:
          - 192.168.10.10
        search:
          - lab.local
```

### Key Linux Configuration Steps

- systemd-networkd enabled and started (required as the netplan renderer)
- systemd-resolved enabled for DNS resolution
- OpenSSH server installed and listening on port 22 (all interfaces)
- Hostname set via `hostnamectl set-hostname srv-linux01`
- `labadmin` user with sudo privileges (used for Veeam agent deployment via SSH)
