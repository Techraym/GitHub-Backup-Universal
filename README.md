# GitHub to Local Backup

**Automatically back up GitHub repositories to a local disk, USB drive, network share or NAS on Windows.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Overview

GitHub to Local Backup is a lightweight PowerShell tool for Windows that creates complete Git mirror backups of repositories from a GitHub user or organization. The source account and destination are chosen during installation.

## Features

- GitHub user or organization as source
- User-defined destination
- Local disks, USB drives, mapped drives and UNC network paths
- Public and private repositories
- Complete `git clone --mirror` backups
- Existing mirrors updated automatically
- Weekly Windows Task Scheduler job
- Missed scheduled runs are retried when Windows can run the task again
- System tray status icon
- Single-instance protection against duplicate tray icons
- Temporarily unavailable destination is treated as a retryable state, not a corrupted backup
- Local and destination-side status/log files

## Status icon

- 🟢 **Green** — backup is recent and successful
- 🟠 **Orange** — running, overdue, not yet run, or destination unavailable
- 🔴 **Red** — actual backup error

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or newer
- Git
- GitHub CLI (`gh`)
- One-time GitHub CLI authentication:

```powershell
gh auth login
```

## Interactive installation

Open PowerShell in the downloaded/extracted project directory:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

The installer asks for:

- **Source** — GitHub user or organization, for example `Techraym`
- **Destination** — local folder or network location, for example:
  - `D:\Backups\GitHub`
  - `Y:\Backup Data\GitHub`
  - `\\NAS\Backups\GitHub`

## Installation with parameters

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

For a local backup:

```powershell
.\Install.ps1 `
    -Source "my-github-name" `
    -Destination "D:\GitHubBackup" `
    -RunNow
```

## Repository visibility

Back up only public repositories:

```powershell
.\Install.ps1 -Source "example" -Destination "D:\GitHub" -Visibility public
```

Supported values:

```text
all
public
private
```

## Backup structure

For source `Techraym`:

```text
<destination>\
├── _logs\
│   ├── github-backup.log
│   └── status.json
└── Techraym\
    ├── Repo1.git\
    ├── Repo2.git\
    └── Repo3.git\
```

## Why mirror backups?

`git clone --mirror` preserves Git references, branches, tags and repository history, not only the currently checked-out files.

## Destination temporarily unavailable

If a laptop is away from the home/company network or a NAS/network share is unavailable:

- the backup is skipped safely;
- the existing backup is not modified;
- the tray icon becomes orange;
- this is not treated as a damaged backup;
- the next scheduled run tries again.

## Manual backup

Right-click the tray icon and choose **Run backup now** / **Nu back-uppen**, or run the installed backup script manually.

## Configuration

Configuration is stored in:

```text
%LOCALAPPDATA%\GitHubNASBackup\config.json
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md) to report security issues.

## License

MIT — see [LICENSE](LICENSE).
