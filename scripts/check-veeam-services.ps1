# Veeam Services Health Check Script
# Run on BKP01 (Veeam Backup Server) as Administrator
# Checks status of all Veeam and dependency services, starts any that are stopped

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Veeam Services Health Check" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check PostgreSQL (Veeam's database backend)
Write-Host "[*] Checking database services..." -ForegroundColor Yellow
$pgServices = Get-Service | Where-Object { $_.Name -like "*postgresql*" }
foreach ($svc in $pgServices) {
    if ($svc.Status -eq "Running") {
        Write-Host "    [OK] $($svc.Name): $($svc.Status)" -ForegroundColor Green
    } else {
        Write-Host "    [!!] $($svc.Name): $($svc.Status) — attempting to start..." -ForegroundColor Red
        Start-Service $svc.Name -ErrorAction SilentlyContinue
        Start-Sleep 5
        $svc.Refresh()
        Write-Host "    [--] $($svc.Name): $($svc.Status)" -ForegroundColor Yellow
    }
}

# Check Veeam services
Write-Host ""
Write-Host "[*] Checking Veeam services..." -ForegroundColor Yellow
$veeamServices = Get-Service | Where-Object { $_.Name -like "*Veeam*" } | Sort-Object Name
foreach ($svc in $veeamServices) {
    if ($svc.Status -eq "Running") {
        Write-Host "    [OK] $($svc.DisplayName): $($svc.Status)" -ForegroundColor Green
    } else {
        Write-Host "    [!!] $($svc.DisplayName): $($svc.Status) — attempting to start..." -ForegroundColor Red
        Start-Service $svc.Name -ErrorAction SilentlyContinue
        Start-Sleep 3
        $svc.Refresh()
        if ($svc.Status -eq "Running") {
            Write-Host "    [OK] $($svc.DisplayName): Started successfully" -ForegroundColor Green
        } else {
            Write-Host "    [!!] $($svc.DisplayName): Failed to start — check Event Viewer" -ForegroundColor Red
        }
    }
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$allServices = @($pgServices) + @($veeamServices)
$running = ($allServices | Where-Object { $_.Status -eq "Running" }).Count
$total = $allServices.Count

if ($running -eq $total) {
    Write-Host "  All $total services running — Veeam console should be accessible." -ForegroundColor Green
} else {
    Write-Host "  $running of $total services running — check failed services above." -ForegroundColor Red
    Write-Host "  Tip: If PostgreSQL won't start, BKP01 may need more RAM (6GB+)." -ForegroundColor Yellow
}
Write-Host ""
