# Runbook: Ransomware Recovery from Immutable Backup

## Purpose

Use this procedure when a machine has been compromised by ransomware (or suspected ransomware) and files need to be recovered from a known-clean backup. This runbook covers file-level recovery for targeted encryption attacks. For full-disk encryption ransomware, use the [Bare-Metal Restore](bare-metal-restore.md) runbook instead.

## Prerequisites

- Veeam Backup & Replication console access on BKP01
- A successful backup exists that predates the ransomware infection
- The compromised machine is isolated or the ransomware process has been stopped
- Immutable backup in S3 (Copy 3) is available as a guaranteed-clean source if local backups (Copy 2) are suspected compromised

## Expected Recovery Time

- File-level ransomware recovery: **under 15 minutes** (based on drill results)
- Full machine recovery (if needed): **under 60 minutes**

## Procedure

### Step 1: Contain the Incident

**Before restoring anything, stop the bleeding.**

1. **Isolate the compromised machine** from the network — disconnect the network adapter in VMware (or unplug the cable on physical hardware). This prevents lateral movement to other machines.
2. **Do NOT shut down the machine yet** — forensic evidence in RAM may be valuable
3. **Verify backup integrity** — check that Veeam backup jobs on BKP01 are still running and that the backup server itself is not compromised
4. **Check the S3 immutable tier** — confirm backup objects in S3 still have Object Lock retention dates. If they do, this backup is guaranteed untampered regardless of what happened on-premises.

### Step 2: Identify the Infection Timeline

5. Determine when the ransomware executed:
   - Check file modification timestamps on encrypted files
   - Review Windows Event Logs or Linux auth logs for suspicious activity
   - Check Veeam backup job logs — did recent backups succeed or fail?
6. **Select a restore point that predates the infection** — this is critical. Restoring from a backup that was taken after infection means restoring encrypted/compromised data.

### Step 3: Choose Recovery Source

7. Decide which backup tier to restore from:

| Source | When to Use |
|---|---|
| **Local repository (Copy 2)** | When you're confident the backup server was not compromised; faster restore |
| **S3 immutable tier (Copy 3)** | When local backups may be compromised, or when you need guaranteed-clean data; slower but trustworthy |

**When in doubt, use the S3 immutable tier.** Its Object Lock retention guarantees the data has not been modified since it was written.

### Step 4: Perform File-Level Restore

8. Open the Veeam console on BKP01
9. Navigate to:
   - **Home → Backups → Disk** (for local repository), or
   - **Home → Backups → Object Storage** (for S3 immutable tier)
10. Right-click the compromised machine's backup → **Restore guest files → Microsoft Windows** (or Linux)
11. Select the pre-infection restore point
12. Click through to mount the backup

### Step 5: Restore Clean Files

13. In the Backup Browser, navigate to the affected directories
14. **Verify the files are clean** — open a few files from the Backup Browser to confirm they contain real data, not encrypted content
15. Select the files/folders to restore
16. Choose **Copy To** and restore to a staging location (e.g., `C:\RecoveredFiles\`) rather than directly overwriting — this lets you verify before replacing
17. After verification, copy the clean files to their original locations, replacing the encrypted versions

### Step 6: Clean Up the Compromised Machine

18. Delete all `.encrypted` files (or whatever extension the ransomware used)
19. Delete any ransom notes (`README-DECRYPT.txt`, `HOW_TO_DECRYPT.html`, etc.)
20. Run a full antivirus/antimalware scan to ensure the ransomware payload itself is removed
21. Check startup programs, scheduled tasks, and services for persistence mechanisms

### Step 7: Verify Recovery

22. Confirm all affected files have been restored with correct content
23. Check that no encrypted files remain
24. Verify the machine functions normally — applications launch, services run, users can log in

### Step 8: Post-Incident Actions

25. **Reconnect the machine to the network** only after cleanup and verification are complete
26. **Run an immediate backup** of the recovered machine to establish a new clean restore point
27. **Investigate root cause:**
    - How did the ransomware get in? (phishing, exposed RDP, vulnerable software)
    - Were other machines affected?
    - Was the backup infrastructure targeted?
28. **Document the incident:** timeline, affected systems, recovery actions, time to recover, root cause, and remediation steps
29. **Review backup architecture:** Did the 3-2-1 strategy work as designed? Were immutable backups actually immutable? What would you change?

## Decision Tree: File-Level vs Full Machine Recovery

```
Was the ransomware limited to encrypting user files?
├── YES → Use this runbook (file-level restore)
└── NO → Was the OS or boot sector affected?
    ├── YES → Use Bare-Metal Restore runbook
    └── UNKNOWN → Restore to a new/clean VM using Bare-Metal
                   Restore, then investigate the original machine
                   offline for forensics
```

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| All restore points appear to contain encrypted files | Ransomware was active for days before detection; backups captured encrypted state | Look for older restore points that predate the infection; check S3 tier for older immutable copies |
| S3 restore is very slow | Cloud download bandwidth limitations | Expected behavior; S3 restores take longer than local. For urgent recovery of many files, consider bare-metal restore from S3 instead |
| Backup server (BKP01) also compromised | Attacker targeted backup infrastructure | Restore from S3 immutable tier — this is exactly the scenario Object Lock protects against. Rebuild BKP01 from scratch, then restore data from S3 |
| Cannot determine infection timeline | No logs or monitoring in place | Restore from the oldest available clean backup; accept potential data loss for the gap period. Post-incident: implement centralized logging and SIEM |

## Key Lessons from Drill Execution

- **Immutable backups are non-negotiable.** If ransomware actors compromise the backup server and delete local backups, the S3 Object Lock tier is the last line of defense. Without it, recovery may be impossible.
- **Backup frequency determines maximum data loss.** With daily backups, the worst-case data loss (RPO) is 24 hours. For critical data, consider more frequent backup schedules.
- **Speed of detection matters.** The faster you detect ransomware, the more recent your clean restore point is, and the less data you lose. This is why monitoring and alerting (Phase 5) complement the backup architecture.
- **Restore drills build confidence.** When a real incident occurs, the team has already practiced the recovery procedure and knows what to expect. Panic is replaced by process.
