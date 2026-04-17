# Ransomware Simulation Script — For Lab/Educational Use Only
# This script simulates ransomware behavior by overwriting file contents
# and renaming files with a .encrypted extension.
#
# WARNING: This script DESTROYS file contents. Only run in an isolated
# lab environment against test data that has been backed up.
#
# Usage: Run as Administrator on the target Windows machine
# Prerequisites: A successful Veeam backup must exist BEFORE running this script

param(
    [string]$TargetFolder = "C:\CompanyDocuments"
)

# Safety check
if (-not (Test-Path $TargetFolder)) {
    Write-Host "[ERROR] Target folder '$TargetFolder' does not exist." -ForegroundColor Red
    Write-Host "Create test files first, then run a backup, then run this script." -ForegroundColor Yellow
    exit 1
}

$files = Get-ChildItem -Path $TargetFolder -File | Where-Object { $_.Name -ne "README-DECRYPT.txt" }

if ($files.Count -eq 0) {
    Write-Host "[ERROR] No files found in '$TargetFolder'." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Red
Write-Host "  RANSOMWARE SIMULATION — LAB USE ONLY" -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""
Write-Host "Target folder : $TargetFolder" -ForegroundColor Yellow
Write-Host "Files affected: $($files.Count)" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will DESTROY the contents of all files in the target folder." -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Type 'ENCRYPT' to proceed (anything else cancels)"
if ($confirm -ne "ENCRYPT") {
    Write-Host "Cancelled. No files were modified." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "[*] Simulating ransomware attack..." -ForegroundColor Yellow

foreach ($file in $files) {
    # Overwrite file content with "encrypted" garbage
    [System.IO.File]::WriteAllText(
        $file.FullName,
        "YOUR FILES HAVE BEEN ENCRYPTED. Pay 5 BTC to unlock. File: $($file.Name)"
    )

    # Rename with .encrypted extension
    $newName = $file.Name + ".encrypted"
    Rename-Item -Path $file.FullName -NewName $newName
    Write-Host "    [!] Encrypted: $($file.Name) -> $newName" -ForegroundColor Red
}

# Drop a ransom note
$ransomNote = @"
========================================
  ALL YOUR FILES HAVE BEEN ENCRYPTED
========================================

Your important files have been encrypted with military-grade encryption.
To recover your files, you must pay 5 Bitcoin to the following wallet:

    1A2b3C4d5E6f7G8h9I0j (fake address — lab simulation only)

You have 72 hours before the decryption key is permanently deleted.

DO NOT:
- Attempt to decrypt files yourself
- Contact law enforcement
- Shut down this computer

========================================
  THIS IS A LAB SIMULATION
  No real encryption was performed.
  Recover using Veeam file-level restore.
========================================
"@

$ransomNote | Out-File "$TargetFolder\README-DECRYPT.txt" -Encoding UTF8
Write-Host "    [!] Ransom note dropped: README-DECRYPT.txt" -ForegroundColor Red

Write-Host ""
Write-Host "[*] Simulation complete. $($files.Count) files 'encrypted'." -ForegroundColor Yellow
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Green
Write-Host "  1. Take a screenshot of the encrypted folder (before recovery)" -ForegroundColor Green
Write-Host "  2. Start your timer" -ForegroundColor Green
Write-Host "  3. Open Veeam -> Home -> Backups -> right-click backup -> Restore guest files" -ForegroundColor Green
Write-Host "  4. Use Backup Browser to restore original files" -ForegroundColor Green
Write-Host "  5. Stop timer and document recovery time" -ForegroundColor Green
Write-Host "  6. Take a screenshot of the recovered folder (after recovery)" -ForegroundColor Green
