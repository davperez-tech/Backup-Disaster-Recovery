# Phase 2 — Backup, Cloud Replication & Disaster Recovery

## Overview

This phase implements a complete 3-2-1 backup architecture: three copies of data, on two different storage types, with one copy off-site and immutable. The architecture is validated through three documented restore drills covering file-level recovery, bare-metal server restoration, and ransomware simulation recovery.

## Backup Architecture

### 3-2-1 Implementation

```
Copy 1 (Production)          Copy 2 (Local)               Copy 3 (Off-site)
─────────────────            ──────────────               ─────────────────
Live VM disks         ──►    E:\Backups on BKP01   ──►    AWS S3 + Object Lock
                             (Veeam repository)           (14-day immutable)

Primary Backup Job           Stored as .vbk/.vib          Backup Copy Job
(Daily, 10 PM)               7 restore points             (Immediate copy)
                             ~1.6x compression            Chunked object storage
```

### Protected Machines

| Machine | Backup Type | Agent | Backup Mode |
|---|---|---|---|
| DC01 | Veeam Agent for Windows | Deployed via protection group | Entire computer (image) |
| BKP01 | Veeam Agent for Windows | Local install | Entire computer (image) |
| WIN11-CLIENT | Veeam Agent for Windows | Deployed via protection group | Entire computer (image) |
| SRV-LINUX01 | Veeam Agent for Linux | Deployed via SSH + sudo | Entire computer (image) |

## Veeam Backup & Replication Configuration

### Installation

- **Version:** Veeam Backup & Replication
- **Server:** BKP01 (192.168.10.30)
- **Database:** Bundled PostgreSQL
- **Service account:** Local System
- **Console access:** localhost on BKP01

### Local Backup Repository

- **Location:** `E:\Backups` on BKP01
- **Disk:** Dedicated 100 GB virtual disk (SCSI, thin-provisioned, GPT, NTFS)
- **Volume label:** BackupRepo
- **Drive letter:** E:
- **Design rationale:** Backup data is isolated on a separate disk from the OS to protect against single-disk failures and to allow independent capacity management

### Protection Groups

| Group Name | Type | Machines | Credential Type |
|---|---|---|---|
| Windows-Servers-and-Clients | Individual computers | DC01, WIN11-CLIENT | Domain admin (LAB\Administrator) |
| Linux-Servers | Individual computers | SRV-LINUX01 | Linux account (labadmin) with sudo elevation |

### Backup Jobs

| Job Name | Type | Schedule | Retention | Destination |
|---|---|---|---|---|
| Daily-Backup-Windows | Windows agent backup | Daily, 10:00 PM | 7 restore points | Local repository (E:\Backups) |
| Daily-Backup-Linux | Linux agent backup | Daily, 10:30 PM | 7 restore points | Local repository (E:\Backups) |

### Backup Performance Metrics

| Metric | Value |
|---|---|
| Source data processed | 13.5 GB (DC01 initial full backup) |
| Data transferred (after compression/dedup) | 8.6 GB |
| Compression ratio | ~1.6x |
| Backup throughput (to S3) | ~30 MB/s sustained |
| Initial full backup duration (to S3) | ~50 minutes |

## AWS S3 Cloud Tier Configuration

### S3 Bucket

| Setting | Value |
|---|---|
| Bucket name | veeam-lab-backup-david-2026 |
| Region | us-east-1 (N. Virginia) |
| Versioning | Enabled (required for Object Lock) |
| Object Lock | Enabled (Governance mode, 14-day retention) |
| Public access | Blocked (all four block public access settings enabled) |
| Encryption | SSE-S3 (AES-256, Amazon-managed keys) |

### IAM Configuration

**User:** `veeam-backup-user` (programmatic access only, no console login)

