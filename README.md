# GitHub NAS Backup

Een eenvoudige Windows-tool om GitHub-repositories automatisch lokaal, op een externe schijf of op een NAS te back-uppen.

## Wat de gebruiker zelf kiest

Tijdens de installatie worden deze waarden gevraagd:

- **Bron**: GitHub-gebruiker of organisatie, bijvoorbeeld `Techraym`
- **Doel**: elke lokale map, externe schijf of netwerkshare, bijvoorbeeld:
  - `D:\Backups\GitHub`
  - `Y:\Backup Data\GitHub`
  - `\\NAS\Backups\GitHub`

De instellingen worden opgeslagen in:

```text
%LOCALAPPDATA%\GitHubNASBackup\config.json
```

## Functies

- GitHub gebruiker of organisatie als bron
- vrij instelbare doelmap
- lokale schijf, USB-schijf, mapped drive of UNC-netwerkpad
- publieke en private repositories
- volledige `git clone --mirror` backup
- bestaande repositories automatisch bijwerken
- automatische wekelijkse Windows Taakplanner-run
- gemiste taak wordt later opnieuw geprobeerd
- systeemvak/tray-status
- single-instance beveiliging tegen dubbele tray-iconen
- doel niet bereikbaar = oranje status, geen echte backupfout
- log- en statusbestanden

## Statusicoon

- 🟢 **groen** — backup recent en succesvol
- 🟠 **oranje** — bezig, te oud, nog niet uitgevoerd of doel niet bereikbaar
- 🔴 **rood** — echte backupfout

## Vereisten

- Windows 10 of 11
- Windows PowerShell 5.1 of nieuwer
- Git
- GitHub CLI (`gh`)
- eenmalig aanmelden met:

```powershell
gh auth login
```

## Installeren — interactief

Open PowerShell in de uitgepakte map:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

De installer vraagt daarna zelf om bron en doel.

## Installeren — direct met parameters

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

Of lokaal:

```powershell
.\Install.ps1 `
    -Source "mijn-github-naam" `
    -Destination "D:\GitHubBackup" `
    -RunNow
```

## Alleen publieke repositories

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

Voor bron `Techraym`:

```text
<doel>\
├── _logs\
│   ├── github-backup.log
│   └── status.json
└── Techraym\
    ├── Repo1.git\
    ├── Repo2.git\
    └── Repo3.git\
```

## Waarom mirror-backups?

`git clone --mirror` bewaart niet alleen de huidige bestanden, maar ook Git-references, branches, tags en repositorygeschiedenis.

## Doel tijdelijk niet bereikbaar

Als een laptop onderweg is of de NAS/netwerkschijf niet bereikbaar is:

- de backup wordt overgeslagen;
- de bestaande backup wordt niet gewijzigd;
- het tray-icoon wordt oranje;
- dit wordt niet als corrupte/mislukte backup behandeld;
- de volgende geplande run probeert opnieuw.

## Handmatig starten

Rechtsklik op het tray-icoon en kies **Nu back-uppen**.

## Bijdragen

Zie [CONTRIBUTING.md](CONTRIBUTING.md).

## Beveiliging

Zie [SECURITY.md](SECURITY.md) voor het melden van beveiligingsproblemen.

## Licentie

MIT — zie [LICENSE](LICENSE).
