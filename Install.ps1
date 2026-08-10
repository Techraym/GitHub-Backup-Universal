# GitHub NAS Backup - Universal installer
# Interactieve Windows installer voor lokale/NAS GitHub backups.

param(
    [string]$Source,
    [string]$Destination,
    [string]$TaskName = "GitHub repositories backup",
    [ValidateSet("public","private","all")]
    [string]$Visibility = "all",
    [switch]$RunNow
)

$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubNASBackup"
$ConfigFile = Join-Path $InstallDir "config.json"

Write-Host ""
Write-Host "=== GitHub NAS Backup ===" -ForegroundColor Cyan
Write-Host ""

if (-not $Source) {
    $Source = Read-Host "GitHub gebruiker of organisatie (bijv. Techraym)"
}
if (-not $Source) { throw "Geen GitHub bron opgegeven." }

if (-not $Destination) {
    $Destination = Read-Host "Doelmap (bijv. D:\GitHubBackup of \\NAS\Backups\GitHub)"
}
if (-not $Destination) { throw "Geen doelmap opgegeven." }

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$config = [ordered]@{
    Source      = $Source
    Destination = $Destination
    Visibility  = $Visibility
    TaskName    = $TaskName
    Schedule    = "Weekly Sunday 02:00"
}
$config | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8

$BackupScript = @'
param()

$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubNASBackup"
$ConfigFile = Join-Path $InstallDir "config.json"
$LocalStatus = Join-Path $InstallDir "status.json"
$LocalLog = Join-Path $InstallDir "backup.log"

if (-not (Test-Path $ConfigFile)) {
    throw "Configuratie ontbreekt: $ConfigFile"
}

$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$Source = [string]$Config.Source
$Destination = [string]$Config.Destination
$Visibility = [string]$Config.Visibility

$RepoRoot = Join-Path $Destination $Source
$LogDir = Join-Path $Destination "_logs"
$StartTime = Get-Date
$Failures = @()
$SuccessCount = 0
$RepoCount = 0

function Write-Log {
    param([string]$Text)
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Text"
    Add-Content -Path $LocalLog -Value $Line -Encoding UTF8
    if (Test-Path $LogDir) {
        try { Add-Content -Path (Join-Path $LogDir "github-backup.log") -Value $Line -Encoding UTF8 } catch {}
    }
}

function Read-PreviousStatus {
    if (Test-Path $LocalStatus) {
        try { return Get-Content $LocalStatus -Raw | ConvertFrom-Json } catch {}
    }
    return $null
}

function Write-Status {
    param(
        [string]$Status,
        [string]$Message,
        [Nullable[datetime]]$LastSuccess,
        [int]$Repositories = 0,
        [int]$FailuresCount = 0
    )
    $Obj = [ordered]@{
        Status        = $Status
        Message       = $Message
        LastAttempt   = (Get-Date).ToString("o")
        LastSuccess   = if ($LastSuccess) { $LastSuccess.ToString("o") } else { $null }
        Repositories  = $Repositories
        Failures      = $FailuresCount
        Source        = $Source
        Destination   = $Destination
        Computer      = $env:COMPUTERNAME
        User          = $env:USERNAME
    }
    $Json = $Obj | ConvertTo-Json -Depth 4
    $Json | Set-Content $LocalStatus -Encoding UTF8
    if (Test-Path $LogDir) {
        try { $Json | Set-Content (Join-Path $LogDir "status.json") -Encoding UTF8 } catch {}
    }
}

function Invoke-GitCommand {
    param([string[]]$Arguments)
    $OldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $Output = & git @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
        foreach ($Line in $Output) { Write-Log "  $Line" }
        return $ExitCode
    }
    finally {
        $ErrorActionPreference = $OldPreference
    }
}

