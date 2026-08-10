# GitHub to Local Backup

**Maak automatisch lokale backups van GitHub-repositories naar een schijf, USB, netwerkshare of NAS op Windows.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Overzicht

GitHub to Local Backup is een lichte PowerShell-tool voor Windows die complete Git-mirrorbackups maakt van één of meerdere GitHub-gebruikers of organisaties.

## Functies

- één of meerdere GitHub-gebruikers/organisaties als bron
- vrij instelbaar backupdoel
- lokale schijf, USB, mapped drive en UNC-netwerkpad
- publieke, private of alle repositories
- volledige `git clone --mirror` backups
- automatische updates met `git remote update --prune`
- integriteitscontrole met `git fsck --full`
- verdwenen GitHub-repositories worden veilig naar `_archived` verplaatst en niet verwijderd
- automatische logrotatie
- wekelijkse Windows Taakplanner-taak met `StartWhenAvailable`
- optionele backup bij Windows-aanmelding
- tray-icoon met single-instance beveiliging
- eenmalige meldingen bij succes, fout of onbereikbaar doel
- instellingen achteraf wijzigen via **Settings** in het traymenu
- controle op Git en GitHub CLI, met optionele installatie via `winget`
- GitHub Actions controleert gewone én ingebedde PowerShell-scripts

## Statusicoon

- 🟢 groen — recente succesvolle backup
- 🟠 oranje — bezig, te oud, nog niet uitgevoerd of doel niet bereikbaar
- 🔴 rood — echte backupfout

## Installeren

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

Met parameters:

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

Meerdere bronnen:

```powershell
.\Install.ps1 `
    -Source "mijn-account","mijn-organisatie" `
    -Destination "D:\GitHubBackup" `
    -RunNow
```

Ontbrekende Git/GitHub CLI automatisch via winget installeren:

```powershell
.\Install.ps1 -Source "mijn-account" -Destination "D:\GitHubBackup" -InstallDependencies
```

## Schema

Standaard: zondag om 02:00.

```powershell
.\Install.ps1 `
    -Source "mijn-account" `
    -Destination "D:\GitHubBackup" `
    -DayOfWeek Friday `
    -Time "23:30" `
    -RunAtLogon
```

## Backupstructuur

```text
<doel>\
├── _logs\
├── _archived\
└── <bron>\
    ├── Repo1.git\
    └── Repo2.git\
```

## Doel tijdelijk niet beschikbaar

Als de NAS of netwerkshare niet bereikbaar is, wordt de backup veilig overgeslagen. Het tray-icoon wordt oranje en de volgende geplande uitvoering probeert opnieuw.

## Instellingen wijzigen

Rechtsklik op het tray-icoon en kies **Settings**. De configuratie staat in:

```text
%LOCALAPPDATA%\GitHubToLocalBackup\config.json
```

## Verwijderen

```powershell
.\Uninstall.ps1
```

Bestaande backupdata wordt niet verwijderd.

## Licentie

MIT — zie [LICENSE](LICENSE).
