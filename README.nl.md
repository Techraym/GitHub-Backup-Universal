# GitHub to Local Backup

**Maak automatisch lokale backups van GitHub-repositories naar een lokale schijf, USB-schijf, netwerkshare of NAS op Windows.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Overzicht

GitHub to Local Backup is een eenvoudige PowerShell-tool voor Windows die volledige Git-mirrorbackups maakt van repositories van een GitHub-gebruiker of organisatie. De gebruiker kiest tijdens installatie zelf de bron en het doel.

## Functies

- GitHub-gebruiker of organisatie als bron
- Vrij instelbare doelmap
- Lokale schijf, USB-schijf, mapped drive of UNC-netwerkpad
- Publieke en private repositories
- Volledige `git clone --mirror` backups
- Bestaande mirrors automatisch bijwerken
- Wekelijkse taak via Windows Taakplanner
- Gemiste geplande runs worden later opnieuw geprobeerd
- Statusicoon in het systeemvak
- Single-instance beveiliging tegen dubbele tray-iconen
- Tijdelijk onbereikbaar doel wordt niet als beschadigde backup beschouwd
- Lokale en doelgebonden status- en logbestanden

## Statusicoon

- 🟢 **Groen** — backup recent en succesvol
- 🟠 **Oranje** — bezig, te oud, nog niet uitgevoerd of doel niet bereikbaar
- 🔴 **Rood** — echte backupfout

## Vereisten

- Windows 10 of Windows 11
- Windows PowerShell 5.1 of nieuwer
- Git
- GitHub CLI (`gh`)
- Eenmalig aanmelden via:

```powershell
gh auth login
```

## Interactief installeren

Open PowerShell in de uitgepakte projectmap:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

De installer vraagt om:

- **Bron** — GitHub-gebruiker of organisatie, bijvoorbeeld `Techraym`
- **Doel** — lokale map of netwerkpad, bijvoorbeeld:
  - `D:\Backups\GitHub`
  - `Y:\Backup Data\GitHub`
  - `\\NAS\Backups\GitHub`

## Installeren met parameters

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

Voor een lokale backup:

```powershell
.\Install.ps1 `
    -Source "mijn-github-naam" `
    -Destination "D:\GitHubBackup" `
    -RunNow
```

## Repository-zichtbaarheid

Alleen publieke repositories:

```powershell
.\Install.ps1 -Source "voorbeeld" -Destination "D:\GitHub" -Visibility public
```

Mogelijke waarden:

```text
all
public
private
```

## Backupstructuur

```text
<doel>\
├── _logs\
│   ├── github-backup.log
│   └── status.json
└── <GitHub-bron>\
    ├── Repo1.git\
    ├── Repo2.git\
    └── Repo3.git\
```

## Waarom mirror-backups?

`git clone --mirror` bewaart Git-references, branches, tags en repositorygeschiedenis, niet alleen de huidige bestanden.

## Doel tijdelijk niet bereikbaar

Als de laptop niet met het juiste netwerk verbonden is of een NAS/netwerkshare tijdelijk niet bereikbaar is:

- wordt de backup veilig overgeslagen;
- blijft de bestaande backup onaangetast;
- wordt het tray-icoon oranje;
- wordt dit niet als beschadigde backup behandeld;
- probeert de volgende geplande run het opnieuw.

## Configuratie

De instellingen staan in:

```text
%LOCALAPPDATA%\GitHubNASBackup\config.json
```

## Bijdragen

Zie [CONTRIBUTING.md](CONTRIBUTING.md).

## Beveiliging

Zie [SECURITY.md](SECURITY.md).

## Licentie

MIT — zie [LICENSE](LICENSE).
