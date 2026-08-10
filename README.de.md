# GitHub to Local Backup

**Automatische lokale Backups von GitHub-Repositories auf Festplatte, USB, Netzwerkfreigabe oder NAS unter Windows.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Funktionen

- ein oder mehrere GitHub-Benutzer/Organisationen als Quelle
- frei wählbares Backup-Ziel
- lokale Laufwerke, USB, gemappte Laufwerke und UNC-Pfade
- öffentliche, private oder alle Repositories
- vollständige `git clone --mirror` Backups
- Updates mit `git remote update --prune`
- Integritätsprüfung mit `git fsck --full`
- entfernte GitHub-Repositories werden nach `_archived` verschoben statt gelöscht
- Log-Rotation
- wöchentliche Windows-Aufgabe mit `StartWhenAvailable`
- optionales Backup bei Windows-Anmeldung
- Tray-Status mit Single-Instance-Schutz
- Einstellungen nach der Installation änderbar
- Prüfung auf Git und GitHub CLI, optional Installation über `winget`

## Installation

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

```powershell
.\Install.ps1 `
  -Source "mein-account","meine-organisation" `
  -Destination "D:\GitHubBackup" `
  -RunNow
```

## Temporär nicht verfügbares Ziel

Ist NAS oder Netzwerkfreigabe nicht erreichbar, wird der Lauf sicher übersprungen. Das Tray-Symbol wird orange und der nächste geplante Lauf versucht es erneut.

## Einstellungen

Über **Settings** im Tray-Menü oder in:

```text
%LOCALAPPDATA%\GitHubToLocalBackup\config.json
```

## Deinstallation

```powershell
.\Uninstall.ps1
```

Vorhandene Backup-Daten werden nicht gelöscht.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
