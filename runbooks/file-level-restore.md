# Runbook: File-Level Restore from Veeam Backup

## Purpose

Use this procedure when one or more files need to be recovered from a Veeam backup — for example, after accidental deletion, corruption, or overwrite. This is the fastest restore method with the lowest RTO.

## Prerequisites

- Veeam Backup & Replication console access on BKP01
- At least one successful backup of the target machine exists
- Network connectivity between BKP01 and the target machine (if restoring to original location)

## Expected Recovery Time

- File-level restore: **under 10 minutes** (based on drill results)

## Procedure

### Step 1: Identify the Backup Source

1. Open the Veeam Backup & Replication console on BKP01
2. Navigate to **Home → Backups → Disk** (for local repository) or **Home → Backups → Object Storage** (for S3 cloud tier)
3. Locate the backup for the target machine
4. Note the available restore points (dates/times) — you need the most recent point that contains the file in its pre-incident state

### Step 2: Launch File-Level Restore

5. Right-click on the target machine's backup entry
6. Select **Restore guest files → Microsoft Windows** (for Windows machines) or **Restore guest files → Linux and other** (for Linux machines)
7. **Restore Point screen:** Select the appropriate restore point date/time
8. **Reason screen:** Enter a description
9. Click **Finish**

### Step 3: Browse and Restore

10. Wait for the Backup Browser window to open (30 seconds to several minutes depending on backup size)
11. Navigate to the file's original location within the Backup Browser
12. Right-click the target file(s) and choose one of:
    - **Restore → Overwrite** — restores to the original location, replacing current version
    - **Restore → Keep** — restores to the original location without overwriting existing files
    - **Copy To** — restores to a different location (safest option — verify before overwriting)

### Step 4: Verify Recovery

13. Navigate to the restored file location
14. Open the file and verify its contents match the expected pre-incident state
15. Check file metadata (size, modification date) for consistency

### Step 5: Clean Up

16. Close the Backup Browser window — Veeam automatically unmounts the backup
17. Document the restore in the incident log: date, file restored, restore point used, time taken

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Backup Browser won't open | Backup mount service not running | Restart Veeam Mount Service on BKP01 |
| File not found in backup | File was created after the restore point | Select an older restore point, or check if a more recent backup exists |
| "Access denied" during restore | Insufficient permissions on target path | Run Veeam console as Administrator; verify NTFS permissions on target folder |
| Restore is very slow | Large backup or network congestion | Normal for multi-GB backups; wait for completion |
