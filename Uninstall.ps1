# GitHub to Local Backup - uninstaller

[CmdletBinding()]
param(
    [string]$TaskName = "GitHub to Local Backup",
    [switch]$KeepConfig
)

$ErrorActionPreference = "SilentlyContinue"
$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "powershell.exe" -and
        $_.CommandLine -match "\\GitHubToLocalBackup\\Tray\.ps1"
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
    }

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Remove-ItemProperty -Path $RunKey -Name "GitHubToLocalBackupTray"

if ($KeepConfig) {
    Get-ChildItem $InstallDir -Force |
        Where-Object { $_.Name -ne "config.json" } |
        Remove-Item -Recurse -Force
}
else {
    Remove-Item $InstallDir -Recurse -Force
}

Write-Host "GitHub to Local Backup has been uninstalled." -ForegroundColor Green
Write-Host "Existing repository backups were not deleted."
