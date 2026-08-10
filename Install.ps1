# GitHub to Local Backup
# Universal Windows installer
# Version 1.1.0

[CmdletBinding()]
param(
    [string[]]$Source,
    [string]$Destination,
    [ValidateSet("all","public","private")]
    [string]$Visibility = "all",
    [ValidateSet("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")]
    [string]$DayOfWeek = "Sunday",
    [string]$Time = "02:00",
    [string]$TaskName = "GitHub to Local Backup",
    [switch]$RunAtLogon,
    [switch]$RunNow,
    [switch]$InstallDependencies,
    [switch]$SkipIntegrityCheck
)

$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$ConfigFile = Join-Path $InstallDir "config.json"

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $Machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $User = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$Machine;$User"
}

function Ensure-Dependency {
    param(
        [string]$Command,
        [string]$WingetId,
        [string]$DisplayName
    )

    if (Test-Command $Command) { return }

    $ShouldInstall = [bool]$InstallDependencies
    if (-not $ShouldInstall -and (Test-Command "winget.exe")) {
        $Answer = Read-Host "$DisplayName is missing. Install it with winget? (Y/N)"
        $ShouldInstall = $Answer -match '^(y|yes|j|ja)$'
    }

    if ($ShouldInstall) {
        if (-not (Test-Command "winget.exe")) {
            throw "$DisplayName is missing and winget is not available. Install it manually and run the installer again."
        }
        Write-Host "Installing $DisplayName..." -ForegroundColor Yellow
        & winget install --id $WingetId --exact --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "Could not install $DisplayName with winget." }
        Refresh-Path
    }

    if (-not (Test-Command $Command)) {
        throw "$DisplayName was not found. Install it and run the installer again."
    }
}

Write-Host ""
Write-Host "=== GitHub to Local Backup v1.1.0 ===" -ForegroundColor Cyan
Write-Host ""

