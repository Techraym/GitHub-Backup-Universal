# GitHub to Local Backup

**Copia automáticamente repositorios de GitHub a un disco local, USB, recurso de red o NAS en Windows.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Funciones

- uno o varios usuarios u organizaciones de GitHub como origen
- destino de copia configurable
- discos locales, USB, unidades mapeadas y rutas UNC
- repositorios públicos, privados o todos
- copias completas con `git clone --mirror`
- actualizaciones con `git remote update --prune`
- comprobación de integridad con `git fsck --full`
- repositorios eliminados de GitHub se mueven a `_archived` en lugar de borrarse
- rotación automática de registros
- tarea semanal de Windows con `StartWhenAvailable`
- copia opcional al iniciar sesión
- icono de bandeja con protección de instancia única
- configuración modificable después de instalar
- comprobación de Git y GitHub CLI, con instalación opcional mediante `winget`

## Instalación

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

```powershell
.\Install.ps1 `
  -Source "mi-cuenta","mi-organizacion" `
  -Destination "D:\GitHubBackup" `
  -RunNow
```

## Destino no disponible

Si el NAS o recurso de red no está disponible, la copia se omite de forma segura. El icono se vuelve naranja y la siguiente ejecución programada lo intenta de nuevo.

## Configuración

Desde **Settings** en el menú de la bandeja o en:

```text
%LOCALAPPDATA%\GitHubToLocalBackup\config.json
```

## Desinstalación

```powershell
.\Uninstall.ps1
```

Las copias existentes no se eliminan.

## Licencia

MIT — consulte [LICENSE](LICENSE).
