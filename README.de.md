# GitHub to Local Backup

**GitHub-Repositories unter Windows automatisch auf eine lokale Festplatte, USB-Festplatte, Netzwerkfreigabe oder NAS sichern.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Übersicht

GitHub to Local Backup ist ein leichtgewichtiges PowerShell-Tool für Windows, das vollständige Git-Mirror-Backups der Repositories eines GitHub-Benutzers oder einer Organisation erstellt. Quelle und Ziel werden bei der Installation frei gewählt.

## Funktionen

- GitHub-Benutzer oder Organisation als Quelle
- Frei wählbarer Zielordner
- Lokale Laufwerke, USB-Laufwerke, eingebundene Laufwerke und UNC-Netzwerkpfade
- Öffentliche und private Repositories
- Vollständige `git clone --mirror` Backups
- Automatische Aktualisierung bestehender Mirrors
- Wöchentliche Ausführung über die Windows-Aufgabenplanung
- Verpasste Ausführungen werden später erneut versucht
- Statussymbol im Infobereich
- Single-Instance-Schutz gegen doppelte Tray-Symbole
- Vorübergehend nicht verfügbares Ziel gilt nicht als beschädigtes Backup
- Status- und Logdateien lokal und am Backupziel

## Statussymbol

- 🟢 **Grün** — Backup aktuell und erfolgreich
- 🟠 **Orange** — läuft, veraltet, noch nicht ausgeführt oder Ziel nicht verfügbar
- 🔴 **Rot** — echter Backupfehler

## Voraussetzungen

- Windows 10 oder Windows 11
- Windows PowerShell 5.1 oder neuer
- Git
- GitHub CLI (`gh`)
- Einmalige Anmeldung mit:

```powershell
gh auth login
```

## Interaktive Installation

PowerShell im entpackten Projektordner öffnen:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

Der Installer fragt nach:

- **Quelle** — GitHub-Benutzer oder Organisation, z. B. `Techraym`
- **Ziel** — lokaler Ordner oder Netzwerkpfad, z. B. `D:\Backups\GitHub` oder `\\NAS\Backups\GitHub`

## Installation mit Parametern

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

## Sichtbarkeit

Nur öffentliche Repositories sichern:

```powershell
.\Install.ps1 -Source "beispiel" -Destination "D:\GitHub" -Visibility public
```

Mögliche Werte: `all`, `public`, `private`.

## Warum Mirror-Backups?

`git clone --mirror` bewahrt Git-Referenzen, Branches, Tags und die Repository-Historie, nicht nur die aktuell ausgecheckten Dateien.

## Ziel vorübergehend nicht verfügbar

Ist ein NAS oder eine Netzwerkfreigabe vorübergehend nicht erreichbar, wird der Lauf sicher übersprungen. Das vorhandene Backup bleibt unverändert, das Tray-Symbol wird orange und der nächste geplante Lauf versucht es erneut.

## Konfiguration

```text
%LOCALAPPDATA%\GitHubNASBackup\config.json
```

## Mitwirken

Siehe [CONTRIBUTING.md](CONTRIBUTING.md).

## Sicherheit

Siehe [SECURITY.md](SECURITY.md).

## Lizenz

MIT — siehe [LICENSE](LICENSE).
