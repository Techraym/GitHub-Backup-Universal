# Changelog

All notable changes to this project are documented here. The project follows Semantic Versioning where practical.

## [1.0.0] - 2026-08-10

### Added
- Interactive GitHub source and backup destination configuration.
- GitHub user and organization support.
- Local disks, USB disks, mapped drives and UNC/network destinations.
- Full `git clone --mirror` backups.
- Existing mirror updates using `git remote update --prune`.
- Public, private or all-repository filtering.
- Configurable weekly Windows Task Scheduler run.
- Optional backup at Windows logon with `-RunAtLogon`.
- `StartWhenAvailable` for missed scheduled runs.
- Green/orange/red system-tray status.
- Single-instance tray protection to prevent duplicate icons.
- One notification per completed backup or unavailable destination event.
- An unavailable destination is treated as a temporary condition, not a damaged backup.
- Local and destination-side status/log files.
- `Uninstall.ps1` that removes the application without deleting repository backups.
- GitHub Actions PowerShell syntax validation.

### Fixed
- Native Git output on stderr is no longer incorrectly treated as a PowerShell terminating error.
- First-run status now supports an empty `LastSuccess` value.
- Tray startup is protected against multiple simultaneous instances.
