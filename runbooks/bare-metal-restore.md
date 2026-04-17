# Runbook: Bare-Metal Recovery to New Hardware

## Purpose

Use this procedure when a server has suffered total loss (hardware failure, unrecoverable disk corruption, catastrophic ransomware) and must be restored from backup onto new or replacement hardware. This procedure restores the entire machine — operating system, applications, configurations, and data — from a Veeam image-level backup.

## Prerequisites

- Veeam Backup & Replication console access on BKP01
- At least one successful **entire computer** (image-level) backup of the target machine exists
- Veeam Recovery Media ISO (created from Veeam console or Veeam Agent recovery media tool)
- Replacement hardware or a new VM with disk capacity equal to or greater than the original
- Network connectivity between the recovery target and BKP01

## Expected Recovery Time

- Full bare-metal restore: **under 60 minutes** (based on drill results; varies with data volume and disk speed)

## Procedure

### Step 1: Prepare Replacement Hardware

1. Provision a new VM (or physical server) with:
   - Same or greater CPU/RAM as the original
   - Disk capacity equal to or larger than the original
   - Network adapter on the same network segment (VMnet11/LAN for this lab)
   - **Do not install an operating system** — leave the disk empty
2. Mount the Veeam Recovery Media ISO to the CD/DVD drive

### Step 2: Boot into Veeam Recovery Environment

3. Boot the machine from the recovery ISO
4. The Veeam Recovery Wizard launches automatically
5. Select **Bare Metal Recovery** (or **Restore Volumes** depending on the Veeam version)

### Step 3: Connect to Backup Server

6. **Backup location:** Select **Network storage → Veeam Backup & Replication server**
7. Enter the backup server details:
   - Server: `192.168.10.30` (BKP01)
   - Credentials: Domain admin or local admin account on BKP01
8. Veeam connects and retrieves the list of available backups

### Step 4: Select Backup and Restore Point

9. Browse the available backups and select the target machine (e.g., SRV-LINUX01)
10. Select the most recent restore point (or a specific point-in-time if recovering from a known-good state before an incident)
11. Click **Next**

### Step 5: Disk Mapping

12. Veeam shows source disks (from the backup) and target disks (on the new hardware)
13. Map each source disk to the corresponding target disk
14. Verify disk sizes are compatible (target must be equal to or larger than source)
15. Click **Next** / **Restore**
16. Confirm the operation when prompted

### Step 6: Wait for Restore to Complete

17. Veeam writes the backup image to the target disk(s)
18. Monitor the progress bar — this typically takes 15-40 minutes depending on data volume
19. Do not interrupt the process

### Step 7: Post-Restore Boot

20. When restore completes, remove the recovery ISO from the CD/DVD drive
21. Reboot the machine
22. The restored OS should boot normally

### Step 8: Verify Recovery

23. Log in with the original credentials
24. Verify critical system attributes:

**For Windows servers:**
```powershell
hostname                     # Should match original
ipconfig /all                # Should show original IP and DNS
(Get-WmiObject Win32_ComputerSystem).Domain   # Should show lab.local
Get-Service | Where-Object {$_.Status -eq "Running"} | Measure-Object   # Service count should be reasonable
```

**For Linux servers:**
```bash
hostname                     # Should match original
ip a                         # Should show original IP
cat /etc/os-release          # Should show correct OS
sudo systemctl status ssh    # Critical services should be running
```

25. Test network connectivity:
```
ping 192.168.10.1            # pfSense gateway
ping 192.168.10.10           # Domain controller
ping 8.8.8.8                 # Internet access
```

### Step 9: Resolve Conflicts

26. **CRITICAL:** If the original machine is still running, shut it down immediately — two machines with the same IP and hostname will cause network conflicts
27. If this is a permanent replacement, decommission the original
28. If this was a drill, shut down the restored machine after verification

### Step 10: Document

29. Record in the incident log: date, machine restored, restore point used, total recovery time, verification results

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Recovery media won't boot | Boot order wrong | Check BIOS/VM settings — ensure CD/DVD is first boot device |
| Cannot connect to BKP01 | Network not configured in recovery environment | Manually configure IP in the recovery environment's network settings |
| "No backups found" | Wrong credentials or backup server unreachable | Verify IP and credentials; check BKP01 is running and Veeam services are up |
| Disk mapping fails | Target disk too small | Use a disk equal to or larger than the source |
| Restored machine won't boot | Driver incompatibility (rare with VMs, common with physical) | Boot into recovery mode and install drivers; or try a different VM hardware version |
| IP conflict after restore | Original machine still running | Shut down one of the two machines immediately |

## Notes

- Bare-metal restore from local repository (Copy 2) is faster than from S3 (Copy 3) due to bandwidth
- For restoring from S3, select the backup under Object Storage in the recovery wizard — the process is identical but slower
- Keep the Veeam Recovery Media ISO in a safe, accessible location — you need it before you can start the restore, so store it outside the environment being protected (host machine, USB drive, or cloud storage)
- After a successful bare-metal restore, run a new backup of the restored machine immediately to establish a fresh restore point