function Test-DestinationAvailable {
    param([string]$Path)

    if ($Path -match '^[A-Za-z]:\\') {
        $Root = [System.IO.Path]::GetPathRoot($Path)
        return Test-Path $Root
    }

    if ($Path -match '^\\\\[^\\]+\\[^\\]+') {
        $Parts = $Path.TrimStart('\').Split('\')
        if ($Parts.Count -ge 2) {
            $ShareRoot = "\\$($Parts[0])\$($Parts[1])"
            return Test-Path $ShareRoot
        }
    }

    $Parent = Split-Path $Path -Parent
    if (-not $Parent) { $Parent = $Path }
    return Test-Path $Parent
}

$Previous = Read-PreviousStatus
$PreviousSuccess = $null
if ($Previous -and $Previous.LastSuccess) {
    try { $PreviousSuccess = [datetime]$Previous.LastSuccess } catch {}
}

Write-Status -Status "running" -Message "GitHub backup wordt uitgevoerd." -LastSuccess $PreviousSuccess
Write-Log "============================================================"
Write-Log "GitHub backup gestart: $Source -> $Destination"

if (-not (Test-DestinationAvailable $Destination)) {
    $Message = "Doel niet beschikbaar. Backup wordt bij de volgende uitvoering opnieuw geprobeerd."
    Write-Log $Message
    Write-Status -Status "destination_unavailable" -Message $Message -LastSuccess $PreviousSuccess
    exit 0
}

try {
    New-Item -ItemType Directory -Force -Path $Destination, $RepoRoot, $LogDir | Out-Null

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw "Git is niet geïnstalleerd of staat niet in PATH."
    }
    if (-not (Get-Command gh.exe -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) is niet geïnstalleerd."
    }

    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI is niet aangemeld. Voer eerst 'gh auth login' uit."
    }

    & gh auth setup-git *> $null

    $Args = @("repo","list",$Source,"--limit","1000","--json","name,url,visibility")
    $RepoJson = & gh @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Repositories van '$Source' konden niet worden opgehaald: $RepoJson"
    }

    $Repos = @($RepoJson | ConvertFrom-Json)

    if ($Visibility -eq "public") {
        $Repos = @($Repos | Where-Object { $_.visibility -eq "PUBLIC" })
    }
    elseif ($Visibility -eq "private") {
        $Repos = @($Repos | Where-Object { $_.visibility -eq "PRIVATE" })
    }

    $RepoCount = $Repos.Count
    Write-Log "$RepoCount repositories gevonden"

    foreach ($Repo in $Repos) {
        $Name = [string]$Repo.name
        $Url = [string]$Repo.url
        $RepoDestination = Join-Path $RepoRoot "$Name.git"

        try {
            if (Test-Path $RepoDestination) {
                Write-Log "Bijwerken: $Name"
                $Code = Invoke-GitCommand @("--git-dir=$RepoDestination","remote","update","--prune")
            }
            else {
                Write-Log "Nieuwe repository: $Name"
                $Code = Invoke-GitCommand @("clone","--mirror",$Url,$RepoDestination)
            }

            if ($Code -ne 0) {
                throw "Git gaf exitcode $Code"
            }

            $SuccessCount++
        }
        catch {
            $Failures += "$Name : $($_.Exception.Message)"
            Write-Log "FOUT $Name : $($_.Exception.Message)"
        }
    }

    if ($Failures.Count -gt 0) {
        $Message = "$SuccessCount van $RepoCount repositories bijgewerkt; $($Failures.Count) fout(en)."
        Write-Status -Status "failed" -Message $Message -LastSuccess $PreviousSuccess -Repositories $RepoCount -FailuresCount $Failures.Count
        Write-Log $Message
        exit 1
    }

    $Finished = Get-Date
    $Message = "$RepoCount repositories succesvol bijgewerkt. Backup is up-to-date."
    Write-Status -Status "success" -Message $Message -LastSuccess $Finished -Repositories $RepoCount
    Write-Log $Message
    Write-Log "Duur: $([math]::Round(($Finished - $StartTime).TotalSeconds)) seconden"
    exit 0
}
catch {
    $Message = $_.Exception.Message
    Write-Log "FOUT: $Message"
    Write-Status -Status "failed" -Message $Message -LastSuccess $PreviousSuccess -Repositories $RepoCount -FailuresCount 1
    exit 1
}
'@

$TrayScript = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$CreatedNew = $false
$Mutex = New-Object System.Threading.Mutex($true, "Global\GitHubNASBackup-Tray", [ref]$CreatedNew)
if (-not $CreatedNew) { exit }

$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubNASBackup"
$ConfigFile = Join-Path $InstallDir "config.json"
$StatusFile = Join-Path $InstallDir "status.json"
$BackupStarter = Join-Path $InstallDir "Start-Backup-Silent.vbs"
$LogPath = Join-Path $InstallDir "backup.log"

$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$Destination = [string]$Config.Destination

function New-CircleIcon([System.Drawing.Color]$Color) {
    $Bmp = New-Object System.Drawing.Bitmap 32,32
    $G = [System.Drawing.Graphics]::FromImage($Bmp)
    $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $G.Clear([System.Drawing.Color]::Transparent)
    $Brush = New-Object System.Drawing.SolidBrush $Color
    $G.FillEllipse($Brush,4,4,24,24)
    $Icon = [System.Drawing.Icon]::FromHandle($Bmp.GetHicon())
    $G.Dispose(); $Brush.Dispose()
    return $Icon
}

$Green = New-CircleIcon ([System.Drawing.Color]::LimeGreen)
$Orange = New-CircleIcon ([System.Drawing.Color]::Orange)
$Red = New-CircleIcon ([System.Drawing.Color]::Crimson)