**Custom IAM Policy** (applied after initial deployment with AmazonS3FullAccess):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListAllBuckets",
            "Effect": "Allow",
            "Action": ["s3:ListAllMyBuckets", "s3:GetBucketLocation"],
            "Resource": "*"
        },
        {
            "Sid": "AllowBucketOperations",
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation", "s3:GetBucketObjectLockConfiguration",
                "s3:GetBucketVersioning", "s3:ListBucket", "s3:ListBucketVersions",
                "s3:GetObject", "s3:GetObjectVersion", "s3:GetObjectRetention",
                "s3:GetObjectLegalHold", "s3:PutObject", "s3:PutObjectRetention",
                "s3:PutObjectLegalHold", "s3:DeleteObject", "s3:DeleteObjectVersion",
                "s3:BypassGovernanceRetention"
            ],
            "Resource": [
                "arn:aws:s3:::veeam-lab-backup-david-2026",
                "arn:aws:s3:::veeam-lab-backup-david-2026/*"
            ]
        },
        {
            "Sid": "AllowVeeamServiceAccountManagement",
            "Effect": "Allow",
            "Action": [
                "iam:CreateUser", "iam:DeleteUser", "iam:GetUser",
                "iam:ListUsers", "iam:CreateAccessKey", "iam:DeleteAccessKey",
                "iam:ListAccessKeys", "iam:AttachUserPolicy", "iam:DetachUserPolicy",
                "iam:PutUserPolicy", "iam:DeleteUserPolicy", "iam:GetUserPolicy",
                "iam:ListAttachedUserPolicies", "iam:ListUserPolicies"
            ],
            "Resource": "arn:aws:iam::*:user/vbrsvcacc-*"
        }
    ]
}
```

**Security progression:** Started with broad managed policies (AmazonS3FullAccess + IAMFullAccess) to validate functionality, then refined to least-privilege custom policy scoped to the specific backup bucket and Veeam's service account naming pattern.

### Backup Copy Jobs

| Job Name | Source | Target | Mode | Retention |
|---|---|---|---|---|
| Backup-Copy-Windows-to-AWS | Daily-Backup-Windows | AWS-S3-Immutable repo | Immediate copy | 7 restore points |
| Backup-Copy-Linux-to-AWS | Daily-Backup-Linux | AWS-S3-Immutable repo | Immediate copy | 7 restore points |

### S3 Storage Characteristics

Veeam does not store traditional `.vbk` files in S3. Instead, backup data is broken into thousands of small chunks (typically 256 KB–1 MB each) and uploaded as individual S3 objects. This design enables:

- Block-level deduplication across workloads
- Efficient incremental uploads (only changed chunks are transmitted)
- Parallel upload/download operations
- Per-object immutability via Object Lock

**Verified S3 contents after first successful backup:**
- Total Objects: 23,360
- Total Size: ~14.8 GB
- Verified via `aws s3 ls --recursive --summarize`

### Cost Analysis

| Resource | Monthly Cost |
|---|---|
| S3 Standard storage (~50 GB) | ~$1.15 |
| PUT/COPY requests | ~$0.02 |
| Data transfer IN | Free |
| Data transfer OUT (restores) | ~$0.09/GB |
| **Monthly total** | **~$1.50–$3.00** |

Billing alarm configured at $10/month threshold.

## Restore Drill Results

See [Restore Drill Results](../../README.md#restore-drill-results) in the main README and detailed runbooks in [runbooks/](../../runbooks/).

## Troubleshooting 

### Common Issues Encountered and Resolved

| Issue | Root Cause | Resolution |
|---|---|---|
| "Failed to connect to backup server localhost" | Veeam services not fully started after boot | Wait 3-5 minutes after login; or manually start Veeam Backup Service and PostgreSQL |
| "Time discrepancy between gateway and server" (S3) | BKP01 clock drift | Force time sync: `w32tm /resync /force`; configure NTP on DC01 as authoritative source |
| "Check if specified account has required permissions" (S3) | IAM user missing s3:ListAllMyBuckets permission | Added AmazonS3FullAccess; later refined to custom policy including ListAllMyBuckets on Resource: * |
| "Not authorized to perform iam:CreateUser" | Veeam auto-provisions IAM service accounts for agents | Added IAMFullAccess; later refined to custom policy scoped to vbrsvcacc-* users |
| Win11 unreachable for agent deployment | Windows Firewall blocking SMB/RPC + LocalAccountTokenFilterPolicy | Enabled File and Printer Sharing, WMI, Remote Service Management across all profiles; set LocalAccountTokenFilterPolicy=1 for local accounts |
