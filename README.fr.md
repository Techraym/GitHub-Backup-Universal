# GitHub to Local Backup

**Sauvegardez automatiquement vos dépôts GitHub sous Windows vers un disque local, un disque USB, un partage réseau ou un NAS.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Présentation

GitHub to Local Backup est un outil PowerShell léger pour Windows qui crée des sauvegardes Git complètes en mode miroir pour les dépôts d’un utilisateur ou d’une organisation GitHub. La source et la destination sont choisies pendant l’installation.

## Fonctionnalités

- Utilisateur ou organisation GitHub comme source
- Destination librement configurable
- Disques locaux, disques USB, lecteurs réseau et chemins UNC
- Dépôts publics et privés
- Sauvegardes complètes avec `git clone --mirror`
- Mise à jour automatique des miroirs existants
- Tâche hebdomadaire via le Planificateur de tâches Windows
- Les exécutions manquées sont retentées ultérieurement
- Icône d’état dans la zone de notification
- Protection contre plusieurs instances de l’icône tray
- Une destination temporairement indisponible n’est pas considérée comme une sauvegarde corrompue
- Fichiers de statut et de journalisation

## Icône d’état

- 🟢 **Vert** — sauvegarde récente et réussie
- 🟠 **Orange** — en cours, trop ancienne, jamais exécutée ou destination indisponible
- 🔴 **Rouge** — erreur réelle de sauvegarde

## Prérequis

- Windows 10 ou Windows 11
- Windows PowerShell 5.1 ou version ultérieure
- Git
- GitHub CLI (`gh`)
- Authentification unique avec :

```powershell
gh auth login
```

## Installation interactive

Ouvrez PowerShell dans le dossier du projet extrait :

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

L’installateur demande :

- **Source** — utilisateur ou organisation GitHub, par exemple `Techraym`
- **Destination** — dossier local ou chemin réseau, par exemple `D:\Backups\GitHub` ou `\\NAS\Backups\GitHub`

## Installation avec paramètres

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

## Visibilité des dépôts

Pour sauvegarder uniquement les dépôts publics :

```powershell
.\Install.ps1 -Source "exemple" -Destination "D:\GitHub" -Visibility public
```

Valeurs possibles : `all`, `public`, `private`.

## Pourquoi des sauvegardes miroir ?

`git clone --mirror` conserve les références Git, les branches, les tags et l’historique du dépôt, et pas seulement les fichiers actuels.

## Destination temporairement indisponible

Si un NAS ou un partage réseau n’est pas accessible, l’exécution est ignorée sans modifier la sauvegarde existante. L’icône devient orange et la prochaine exécution planifiée réessaie automatiquement.

## Configuration

```text
%LOCALAPPDATA%\GitHubNASBackup\config.json
```

## Contribution

Voir [CONTRIBUTING.md](CONTRIBUTING.md).

## Sécurité

Voir [SECURITY.md](SECURITY.md).

## Licence

MIT — voir [LICENSE](LICENSE).