$Tray = New-Object System.Windows.Forms.NotifyIcon
$Tray.Visible = $true
$Tray.Icon = $Orange
$Tray.Text = "GitHub backup: status onbekend"

$Menu = New-Object System.Windows.Forms.ContextMenuStrip
$StatusItem = $Menu.Items.Add("Status bekijken")
$RunItem = $Menu.Items.Add("Nu back-uppen")
$DestinationItem = $Menu.Items.Add("Doelmap openen")
$LogItem = $Menu.Items.Add("Log bekijken")
$null = $Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$ExitItem = $Menu.Items.Add("Afsluiten")
$Tray.ContextMenuStrip = $Menu

function Get-Status {
    if (-not (Test-Path $StatusFile)) { return $null }
    try { Get-Content $StatusFile -Raw | ConvertFrom-Json } catch { return $null }
}

function Update-Tray {
    $S = Get-Status
    if (-not $S) {
        $Tray.Icon = $Orange
        $Tray.Text = "GitHub backup: nog niet uitgevoerd"
        return
    }

    switch ($S.Status) {
        "running" {
            $Tray.Icon=$Orange
            $Tray.Text="GitHub backup: bezig..."
        }
        "destination_unavailable" {
            $Tray.Icon=$Orange
            $Tray.Text="GitHub backup: doel niet beschikbaar"
        }
        "failed" {
            $Tray.Icon=$Red
            $Tray.Text="GitHub backup: fout"
        }
        "success" {
            $Last = [datetime]$S.LastSuccess
            if (((Get-Date)-$Last).TotalDays -gt 8) {
                $Tray.Icon=$Orange
                $Tray.Text="GitHub backup: verouderd $($Last.ToString('dd-MM HH:mm'))"
            }
            else {
                $Tray.Icon=$Green
                $Tray.Text="GitHub backup OK $($Last.ToString('dd-MM HH:mm'))"
            }
        }
    }
}

$StatusItem.Add_Click({
    $S = Get-Status
    if ($S) {
        [System.Windows.Forms.MessageBox]::Show(
            "Bron: $($S.Source)`nDoel: $($S.Destination)`nStatus: $($S.Status)`nLaatste succes: $($S.LastSuccess)`nRepositories: $($S.Repositories)`nFouten: $($S.Failures)`n`n$($S.Message)",
            "GitHub Backup"
        )
    }
})

$RunItem.Add_Click({ Start-Process wscript.exe -ArgumentList "`"$BackupStarter`"" })
$DestinationItem.Add_Click({ if (Test-Path $Destination) { Start-Process explorer.exe $Destination } })
$LogItem.Add_Click({ if (Test-Path $LogPath) { Start-Process notepad.exe $LogPath } })
$ExitItem.Add_Click({ $Tray.Visible=$false; [System.Windows.Forms.Application]::Exit() })
$Tray.Add_DoubleClick({ $StatusItem.PerformClick() })

$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 30000
$Timer.Add_Tick({ Update-Tray })
$Timer.Start()

Update-Tray
[System.Windows.Forms.Application]::Run()
$Tray.Visible = $false
'@

Set-Content (Join-Path $InstallDir "Backup.ps1") $BackupScript -Encoding UTF8
Set-Content (Join-Path $InstallDir "Tray.ps1") $TrayScript -Encoding UTF8

$BackupVbs = 'Set s=CreateObject("WScript.Shell"): s.Run "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File """ & s.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\GitHubNASBackup\Backup.ps1""",0,False'
$TrayVbs = 'Set s=CreateObject("WScript.Shell"): s.Run "powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & s.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\GitHubNASBackup\Tray.ps1""",0,False'

Set-Content (Join-Path $InstallDir "Start-Backup-Silent.vbs") $BackupVbs -Encoding ASCII
Set-Content (Join-Path $InstallDir "Start-Tray.vbs") $TrayVbs -Encoding ASCII

$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
New-ItemProperty -Path $RunKey -Name "GitHubNASBackupTray" -Value "wscript.exe `"$InstallDir\Start-Tray.vbs`"" -PropertyType String -Force | Out-Null

$Action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument "`"$InstallDir\Start-Backup-Silent.vbs`""
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2:00am
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 12)

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Automatische GitHub mirror-backup." -Force | Out-Null

Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "powershell.exe" -and $_.CommandLine -match "\\GitHubNASBackup\\Tray\.ps1"
} | ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force } catch {}
}

Start-Sleep -Seconds 1
Start-Process wscript.exe -ArgumentList "`"$InstallDir\Start-Tray.vbs`""

Write-Host ""
Write-Host "Installatie voltooid." -ForegroundColor Green
Write-Host "Bron : $Source"
Write-Host "Doel : $Destination"
Write-Host "Config: $ConfigFile"
Write-Host ""

if ($RunNow) {
    & (Join-Path $InstallDir "Backup.ps1")
}
