<#
.SYNOPSIS
  Fully removes FortiClient services, drivers, registry entries, files, and Windows Installer product traces.

.DESCRIPTION
  • Stops & deletes FortiClient services  
  • Removes FortiClient drivers  
  • Deletes FortiClient uninstall registry keys  
  • Deletes FortiClient installation folders  
  • Deletes FortiClient registry keys under HKLM and HKCU  
  • Cleans Windows Installer product entries referencing FortiClient  

.NOTES
  Must be run as Administrator.
  Tested on Windows 10/11.
  Author Filip Navratil (filip.navratil@gmail.com)
#>

# Common FortiClient service names
$services = @(
  'FA_Scheduler',
  'fortishield',
  'FortiESNAC',
  'FortiWF',
  'FortiSSLVPNService'
)

# Common FortiClient driver names (.sys without extension)
$drivers = @(
  'fctsvc',
  'ffsys',
  'fltsrv'
)

# FortiClient install folders
$folders = @(
  "$Env:ProgramFiles\Fortinet\FortiClient",
  "$Env:ProgramFiles(x86)\Fortinet\FortiClient"
)

# Uninstall key roots
$uninstallRoots = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

# Registry roots for FortiClient settings
$fortiRoots = @(
  'HKLM:\SOFTWARE\Fortinet',
  'HKCU:\Software\Fortinet'
)

# Function to stop and delete a Windows service
function Remove-ServiceIfExists {
    param([string]$name)
    if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
        Write-Host "Stopping service $name…" -ForegroundColor Cyan
        Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
        sc.exe config $name start= disabled | Out-Null
        sc.exe delete $name | Out-Null
        Write-Host "Deleted service $name." -ForegroundColor Green
    }
}

# Function to remove a kernel driver
function Remove-DriverIfExists {
    param([string]$name)
    $path = "$Env:SystemRoot\System32\drivers\$name.sys"
    if (Test-Path $path) {
        Write-Host "Removing driver $name…" -ForegroundColor Cyan
        sc.exe stop $name | Out-Null
        sc.exe delete $name | Out-Null
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
        Write-Host "Removed driver $name." -ForegroundColor Green
    }
}

# Function to delete Uninstall registry entries
function Remove-UninstallKeys {
    param([string]$root)
    Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
        $disp = (Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue).DisplayName
        if ($disp -and $disp -match 'FortiClient') {
            Write-Host "Deleting uninstall key $($_.PSPath)" -ForegroundColor Cyan
            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Deleted $($_.PSPath)." -ForegroundColor Green
        }
    }
}

# Function to delete FortiClient registry roots
function Remove-FortiRoots {
    param([string]$root)
    if (Test-Path $root) {
        Write-Host "Deleting registry key $root…" -ForegroundColor Cyan
        Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted registry key $root." -ForegroundColor Green
    }
}

# Function to delete Windows Installer product entries
function Remove-InstallerProducts {
    $productsRoot = 'HKLM:\SOFTWARE\Classes\Installer\Products'
    Get-ChildItem -Path $productsRoot -ErrorAction SilentlyContinue | ForEach-Object {
        $keyPath = $_.PSPath
        $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
        if ($props.ProductName -and $props.ProductName -match 'FortiClient') {
            Write-Host "Deleting Installer product entry $keyPath" -ForegroundColor Cyan
            Remove-Item -Path $keyPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Deleted Installer entry $keyPath." -ForegroundColor Green
        }
    }
}

# 1. Stop & delete services
foreach ($svc in $services) { Remove-ServiceIfExists -name $svc }

# 2. Remove drivers
foreach ($drv in $drivers) { Remove-DriverIfExists -name $drv }

# 3. Delete uninstall registry entries
foreach ($root in $uninstallRoots) { Remove-UninstallKeys -root $root }

# 4. Remove installation folders
foreach ($dir in $folders) {
    if (Test-Path $dir) {
        Write-Host "Removing folder $dir…" -ForegroundColor Cyan
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed folder $dir." -ForegroundColor Green
    }
}

# 5. Delete FortiClient registry roots
foreach ($root in $fortiRoots) { Remove-FortiRoots -root $root }

# 6. Delete Windows Installer product entries
Remove-InstallerProducts

Write-Host "FortiClient cleanup complete. Please reboot your computer." -ForegroundColor Yellow