if (-not $Source -or $Source.Count -eq 0) {
    $Entered = Read-Host "GitHub user or organization (multiple: comma separated)"
    $Source = @($Entered -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
else {
    $Source = @($Source | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
if ($Source.Count -eq 0) { throw "No GitHub source was specified." }

if (-not $Destination) {
    $Destination = Read-Host "Backup destination (for example D:\GitHubBackup or \\NAS\Backups\GitHub)"
}
if ([string]::IsNullOrWhiteSpace($Destination)) { throw "No backup destination was specified." }

$ParsedTime = [datetime]::MinValue
if (-not [datetime]::TryParseExact($Time, "HH:mm", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$ParsedTime)) {
    throw "Time must use HH:mm format, for example 02:00."
}

Ensure-Dependency -Command "git.exe" -WingetId "Git.Git" -DisplayName "Git for Windows"
Ensure-Dependency -Command "gh.exe" -WingetId "GitHub.cli" -DisplayName "GitHub CLI"

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
    Write-Host "GitHub CLI is not authenticated." -ForegroundColor Yellow
    Write-Host "Starting 'gh auth login'..." -ForegroundColor Yellow
    & gh auth login
    if ($LASTEXITCODE -ne 0) { throw "GitHub authentication was not completed." }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$Config = [ordered]@{
    Version             = "1.1.0"
    Sources             = @($Source)
    Destination         = $Destination.Trim()
    Visibility          = $Visibility
    TaskName            = $TaskName
    DayOfWeek           = $DayOfWeek
    Time                = $Time
    RunAtLogon          = [bool]$RunAtLogon
    IntegrityCheck      = -not [bool]$SkipIntegrityCheck
    ArchiveMissingRepos = $true
    MaxLogSizeMB        = 5
    MaxLogArchives      = 5
}
$Config | ConvertTo-Json -Depth 4 | Set-Content $ConfigFile -Encoding UTF8

$BackupScript = @'
$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$ConfigFile = Join-Path $InstallDir "config.json"
$StatusFile = Join-Path $InstallDir "status.json"
$LogFile = Join-Path $InstallDir "backup.log"

if (-not (Test-Path $ConfigFile)) { throw "Configuration file not found: $ConfigFile" }
$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$Sources = @($Config.Sources)
if ($Sources.Count -eq 0 -and $Config.Source) { $Sources = @([string]$Config.Source) }
$Destination = [string]$Config.Destination
$Visibility = [string]$Config.Visibility
$IntegrityCheck = [bool]$Config.IntegrityCheck
$ArchiveMissingRepos = [bool]$Config.ArchiveMissingRepos
$MaxLogSizeMB = if ($Config.MaxLogSizeMB) { [int]$Config.MaxLogSizeMB } else { 5 }
$MaxLogArchives = if ($Config.MaxLogArchives) { [int]$Config.MaxLogArchives } else { 5 }
$StartTime = Get-Date
$Failures = @()
$SuccessCount = 0
$RepoCount = 0
$ArchivedCount = 0

function Rotate-Log {
    if (-not (Test-Path $LogFile)) { return }
    if ((Get-Item $LogFile).Length -lt ($MaxLogSizeMB * 1MB)) { return }
    for ($i = $MaxLogArchives - 1; $i -ge 1; $i--) {
        $Old = "$LogFile.$i"
        $New = "$LogFile.$($i + 1)"
        if (Test-Path $Old) { Move-Item $Old $New -Force }
    }
    Move-Item $LogFile "$LogFile.1" -Force
}

function Write-Log {
    param([string]$Text)
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Text"
    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
    $TargetLogDir = Join-Path $Destination "_logs"
    if (Test-Path $TargetLogDir) {
        try { Add-Content -Path (Join-Path $TargetLogDir "github-backup.log") -Value $Line -Encoding UTF8 } catch {}
    }
}

function Read-PreviousStatus {
    if (Test-Path $StatusFile) {
        try { return Get-Content $StatusFile -Raw | ConvertFrom-Json } catch {}
    }
    return $null
}

function Write-Status {
    param([string]$Status,[string]$Message,[Nullable[datetime]]$LastSuccess,[int]$Repositories=0,[int]$FailuresCount=0,[int]$Archived=0)
    $Obj = [ordered]@{
        Status = $Status
        Message = $Message
        LastAttempt = (Get-Date).ToString("o")
        LastSuccess = if ($LastSuccess) { $LastSuccess.ToString("o") } else { $null }
        Repositories = $Repositories
        Failures = $FailuresCount
        Archived = $Archived
        Sources = @($Sources)
        Destination = $Destination
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
    }
    $Json = $Obj | ConvertTo-Json -Depth 5
    $Json | Set-Content $StatusFile -Encoding UTF8
    $TargetLogDir = Join-Path $Destination "_logs"
    if (Test-Path $TargetLogDir) {
        try { $Json | Set-Content (Join-Path $TargetLogDir "status.json") -Encoding UTF8 } catch {}
    }
}

function Invoke-Native {
    param([string]$Command,[string[]]$Arguments)
    $OldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $Output = & $Command @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $OldPreference }
    [pscustomobject]@{ Output=@($Output); ExitCode=$ExitCode }
}

function Invoke-Git {
    param([string[]]$Arguments)
    $Result = Invoke-Native -Command "git.exe" -Arguments $Arguments
    foreach ($Line in $Result.Output) { Write-Log "  $Line" }
    return $Result.ExitCode
}

function Test-DestinationAvailable {
    param([string]$Path)
    if ($Path -match '^[A-Za-z]:\\') {
        return Test-Path ([System.IO.Path]::GetPathRoot($Path))
    }
    if ($Path -match '^\\\\[^\\]+\\[^\\]+') {
        $Parts = $Path.TrimStart('\').Split('\')
        if ($Parts.Count -ge 2) { return Test-Path "\\$($Parts[0])\$($Parts[1])" }
    }
    $Parent = Split-Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($Parent)) { $Parent = $Path }
    return Test-Path $Parent
}

function Archive-MissingRepositories {
    param([string]$Source,[string]$RepoRoot,[object[]]$CurrentRepos)
    if (-not $ArchiveMissingRepos -or -not (Test-Path $RepoRoot)) { return 0 }
    $CurrentNames = @($CurrentRepos | ForEach-Object { ([string]$_.name).ToLowerInvariant() })
    $Archived = 0
    Get-ChildItem $RepoRoot -Directory -Filter "*.git" -ErrorAction SilentlyContinue | ForEach-Object {
        $Name = $_.Name.Substring(0, $_.Name.Length - 4)
        if ($CurrentNames -notcontains $Name.ToLowerInvariant()) {
            $ArchiveRoot = Join-Path $Destination "_archived\$Source"
            New-Item -ItemType Directory -Force -Path $ArchiveRoot | Out-Null
            $Target = Join-Path $ArchiveRoot ("{0}.git_{1}" -f $Name,(Get-Date -Format "yyyyMMdd_HHmmss"))
            Move-Item $_.FullName $Target -Force
            Write-Log "Archived missing repository: $Source/$Name"
            $Archived++
        }
    }
    return $Archived
}

Rotate-Log
$Previous = Read-PreviousStatus
$PreviousSuccess = $null
if ($Previous -and $Previous.LastSuccess) { try { $PreviousSuccess = [datetime]$Previous.LastSuccess } catch {} }
Write-Status -Status "running" -Message "GitHub backup is running." -LastSuccess $PreviousSuccess
Write-Log "============================================================"
Write-Log "Backup started -> $Destination"

if (-not (Test-DestinationAvailable $Destination)) {
    $Message = "Backup destination is not available. The next scheduled run will try again."
    Write-Log $Message
    Write-Status -Status "destination_unavailable" -Message $Message -LastSuccess $PreviousSuccess
    exit 0
}

try {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Destination "_logs") | Out-Null
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { throw "Git was not found." }
    if (-not (Get-Command gh.exe -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) was not found." }
    $Auth = Invoke-Native -Command "gh.exe" -Arguments @("auth","status")
    if ($Auth.ExitCode -ne 0) { throw "GitHub CLI is not authenticated. Run 'gh auth login'." }
    $null = Invoke-Native -Command "gh.exe" -Arguments @("auth","setup-git")

    foreach ($Source in $Sources) {
        $Source = [string]$Source
        $RepoRoot = Join-Path $Destination $Source
        New-Item -ItemType Directory -Force -Path $RepoRoot | Out-Null
        Write-Log "Source: $Source"

        $ListResult = Invoke-Native -Command "gh.exe" -Arguments @("repo","list",$Source,"--limit","1000","--json","name,url,visibility")
        if ($ListResult.ExitCode -ne 0) {
            $Failures += "$Source : repository list failed"
            Write-Log "ERROR $Source : could not list repositories"
            continue
        }

        $RepoJson = $ListResult.Output -join [Environment]::NewLine
        $Repos = @($RepoJson | ConvertFrom-Json)
        if ($Visibility -eq "public") { $Repos = @($Repos | Where-Object { $_.visibility -eq "PUBLIC" }) }
        elseif ($Visibility -eq "private") { $Repos = @($Repos | Where-Object { $_.visibility -eq "PRIVATE" }) }
        $RepoCount += $Repos.Count
        Write-Log "$($Repos.Count) repositories found for $Source"

        foreach ($Repo in $Repos) {
            $Name = [string]$Repo.name
            $Url = [string]$Repo.url
            $RepoDestination = Join-Path $RepoRoot "$Name.git"
            try {
                if (Test-Path $RepoDestination) {
                    Write-Log "Updating: $Source/$Name"
                    $Code = Invoke-Git @("--git-dir=$RepoDestination","remote","update","--prune")
                } else {
                    Write-Log "Cloning: $Source/$Name"
                    $Code = Invoke-Git @("clone","--mirror",$Url,$RepoDestination)
                }
                if ($Code -ne 0) { throw "Git returned exit code $Code" }
                if ($IntegrityCheck) {
                    Write-Log "Verifying: $Source/$Name"
                    $Fsck = Invoke-Git @("--git-dir=$RepoDestination","fsck","--full")
                    if ($Fsck -ne 0) { throw "Integrity check failed with exit code $Fsck" }
                }
                $SuccessCount++
            }
            catch {
                $Failures += "$Source/$Name : $($_.Exception.Message)"
                Write-Log "ERROR $Source/$Name : $($_.Exception.Message)"
            }
        }
        $ArchivedCount += Archive-MissingRepositories -Source $Source -RepoRoot $RepoRoot -CurrentRepos $Repos
    }

    if ($Failures.Count -gt 0) {
        $Message = "$SuccessCount of $RepoCount repositories updated; $($Failures.Count) error(s)."
        Write-Status -Status "failed" -Message $Message -LastSuccess $PreviousSuccess -Repositories $RepoCount -FailuresCount $Failures.Count -Archived $ArchivedCount
        Write-Log $Message
        exit 1
    }

    $Finished = Get-Date
    $Message = "$RepoCount repositories successfully updated. Backup is up-to-date."
    if ($ArchivedCount -gt 0) { $Message += " $ArchivedCount removed repository/repositories moved to _archived." }
    Write-Status -Status "success" -Message $Message -LastSuccess $Finished -Repositories $RepoCount -Archived $ArchivedCount
    Write-Log $Message
    Write-Log "Duration: $([math]::Round(($Finished - $StartTime).TotalSeconds)) seconds"
    exit 0
}
catch {
    $Message = $_.Exception.Message
    Write-Log "ERROR: $Message"
    Write-Status -Status "failed" -Message $Message -LastSuccess $PreviousSuccess -Repositories $RepoCount -FailuresCount 1 -Archived $ArchivedCount
    exit 1
}
'@

$TrayScript = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$CreatedNew = $false
$Mutex = New-Object System.Threading.Mutex($true, "Global\GitHubToLocalBackup-Tray", [ref]$CreatedNew)
if (-not $CreatedNew) { exit }
$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$ConfigFile = Join-Path $InstallDir "config.json"
$StatusFile = Join-Path $InstallDir "status.json"
$TrayStateFile = Join-Path $InstallDir "tray-state.json"
$BackupStarter = Join-Path $InstallDir "Start-Backup-Silent.vbs"
$LogFile = Join-Path $InstallDir "backup.log"
$ConfigEditor = Join-Path $InstallDir "Config.ps1"
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
    $G.Dispose(); $Brush.Dispose(); return $Icon
}
function Read-JsonFile([string]$Path) { if(Test-Path $Path){try{return Get-Content $Path -Raw|ConvertFrom-Json}catch{}};return $null }
function Show-NotificationOnce($Status,[string]$Title,[string]$Text,[System.Windows.Forms.ToolTipIcon]$Icon) {
    $Key = "$($Status.Status)|$($Status.LastAttempt)"
    $Previous = Read-JsonFile $TrayStateFile
    if ($Previous -and $Previous.Key -eq $Key) { return }
    $Tray.BalloonTipTitle=$Title;$Tray.BalloonTipText=$Text;$Tray.BalloonTipIcon=$Icon;$Tray.ShowBalloonTip(5000)
    [ordered]@{Key=$Key}|ConvertTo-Json|Set-Content $TrayStateFile -Encoding UTF8
}
$Green=New-CircleIcon([System.Drawing.Color]::LimeGreen);$Orange=New-CircleIcon([System.Drawing.Color]::Orange);$Red=New-CircleIcon([System.Drawing.Color]::Crimson)
$Tray=New-Object System.Windows.Forms.NotifyIcon;$Tray.Visible=$true;$Tray.Icon=$Orange;$Tray.Text="GitHub backup: status unknown"
$Menu=New-Object System.Windows.Forms.ContextMenuStrip
$StatusItem=$Menu.Items.Add("View status");$RunItem=$Menu.Items.Add("Back up now");$ConfigItem=$Menu.Items.Add("Settings");$DestinationItem=$Menu.Items.Add("Open destination");$LogItem=$Menu.Items.Add("Open log");$null=$Menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator));$ExitItem=$Menu.Items.Add("Exit");$Tray.ContextMenuStrip=$Menu
function Update-Tray {
    $Status=Read-JsonFile $StatusFile
    if(-not $Status){$Tray.Icon=$Orange;$Tray.Text="GitHub backup: not run yet";return}
    switch([string]$Status.Status){
        "running"{$Tray.Icon=$Orange;$Tray.Text="GitHub backup: running..."}
        "destination_unavailable"{$Tray.Icon=$Orange;$Tray.Text="GitHub backup: destination unavailable";Show-NotificationOnce $Status "GitHub to Local Backup" "Backup destination is not available. The next scheduled run will try again." ([System.Windows.Forms.ToolTipIcon]::Warning)}
        "failed"{$Tray.Icon=$Red;$Tray.Text="GitHub backup: error";Show-NotificationOnce $Status "GitHub backup failed" ([string]$Status.Message) ([System.Windows.Forms.ToolTipIcon]::Error)}
        "success"{$Last=[datetime]$Status.LastSuccess;if(((Get-Date)-$Last).TotalDays -gt 8){$Tray.Icon=$Orange;$Tray.Text="GitHub backup: outdated"}else{$Tray.Icon=$Green;$Tray.Text="GitHub backup OK $($Last.ToString('dd-MM HH:mm'))"};Show-NotificationOnce $Status "GitHub backup completed" ([string]$Status.Message) ([System.Windows.Forms.ToolTipIcon]::Info)}
    }
}
$StatusItem.Add_Click({$S=Read-JsonFile $StatusFile;if($S){[System.Windows.Forms.MessageBox]::Show("Sources: $($S.Sources -join ', ')`nDestination: $($S.Destination)`nStatus: $($S.Status)`nLast success: $($S.LastSuccess)`nRepositories: $($S.Repositories)`nErrors: $($S.Failures)`nArchived: $($S.Archived)`n`n$($S.Message)","GitHub to Local Backup")}})
$RunItem.Add_Click({Start-Process wscript.exe -ArgumentList "`"$BackupStarter`""})
$ConfigItem.Add_Click({Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ConfigEditor`""})
$DestinationItem.Add_Click({if(Test-Path $Destination){Start-Process explorer.exe $Destination}})
$LogItem.Add_Click({if(Test-Path $LogFile){Start-Process notepad.exe $LogFile}})
$ExitItem.Add_Click({$Tray.Visible=$false;[System.Windows.Forms.Application]::Exit()})
$Tray.Add_DoubleClick({$StatusItem.PerformClick()})
$Timer=New-Object System.Windows.Forms.Timer;$Timer.Interval=30000;$Timer.Add_Tick({Update-Tray});$Timer.Start();Update-Tray;[System.Windows.Forms.Application]::Run();$Tray.Visible=$false
'@

