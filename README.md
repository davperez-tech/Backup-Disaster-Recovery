# Infrastructure Lab — Backup & Disaster Recovery

A hands-on infrastructure project simulating a business IT environment with enterprise-grade backup and disaster recovery architecture. Built on VMware Workstation with segmented networking, Active Directory, and a full 3-2-1 backup implementation using Veeam Backup & Replication and AWS S3 with Object Lock immutability.

---

## Project Summary

| Component | Detail |
|---|---|
| **Environment** | VMware Workstation |
| **Operating Systems** | Windows Server 2022, Windows 11 Enterprise, Ubuntu Server 24.04 LTS |
| **Network** | Segmented VLANs via pfSense CE — WAN, LAN (servers), Management |
| **Identity** | Active Directory Domain Services with DNS and Group Policy |
| **Backup Platform** | Veeam Backup & Replication v13 Community Edition |
| **Cloud Tier** | AWS S3 with Object Lock |
| **Backup Strategy** | 3-2-1: production data + local repository + immutable off-site cloud |
| **Validation** | File-level restore and bare-metal recovery drills |

---

## Architecture
<p align="center">
  <img width="534" height="457" alt="Lab Diagram (1)" src="https://github.com/user-attachments/assets/c16e7de3-6283-477f-916a-b279315eb06c" />
</p>

---

## Table of Contents

