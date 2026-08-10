# GitHub to Local Backup

**Sauvegardez automatiquement des dépôts GitHub vers un disque local, USB, partage réseau ou NAS sous Windows.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Fonctionnalités

- une ou plusieurs sources GitHub (utilisateurs ou organisations)
- destination de sauvegarde configurable
- disques locaux, USB, lecteurs mappés et chemins UNC
- dépôts publics, privés ou tous
- sauvegardes complètes avec `git clone --mirror`
- mises à jour avec `git remote update --prune`
- vérification d’intégrité avec `git fsck --full`
- dépôts supprimés de GitHub déplacés vers `_archived` au lieu d’être supprimés
- rotation automatique des journaux
- tâche Windows hebdomadaire avec `StartWhenAvailable`
- sauvegarde optionnelle à l’ouverture de session
- icône de zone de notification avec protection contre les doublons
- paramètres modifiables après installation
- vérification de Git et GitHub CLI, installation optionnelle via `winget`

## Installation

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

```powershell
.\Install.ps1 `
  -Source "mon-compte","mon-organisation" `
  -Destination "D:\GitHubBackup" `
  -RunNow
```

## Destination indisponible

Si le NAS ou le partage réseau est indisponible, la sauvegarde est ignorée en toute sécurité. L’icône devient orange et la prochaine exécution planifiée réessaie.

## Paramètres

Via **Settings** dans le menu de l’icône ou dans :

```text
%LOCALAPPDATA%\GitHubToLocalBackup\config.json
```

## Désinstallation

```powershell
.\Uninstall.ps1
```

Les sauvegardes existantes ne sont pas supprimées.

## Licence

MIT — voir [LICENSE](LICENSE).
