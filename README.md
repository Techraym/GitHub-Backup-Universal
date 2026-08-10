# GitHub to Local Backup

**Automatically back up GitHub repositories to a local disk, USB drive, network share or NAS on Windows.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Overview

GitHub to Local Backup is a lightweight Windows PowerShell tool that creates complete Git mirror backups from one or more GitHub users or organizations. The destination can be a local disk, USB drive, mapped drive or UNC network path.

## Features

- One or multiple GitHub users/organizations as sources
- User-defined backup destination
- Local disks, USB drives, mapped drives and UNC network paths
- Public, private or all repositories
- Complete `git clone --mirror` backups
- Existing mirrors updated with `git remote update --prune`
- Optional repository integrity verification using `git fsck --full`
- Repositories that disappear from GitHub are moved safely to `_archived` instead of being deleted
- Automatic log rotation
- Weekly Windows Task Scheduler job with `StartWhenAvailable`
- Optional backup at Windows logon
- System tray status icon with single-instance protection
- One-time success/error/offline notifications
- Temporarily unavailable destination is a retryable state, not a backup failure
- Settings can be changed after installation from the tray menu
- Git and GitHub CLI dependency checks; optional installation through `winget`
- GitHub Actions validation for both normal and embedded PowerShell scripts

## Status icon

- 🟢 **Green** — backup is recent and successful
- 🟠 **Orange** — running, overdue, not yet run, or destination unavailable
- 🔴 **Red** — actual backup error

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or newer
- Git for Windows
- GitHub CLI (`gh`)

If Git or GitHub CLI is missing and `winget` is available, the installer can offer to install it.

## Interactive installation

Open PowerShell in the downloaded/extracted project directory:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

The installer asks for the GitHub source(s), destination and missing dependencies when needed.

## Installation with parameters

One source:

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

Multiple sources:

```powershell
.\Install.ps1 `
    -Source "my-user","my-organization" `
    -Destination "D:\GitHubBackup" `
    -RunNow
```

Automatically install missing Git/GitHub CLI dependencies with winget:

```powershell
.\Install.ps1 `
    -Source "my-user" `
    -Destination "D:\GitHubBackup" `
    -InstallDependencies
```

Disable the post-backup integrity check if desired:

```powershell
.\Install.ps1 `
    -Source "my-user" `
    -Destination "D:\GitHubBackup" `
    -SkipIntegrityCheck
```

## Repository visibility

```powershell
.\Install.ps1 -Source "example" -Destination "D:\GitHub" -Visibility public
```

Supported values: `all`, `public`, `private`.

## Scheduling

Default: every Sunday at 02:00.

```powershell
.\Install.ps1 `
    -Source "my-user" `
    -Destination "D:\GitHubBackup" `
    -DayOfWeek Friday `
    -Time "23:30" `
    -RunAtLogon
```

## Backup structure

```text
<destination>\
├── _logs\
│   ├── github-backup.log
│   └── status.json
├── _archived\
│   └── <source>\
└── <source>\
    ├── Repo1.git\
    ├── Repo2.git\
    └── Repo3.git\
```

## Why mirror backups?

`git clone --mirror` preserves Git references, branches, tags and repository history, not only the currently checked-out files.

## Destination temporarily unavailable

If a laptop is away from the home/company network or a NAS/network share is unavailable, the backup is skipped safely, the tray icon becomes orange and the next scheduled run tries again.

## Settings after installation

Right-click the tray icon and choose **Settings**. Configuration is stored in:

```text
%LOCALAPPDATA%\GitHubToLocalBackup\config.json
```

## Manual backup

Right-click the tray icon and choose **Back up now**.

## Uninstall

Run:

```powershell
.\Uninstall.ps1
```

The application files and scheduled task are removed. Existing backup data is not deleted.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).