- [Phase 1 — Network Infrastructure & Active Directory](#phase-1--network-infrastructure--active-directory)
- [Phase 2 — Backup, Cloud Replication & Disaster Recovery](#phase-2--backup-cloud-replication--disaster-recovery)
- [Restore Drill Results](#restore-drill-results)
- [Lessons Learned & Incidents](#lessons-learned--incidents)

---

## Phase 1 — Network Infrastructure & Active Directory

**Objective:** Build a segmented, domain-joined network environment that mirrors a real business with proper routing, DNS, DHCP, and centralized identity management.

### What Was Built

**Network Segmentation with pfSense CE**
- Three isolated VMware virtual networks: WAN (VMnet10/NAT), LAN (VMnet11/Host-only), Management (VMnet12/Host-only)
- pfSense firewall routing between segments with DHCP on the LAN (`192.168.10.100–200`)
- Static IP assignments for all infrastructure servers; DHCP reservations for client workstations
- Outbound internet access through NAT for patching and cloud connectivity

**Active Directory Domain Services**
- Windows Server 2022 domain controller (`DC01`) running AD DS, DNS, and Group Policy
- New forest: `lab.local` with a single domain
- DNS integrated with AD for dynamic registration and SRV record resolution
- Group Policy Objects deployed for centralized firewall rule management (ICMP allow across all domain members)

**Server Infrastructure**
- `DC01` (192.168.10.10) — Domain controller, DNS, NTP source, Group Policy management
- `BKP01` (192.168.10.30) — Dedicated backup server with separate 100GB repository disk (thin-provisioned, GPT, NTFS)
- `SRV-LINUX01` (192.168.10.20) — Ubuntu Server 24.04 LTS with static IP via netplan, SSH enabled
- `WIN11-CLIENT` (192.168.10.103) — Domain-joined Windows 11 Enterprise workstation with DHCP reservation

**Key Design Decisions**
- Dedicated backup server rather than installing Veeam on the domain controller — follows the principle of role separation and prevents backup failures from impacting authentication services
- Thin-provisioned virtual disks to maximize host storage efficiency — the same approach used in enterprise VMware environments to manage storage overcommit ratios
- GPO-based firewall management rather than per-machine configuration — ensures consistency across all current and future domain members without manual intervention

> **Full Phase 1 documentation:** [docs/phase-1-infrastructure/](docs/phase-1-infrastructure/)

---

## Phase 2 — Backup, Cloud Replication & Disaster Recovery

**Objective:** Implement a complete 3-2-1 backup architecture with local fast-restore capability and ransomware-resistant off-site immutability, then validate it through documented restore drills.

### 3-2-1 Backup Architecture

| Copy | Location | Purpose | Technology |
|---|---|---|---|
| **Copy 1** | Production VMs | Live data | VMware Workstation guest disks |
| **Copy 2** | Local repository (`E:\Backups` on BKP01) | Fast restore — sub-10-minute RTO for file-level recovery | Veeam B&R v13, agent-based, entire-computer image backup |
| **Copy 3** | AWS S3 with Object Lock | Ransomware-resistant off-site | Veeam Backup Copy Job, chunked object storage, encrypted in transit and at rest |

### Backup Implementation

**Veeam Backup & Replication v13 (Community Edition)**
- Agent-based backup selected over hypervisor-level integration — the same deployment pattern used for physical servers, AWS EC2 instances, and endpoints in production environments
- Protection groups organized by OS: Windows servers/clients and Linux servers with separate credential management
- Image-level (entire computer) backup mode for bare-metal recovery capability
- Daily backup schedule with 7-day retention (7 restore points)
- Forever-forward-incremental chain: one full backup followed by daily incrementals, minimizing storage consumption while maintaining full recovery capability

**Local Backup Repository**
- Dedicated 100GB virtual disk (`E:\Backups`) on BKP01 — separated from the OS volume to isolate backup data from system failures
- NTFS formatted with default allocation unit size
- Veeam deduplication and compression achieving approximately 1.6x reduction ratio (13.5 GB source → 8.6 GB stored)

*Veeam backup job completed successfully — 13.5 GB processed with 1.6x compression:*

<p align="center">
<img width="817" height="547" alt="image" src="https://github.com/user-attachments/assets/0caa3320-b50a-4204-b562-557a2e88bfec" />
</p>


**AWS S3 Immutable Cloud Tier**
- S3 bucket with Object Lock enabled at creation (cannot be disabled retroactively)
- Bucket versioning enabled (required for Object Lock)
- All public access blocked; bucket policy denies anonymous access
- Dedicated IAM user (`veeam-backup-user`) with a custom least-privilege policy scoped to the backup bucket only — initially deployed with `AmazonS3FullAccess` + `IAMFullAccess` for functionality validation, then tightened to bucket-scoped permissions with IAM actions restricted to the `vbrsvcacc-*` naming pattern used by Veeam's auto-provisioned service accounts
- 14-day Object Lock retention: backup objects cannot be modified or deleted within the retention window, even by administrators with full account access
- Veeam Backup Copy Job configured in Immediate Copy mode — new restore points replicate to S3 as soon as primary backup completes
- Backup file encryption enabled with a password-protected key stored separately from the backup infrastructure

_Veeam backup copy job completed successfully to S3 Bucket (AWS) - 13.5 GB processed:_
<p align="center">
<img width="703" height="412" alt="image" src="https://github.com/user-attachments/assets/e50d54f7-fe77-4fe8-9244-26d20b67638e" />
</p>

_S3 Bucket (AWS):_
<p align="center">
<img width="772" height="128" alt="image" src="https://github.com/user-attachments/assets/5b1e030a-49de-453c-9c5c-06150c2d2d64" />
</p>

_Verified data upload via CLI command:_

aws s3 ls s3://veeam-lab-backup-david-2026 --recursive --human-readable --summarize

<p align="center">
<img width="1050" height="196" alt="image" src="https://github.com/user-attachments/assets/0442381c-a76c-4369-a88b-5291124d1469" />
</p>

### Cost Analysis

| AWS Resource | Monthly Cost (estimated) |
|---|---|
| S3 Standard storage (~50 GB) | ~$1.15 |
| PUT/COPY requests | ~$0.02 |
| Data transfer IN | Free |
| Data transfer OUT (restores only) | ~$0.09/GB |
| **Total monthly cost** | **~$1.50–$3.00** |

> **Full Phase 2 documentation:** [docs/phase-2-backup/](docs/phase-2-backup/)

---

## Restore Drill Results

Backups that are never tested are not backups — they are assumptions. Three restore drills were performed and documented to validate end-to-end recovery capability.

_*Veeam inventory showing all Windows OS protected machines with agents deployed:*_
<p align="center">
<img width="1076" height="114" alt="image" src="https://github.com/user-attachments/assets/1d9890d6-0707-4a9e-b088-2fbf4c804fca" />
</p>

*Veeam inventory showing Linux/Ubuntu protected machine with agent deployed:*
<p align="center">
<img width="1077" height="87" alt="image" src="https://github.com/user-attachments/assets/bd15bc9d-7499-4fbe-8667-107c44338b43" />
</p>

### Drill 1: File-Level Restore

| Metric | Result |
|---|---|
| **Scenario** | Single file accidentally deleted from DC01 |
| **Source** | Local Veeam repository (Copy 2) |
| **Method** | Veeam Backup Browser → file-level restore to original location |
| **Recovery Time** | < 10 minutes |
| **Outcome** | File content verified intact; original data fully recovered |

### Drill 2: Bare-Metal Recovery

| Metric | Result |
|---|---|
| **Scenario** | SRV-LINUX01 total loss — restore to empty replacement hardware |
| **Source** | Local Veeam repository (Copy 2) |
| **Method** | Veeam Recovery Media ISO → bare-metal restore to new VM |
| **Recovery Time** | < 60 minutes |
| **Outcome** | Hostname, IP, OS, SSH service all verified post-restore; machine fully operational |

*Windows 11 - Restored verified operational after bare-metal restore:*
<p align="center">
<img width="1919" height="854" alt="image" src="https://github.com/user-attachments/assets/aa62e613-db68-44f5-8171-16369e79fdef" />
</p>


> **Detailed runbooks with step-by-step instructions:** [runbooks/](runbooks/)

---

## Lessons Learned & Incidents

### pfSense Disk Corruption Incident

During the project, the pfSense virtual disk suffered ZFS metadata corruption after an ungraceful VM shutdown, rendering the firewall unbootable (`ZFS: i/o error — all block copies unavailable`). Recovery assessment determined that rebuilding from scratch (20 minutes) was faster and more reliable than attempting ZFS pool repair.

**Takeaway:** Stateless infrastructure components (firewalls, load balancers) should be treated as disposable and rebuildable. Configuration backups (pfSense `config.xml` export) and VMware snapshots at milestones are cheap insurance.

**Post-incident actions:**
- Implemented VMware snapshot policy at every project milestone
- Exported pfSense configuration XML after rebuild
- Documented clean shutdown procedures for all VMs

### Windows Firewall Profile Mismatch

Domain-joined Windows machines intermittently classified their network connection as "Public" instead of "Domain," blocking ICMP and SMB traffic. Root cause: DNS resolution failures during boot prevented the domain authentication handshake that triggers the Domain profile.

**Takeaway:** DNS is the foundation of Active Directory. When AD-related features behave inconsistently, check DNS first.

**Resolution:** Deployed a Group Policy Object (`Lab-Firewall-Allow-ICMP`) that enables ICMP Echo Request across all firewall profiles (Domain, Private, and Public), ensuring consistent behavior regardless of profile classification.

### AWS IAM Permissions and Least-Privilege Progression

Veeam failed to browse S3 buckets during repository configuration, returning "check if the specified account has required permissions." After resolving that by adding s3:ListAllMyBuckets (which requires Resource: "*" because listing buckets is an account-wide operation, not bucket-scoped), a second error appeared during backup copy jobs: "not authorized to perform iam:CreateUser." Veeam auto-provisions dedicated IAM service accounts (prefixed vbrsvcacc-*) for agent-to-S3 communication, and the backup IAM user lacked permissions to create them.

**Takeaway:** Least-privilege in cloud environments is an iterative process, not a one-shot configuration. Starting with broad permissions to validate functionality, then tightening based on observed API calls and error messages, is standard practice in production cloud security. Understanding which API actions a tool actually performs and at what resource scope, is the core skill behind effective IAM policy authoring.

**Resolution:** Initially attached AmazonS3FullAccess and IAMFullAccess managed policies to unblock functionality and validate the end-to-end backup pipeline. Once the backup copy jobs were confirmed working, refined permissions to a custom IAM policy with three scoped statements: bucket listing on Resource: "*", full S3 operations restricted to the specific backup bucket ARN, and IAM user management restricted to the vbrsvcacc-* naming pattern.

---

*Last updated: April 2026*