$ConfigScript = @'
$ErrorActionPreference = "Stop"
$InstallDir = Join-Path $env:LOCALAPPDATA "GitHubToLocalBackup"
$ConfigFile = Join-Path $InstallDir "config.json"
if (-not (Test-Path $ConfigFile)) { throw "Configuration not found." }
$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
Write-Host "GitHub to Local Backup - Settings" -ForegroundColor Cyan
Write-Host "Press Enter to keep the current value."; Write-Host ""
$SourcesNow = @($Config.Sources) -join ","
$Sources = Read-Host "Sources [$SourcesNow]"; if([string]::IsNullOrWhiteSpace($Sources)){$Sources=@($Config.Sources)}else{$Sources=@($Sources -split ','|ForEach-Object{$_.Trim()}|Where-Object{$_})}
$Destination = Read-Host "Destination [$($Config.Destination)]"; if([string]::IsNullOrWhiteSpace($Destination)){$Destination=[string]$Config.Destination}
$Visibility = Read-Host "Visibility all/public/private [$($Config.Visibility)]"; if([string]::IsNullOrWhiteSpace($Visibility)){$Visibility=[string]$Config.Visibility}; if($Visibility -notin @('all','public','private')){throw 'Invalid visibility.'}
$Day = Read-Host "Day [$($Config.DayOfWeek)]"; if([string]::IsNullOrWhiteSpace($Day)){$Day=[string]$Config.DayOfWeek}
$Time = Read-Host "Time HH:mm [$($Config.Time)]"; if([string]::IsNullOrWhiteSpace($Time)){$Time=[string]$Config.Time}
$Config.Sources=@($Sources);$Config.Destination=$Destination;$Config.Visibility=$Visibility;$Config.DayOfWeek=$Day;$Config.Time=$Time;$Config.Version='1.1.0'
$Config|ConvertTo-Json -Depth 5|Set-Content $ConfigFile -Encoding UTF8
$Parsed=[datetime]::ParseExact($Time,'HH:mm',[Globalization.CultureInfo]::InvariantCulture)
$Action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument "`"$InstallDir\Start-Backup-Silent.vbs`""
$Triggers=@(New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $Parsed)
if([bool]$Config.RunAtLogon){$Triggers += New-ScheduledTaskTrigger -AtLogOn}
$Settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName ([string]$Config.TaskName) -Action $Action -Trigger $Triggers -Settings $Settings -Description "Automatic GitHub mirror backup." -Force|Out-Null
Write-Host "Settings saved." -ForegroundColor Green
'@

Set-Content (Join-Path $InstallDir "Backup.ps1") $BackupScript -Encoding UTF8
Set-Content (Join-Path $InstallDir "Tray.ps1") $TrayScript -Encoding UTF8
Set-Content (Join-Path $InstallDir "Config.ps1") $ConfigScript -Encoding UTF8
$BackupVbs='Set s=CreateObject("WScript.Shell"): s.Run "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File """ & s.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\GitHubToLocalBackup\Backup.ps1""",0,False'
$TrayVbs='Set s=CreateObject("WScript.Shell"): s.Run "powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & s.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\GitHubToLocalBackup\Tray.ps1""",0,False'
Set-Content (Join-Path $InstallDir "Start-Backup-Silent.vbs") $BackupVbs -Encoding ASCII
Set-Content (Join-Path $InstallDir "Start-Tray.vbs") $TrayVbs -Encoding ASCII
$RunKey="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
New-ItemProperty -Path $RunKey -Name "GitHubToLocalBackupTray" -Value "wscript.exe `"$InstallDir\Start-Tray.vbs`"" -PropertyType String -Force|Out-Null
$Action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument "`"$InstallDir\Start-Backup-Silent.vbs`""
$Triggers=@(New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $ParsedTime)
if($RunAtLogon){$Triggers += New-ScheduledTaskTrigger -AtLogOn}
$Settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings -Description "Automatic GitHub mirror backup." -Force|Out-Null
Get-CimInstance Win32_Process|Where-Object{$_.Name -eq 'powershell.exe' -and $_.CommandLine -match '\\GitHubToLocalBackup\\Tray\.ps1'}|ForEach-Object{try{Stop-Process -Id $_.ProcessId -Force}catch{}}
Start-Sleep -Milliseconds 500
Start-Process wscript.exe -ArgumentList "`"$InstallDir\Start-Tray.vbs`""
Write-Host "";Write-Host "Installation completed." -ForegroundColor Green
Write-Host "Sources: $($Source -join ', ')";Write-Host "Destination: $Destination";Write-Host "Schedule: $DayOfWeek $Time";Write-Host "Settings: $InstallDir\Config.ps1";Write-Host ""
if($RunNow){& (Join-Path $InstallDir "Backup.ps1")}
