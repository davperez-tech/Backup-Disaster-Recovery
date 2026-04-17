# Enable ICMP Echo Request (Ping) Across All Firewall Profiles
# Run as Administrator on any Windows machine in the lab
# Alternatively, deploy via Group Policy for centralized management

# Check if the rule already exists
$existingRule = Get-NetFirewallRule -DisplayName "Allow ICMPv4-In (Lab)" -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "[OK] ICMP allow rule already exists." -ForegroundColor Green
} else {
    New-NetFirewallRule `
        -DisplayName "Allow ICMPv4-In (Lab)" `
        -Protocol ICMPv4 `
        -IcmpType 8 `
        -Direction Inbound `
        -Action Allow `
        -Profile Domain,Private,Public `
        -Description "Allow inbound ICMP Echo Request (ping) on all profiles — lab environment"

    Write-Host "[OK] ICMP allow rule created for all profiles." -ForegroundColor Green
}

# Also enable File and Printer Sharing (required for Veeam agent deployment)
Write-Host "[*] Enabling File and Printer Sharing rules..." -ForegroundColor Yellow
Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True -Profile Domain,Private,Public -ErrorAction SilentlyContinue
Write-Host "[OK] File and Printer Sharing enabled." -ForegroundColor Green

# Enable WMI (required for remote management tools)
Write-Host "[*] Enabling WMI rules..." -ForegroundColor Yellow
Set-NetFirewallRule -DisplayGroup "Windows Management Instrumentation (WMI)" -Enabled True -Profile Domain,Private,Public -ErrorAction SilentlyContinue
Write-Host "[OK] WMI enabled." -ForegroundColor Green

# Enable Remote Service Management (required for Veeam agent install)
Write-Host "[*] Enabling Remote Service Management rules..." -ForegroundColor Yellow
Set-NetFirewallRule -DisplayGroup "Remote Service Management" -Enabled True -Profile Domain,Private,Public -ErrorAction SilentlyContinue
Write-Host "[OK] Remote Service Management enabled." -ForegroundColor Green

Write-Host ""
Write-Host "All firewall rules configured. This machine should now be reachable" -ForegroundColor Cyan
Write-Host "for ping, file sharing, WMI, and Veeam agent deployment." -ForegroundColor Cyan
