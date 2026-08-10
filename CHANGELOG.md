# Changelog

Alle noemenswaardige wijzigingen aan dit project worden in dit bestand bijgehouden.

Het project gebruikt Semantic Versioning waar dat praktisch toepasbaar is.

## [1.1.0] - 2026-08-10

### Added
- Meerdere GitHub-gebruikers en/of organisaties als bron in één installatie.
- Automatische controle op Git en GitHub CLI.
- Optionele installatie van ontbrekende dependencies via `winget`.
- Interactieve `gh auth login` wanneer de gebruiker nog niet is aangemeld.
- Repository-integriteitscontrole met `git fsck --full`.
- Veilige `_archived`-map voor repositories die niet langer op GitHub bestaan.
- Automatische logrotatie.
- Instellingen wijzigen vanuit het traymenu zonder herinstallatie.
- Configuratie voor loggrootte en aantal logarchieven.
- CI-validatie van de PowerShell-scripts die in de installer als here-string zijn ingebed.

### Changed
- Installatiemap en documentatie consequent op `%LOCALAPPDATA%\GitHubToLocalBackup` gezet.
- Statusinformatie bevat nu alle bronnen en het aantal gearchiveerde repositories.
- README-bestanden in Engels, Nederlands, Duits, Frans en Spaans bijgewerkt.
- Backup-engine behandelt elke bron afzonderlijk zodat een fout in één bron beter zichtbaar blijft.

### Safety
- Een onbereikbaar backupdoel blijft een herprobeerbare oranje status en geen permanente fout.
- Verdwenen repositories worden nooit automatisch verwijderd.
- Bestaande backupdata wordt door de uninstaller niet verwijderd.

## [1.0.0] - 2026-08-10

### Added
- Interactieve bron- en doelconfiguratie.
- Ondersteuning voor GitHub-gebruikers en organisaties.
- Ondersteuning voor lokale schijven, USB-schijven, mapped drives en UNC-netwerkpaden.
- Volledige `git clone --mirror` backups.
- Automatische update van bestaande mirrors met `git remote update --prune`.
- Filter voor publieke, private of alle repositories.
- Wekelijkse Windows Taakplanner-run met `StartWhenAvailable`.
- Tray-icoon met groen/oranje/rode status.
- Single-instance beveiliging tegen dubbele tray-iconen.
- Tijdelijk onbereikbaar doel wordt niet als echte backupfout behandeld.
- Lokale en doelgebonden status- en logbestanden.
