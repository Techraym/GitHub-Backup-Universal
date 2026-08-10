# GitHub to Local Backup
# Universal Windows installer
# Version 1.0.0

[CmdletBinding()]
param(
    [string]$Source,
    [string]$Destination,
    [ValidateSet("all","public","private")]
    [string]$Visibility = "all",
    [ValidateSet("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")]
    [string]$DayOfWeek = "Sunday",
    [string]$Time = "02:00",
    [string]$TaskName = "GitHub to Local Backup",
    [switch]$RunAtLogon,
    [switch]$RunNow
)

$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$ConfigFile = Join-Path $InstallDir "config.json"

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host ""
Write-Host "=== GitHub to Local Backup ===" -ForegroundColor Cyan
Write-Host ""

if (-not $Source) {
    $Source = Read-Host "GitHub user or organization"
}
if ([string]::IsNullOrWhiteSpace($Source)) {
    throw "No GitHub source was specified."
}

if (-not $Destination) {
    $Destination = Read-Host "Backup destination (for example D:\GitHubBackup or \\NAS\Backups\GitHub)"
}
if ([string]::IsNullOrWhiteSpace($Destination)) {
    throw "No backup destination was specified."
}

$ParsedTime = [datetime]::MinValue
if (-not [datetime]::TryParseExact($Time, "HH:mm", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$ParsedTime)) {
    throw "Time must use HH:mm format, for example 02:00."
}

if (-not (Test-Command "git.exe")) {
    throw "Git was not found. Install Git for Windows and run the installer again."
}
if (-not (Test-Command "gh.exe")) {
    throw "GitHub CLI (gh) was not found. Install GitHub CLI and run the installer again."
}

$OldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & gh auth status *> $null
    $GhAuthExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $OldPreference
}
if ($GhAuthExitCode -ne 0) {
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$Config = [ordered]@{
    Version      = "1.0.0"
    Source       = $Source.Trim()
    Destination  = $Destination.Trim()
    Visibility   = $Visibility
    TaskName     = $TaskName
    DayOfWeek    = $DayOfWeek
    Time         = $Time
    RunAtLogon   = [bool]$RunAtLogon
}
$Config | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8

$BackupScript = @'
$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$ConfigFile = Join-Path $InstallDir "config.json"
$StatusFile = Join-Path $InstallDir "status.json"
$LogFile = Join-Path $InstallDir "backup.log"

if (-not (Test-Path $ConfigFile)) {
    throw "Configuration file not found: $ConfigFile"
}

$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$Source = [string]$Config.Source
$Destination = [string]$Config.Destination
$Visibility = [string]$Config.Visibility

$RepoRoot = Join-Path $Destination $Source
$NasLogDir = Join-Path $Destination "_logs"
$StartTime = Get-Date
$Failures = @()
$SuccessCount = 0
$RepoCount = 0

function Write-Log {
    param([string]$Text)
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Text"
    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
    if (Test-Path $NasLogDir) {
        try {
            Add-Content -Path (Join-Path $NasLogDir "github-backup.log") -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

function Read-PreviousStatus {
    if (Test-Path $StatusFile) {
        try {
            return Get-Content $StatusFile -Raw | ConvertFrom-Json
        }
        catch {}
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
    $Json | Set-Content $StatusFile -Encoding UTF8

    if (Test-Path $NasLogDir) {
        try {
            $Json | Set-Content (Join-Path $NasLogDir "status.json") -Encoding UTF8
        }
        catch {}
    }
}

function Invoke-Native {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    $OldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $Output = & $Command @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $OldPreference
    }

    return [pscustomobject]@{
        Output = @($Output)
        ExitCode = $ExitCode
    }
}

function Invoke-Git {
    param([string[]]$Arguments)

    $Result = Invoke-Native -Command "git.exe" -Arguments $Arguments
    foreach ($Line in $Result.Output) {
        Write-Log "  $Line"
    }
    return $Result.ExitCode
}

function Test-DestinationAvailable {
    param([string]$Path)

    if ($Path -match '^[A-Za-z]:\\') {
        $Root = [System.IO.Path]::GetPathRoot($Path)
        return (Test-Path $Root)
    }

    if ($Path -match '^\\\\[^\\]+\\[^\\]+') {
        $Parts = $Path.TrimStart('\').Split('\')
        if ($Parts.Count -ge 2) {
            $ShareRoot = "\\$($Parts[0])\$($Parts[1])"
            return (Test-Path $ShareRoot)
        }
    }

    $Parent = Split-Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($Parent)) {
        $Parent = $Path
    }
    return (Test-Path $Parent)
}

$Previous = Read-PreviousStatus
$PreviousSuccess = $null
if ($Previous -and $Previous.LastSuccess) {
    try {
        $PreviousSuccess = [datetime]$Previous.LastSuccess
    }
    catch {}
}

Write-Status -Status "running" -Message "GitHub backup is running." -LastSuccess $PreviousSuccess
Write-Log "============================================================"
Write-Log "Backup started: $Source -> $Destination"

if (-not (Test-DestinationAvailable $Destination)) {
    $Message = "Backup destination is not available. The next scheduled run will try again."
    Write-Log $Message
    Write-Status -Status "destination_unavailable" -Message $Message -LastSuccess $PreviousSuccess
    exit 0
}

try {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    New-Item -ItemType Directory -Force -Path $RepoRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $NasLogDir | Out-Null

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw "Git was not found."
    }
    if (-not (Get-Command gh.exe -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) was not found."
    }

    $Auth = Invoke-Native -Command "gh.exe" -Arguments @("auth","status")
    if ($Auth.ExitCode -ne 0) {
        throw "GitHub CLI is not authenticated. Run 'gh auth login'."
    }

    $null = Invoke-Native -Command "gh.exe" -Arguments @("auth","setup-git")

    $ListResult = Invoke-Native -Command "gh.exe" -Arguments @(
        "repo","list",$Source,
        "--limit","1000",
        "--json","name,url,visibility"
    )

    if ($ListResult.ExitCode -ne 0) {
        throw "Could not list repositories for '$Source': $($ListResult.Output -join ' ')"
    }

    $RepoJson = $ListResult.Output -join [Environment]::NewLine
    $Repos = @($RepoJson | ConvertFrom-Json)

    if ($Visibility -eq "public") {
        $Repos = @($Repos | Where-Object { $_.visibility -eq "PUBLIC" })
    }
    elseif ($Visibility -eq "private") {
        $Repos = @($Repos | Where-Object { $_.visibility -eq "PRIVATE" })
    }

    $RepoCount = $Repos.Count
    Write-Log "$RepoCount repositories found"

    foreach ($Repo in $Repos) {
        $Name = [string]$Repo.name
        $Url = [string]$Repo.url
        $RepoDestination = Join-Path $RepoRoot "$Name.git"

        try {
            if (Test-Path $RepoDestination) {
                Write-Log "Updating: $Name"
                $Code = Invoke-Git @(
                    "--git-dir=$RepoDestination",
                    "remote","update","--prune"
                )
            }
            else {
                Write-Log "Cloning: $Name"
                $Code = Invoke-Git @(
                    "clone","--mirror",$Url,$RepoDestination
                )
            }

            if ($Code -ne 0) {
                throw "Git returned exit code $Code"
            }

            $SuccessCount++
        }
        catch {
            $Failures += "$Name : $($_.Exception.Message)"
            Write-Log "ERROR $Name : $($_.Exception.Message)"
        }
    }

    if ($Failures.Count -gt 0) {
        $Message = "$SuccessCount of $RepoCount repositories updated; $($Failures.Count) error(s)."
        Write-Status -Status "failed" -Message $Message -LastSuccess $PreviousSuccess -Repositories $RepoCount -FailuresCount $Failures.Count
        Write-Log $Message
        exit 1
    }

    $Finished = Get-Date
    $Message = "$RepoCount repositories successfully updated. Backup is up-to-date."
    Write-Status -Status "success" -Message $Message -LastSuccess $Finished -Repositories $RepoCount
    Write-Log $Message
    Write-Log "Duration: $([math]::Round(($Finished - $StartTime).TotalSeconds)) seconds"
    exit 0
}
catch {
    $Message = $_.Exception.Message
    Write-Log "ERROR: $Message"
    Write-Status -Status "failed" -Message $Message -LastSuccess $PreviousSuccess -Repositories $RepoCount -FailuresCount 1
    exit 1
}
'@

$TrayScript = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$CreatedNew = $false
$Mutex = New-Object System.Threading.Mutex($true, "Global\GitHubToLocalBackup-Tray", [ref]$CreatedNew)
if (-not $CreatedNew) {
    exit
}

$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$ConfigFile = Join-Path $InstallDir "config.json"
$StatusFile = Join-Path $InstallDir "status.json"
$TrayStateFile = Join-Path $InstallDir "tray-state.json"
$BackupStarter = Join-Path $InstallDir "Start-Backup-Silent.vbs"
$LogFile = Join-Path $InstallDir "backup.log"

$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$Destination = [string]$Config.Destination

function New-CircleIcon {
    param([System.Drawing.Color]$Color)

    $Bmp = New-Object System.Drawing.Bitmap 32,32
    $Graphics = [System.Drawing.Graphics]::FromImage($Bmp)
    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $Graphics.Clear([System.Drawing.Color]::Transparent)
    $Brush = New-Object System.Drawing.SolidBrush $Color
    $Graphics.FillEllipse($Brush,4,4,24,24)

    $Icon = [System.Drawing.Icon]::FromHandle($Bmp.GetHicon())
    $Graphics.Dispose()
    $Brush.Dispose()
    return $Icon
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Save-TrayState {
    param(
        [string]$Key,
        [string]$Status
    )
    [ordered]@{
        Key = $Key
        Status = $Status
    } | ConvertTo-Json | Set-Content $TrayStateFile -Encoding UTF8
}

$Green = New-CircleIcon ([System.Drawing.Color]::LimeGreen)
$Orange = New-CircleIcon ([System.Drawing.Color]::Orange)
$Red = New-CircleIcon ([System.Drawing.Color]::Crimson)

$Tray = New-Object System.Windows.Forms.NotifyIcon
$Tray.Visible = $true
$Tray.Icon = $Orange
$Tray.Text = "GitHub backup: status unknown"

$Menu = New-Object System.Windows.Forms.ContextMenuStrip
$StatusItem = $Menu.Items.Add("View status")
$RunItem = $Menu.Items.Add("Back up now")
$DestinationItem = $Menu.Items.Add("Open destination")
$LogItem = $Menu.Items.Add("Open log")
$null = $Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$ExitItem = $Menu.Items.Add("Exit")
$Tray.ContextMenuStrip = $Menu

function Show-NotificationOnce {
    param(
        [object]$Status,
        [string]$Title,
        [string]$Text,
        [System.Windows.Forms.ToolTipIcon]$Icon
    )

    $Key = "$($Status.Status)|$($Status.LastAttempt)"
    $Previous = Read-JsonFile $TrayStateFile

    if ($Previous -and $Previous.Key -eq $Key) {
        return
    }

    $Tray.BalloonTipTitle = $Title
    $Tray.BalloonTipText = $Text
    $Tray.BalloonTipIcon = $Icon
    $Tray.ShowBalloonTip(5000)
    Save-TrayState -Key $Key -Status ([string]$Status.Status)
}

function Update-Tray {
    $Status = Read-JsonFile $StatusFile

    if (-not $Status) {
        $Tray.Icon = $Orange
        $Tray.Text = "GitHub backup: not run yet"
        return
    }

    switch ([string]$Status.Status) {
        "running" {
            $Tray.Icon = $Orange
            $Tray.Text = "GitHub backup: running..."
        }

        "destination_unavailable" {
            $Tray.Icon = $Orange
            $Tray.Text = "GitHub backup: destination unavailable"
            Show-NotificationOnce -Status $Status `
                -Title "GitHub to Local Backup" `
                -Text "Backup destination is not available. The next scheduled run will try again." `
                -Icon ([System.Windows.Forms.ToolTipIcon]::Warning)
        }

        "failed" {
            $Tray.Icon = $Red
            $Tray.Text = "GitHub backup: error"
            Show-NotificationOnce -Status $Status `
                -Title "GitHub backup failed" `
                -Text ([string]$Status.Message) `
                -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
        }

        "success" {
            $Last = [datetime]$Status.LastSuccess

            if (((Get-Date) - $Last).TotalDays -gt 8) {
                $Tray.Icon = $Orange
                $Tray.Text = "GitHub backup: outdated $($Last.ToString('dd-MM HH:mm'))"
            }
            else {
                $Tray.Icon = $Green
                $Tray.Text = "GitHub backup OK $($Last.ToString('dd-MM HH:mm'))"
            }

            Show-NotificationOnce -Status $Status `
                -Title "GitHub backup completed" `
                -Text "$($Status.Repositories) repositories updated. Backup is up-to-date." `
                -Icon ([System.Windows.Forms.ToolTipIcon]::Info)
        }
    }
}

$StatusItem.Add_Click({
    $Status = Read-JsonFile $StatusFile
    if (-not $Status) {
        [System.Windows.Forms.MessageBox]::Show(
            "No backup status is available yet.",
            "GitHub to Local Backup"
        )
        return
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Source: $($Status.Source)`nDestination: $($Status.Destination)`nStatus: $($Status.Status)`nLast success: $($Status.LastSuccess)`nRepositories: $($Status.Repositories)`nErrors: $($Status.Failures)`n`n$($Status.Message)",
        "GitHub to Local Backup"
    )
})

$RunItem.Add_Click({
    if (Test-Path $BackupStarter) {
        Start-Process wscript.exe -ArgumentList "`"$BackupStarter`""
    }
})

$DestinationItem.Add_Click({
    if (Test-Path $Destination) {
        Start-Process explorer.exe -ArgumentList "`"$Destination`""
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "The backup destination is currently unavailable.",
            "GitHub to Local Backup"
        )
    }
})

$LogItem.Add_Click({
    if (Test-Path $LogFile) {
        Start-Process notepad.exe -ArgumentList "`"$LogFile`""
    }
})

$ExitItem.Add_Click({
    $Tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})

$Tray.Add_DoubleClick({
    $StatusItem.PerformClick()
})

$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 30000
$Timer.Add_Tick({
    Update-Tray
})
$Timer.Start()

Update-Tray
[System.Windows.Forms.Application]::Run()

$Tray.Visible = $false
if ($Mutex) {
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}
'@

$BackupVbs = @'
Set s = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File """ & s.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\GitHubToLocalBackup\Backup.ps1"""
s.Run cmd, 0, False
'@

$TrayVbs = @'
Set s = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & s.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\GitHubToLocalBackup\Tray.ps1"""
s.Run cmd, 0, False
'@

Set-Content (Join-Path $InstallDir "Backup.ps1") $BackupScript -Encoding UTF8
Set-Content (Join-Path $InstallDir "Tray.ps1") $TrayScript -Encoding UTF8
Set-Content (Join-Path $InstallDir "Start-Backup-Silent.vbs") $BackupVbs -Encoding ASCII
Set-Content (Join-Path $InstallDir "Start-Tray.vbs") $TrayVbs -Encoding ASCII

$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
New-ItemProperty `
    -Path $RunKey `
    -Name "GitHubToLocalBackupTray" `
    -Value "wscript.exe `"$InstallDir\Start-Tray.vbs`"" `
    -PropertyType String `
    -Force | Out-Null

$Action = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\wscript.exe" `
    -Argument "`"$InstallDir\Start-Backup-Silent.vbs`""

$At = Get-Date -Hour $ParsedTime.Hour -Minute $ParsedTime.Minute -Second 0
$WeeklyTrigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek $DayOfWeek `
    -At $At

$Triggers = @($WeeklyTrigger)
if ($RunAtLogon) {
    $Triggers += New-ScheduledTaskTrigger -AtLogOn
}

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 12)

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Triggers `
    -Settings $Settings `
    -Description "Automatic mirror backup of GitHub repositories to local or network storage." `
    -Force | Out-Null

Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq "powershell.exe" -and
        $_.CommandLine -match "\\GitHubToLocalBackup\\Tray\.ps1"
    } |
    ForEach-Object {
        try { Stop-Process -Id $_.ProcessId -Force } catch {}
    }

Start-Sleep -Seconds 1
Start-Process wscript.exe -ArgumentList "`"$InstallDir\Start-Tray.vbs`""

Write-Host ""
Write-Host "Installation completed." -ForegroundColor Green
Write-Host "Source      : $Source"
Write-Host "Destination : $Destination"
Write-Host "Schedule    : $DayOfWeek at $Time"
Write-Host "Config      : $ConfigFile"
Write-Host ""

if ($RunNow) {
    & (Join-Path $InstallDir "Backup.ps1")
}
