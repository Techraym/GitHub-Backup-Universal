# GitHub to Local Backup

**Realiza copias de seguridad automáticas de repositorios de GitHub en Windows hacia un disco local, una unidad USB, un recurso de red o un NAS.**

[English](README.md) · [Nederlands](README.nl.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md)

## Descripción

GitHub to Local Backup es una herramienta ligera de PowerShell para Windows que crea copias completas tipo espejo de los repositorios de un usuario u organización de GitHub. El origen y el destino se eligen durante la instalación.

## Funciones

- Usuario u organización de GitHub como origen
- Carpeta de destino configurable
- Discos locales, unidades USB, unidades asignadas y rutas UNC
- Repositorios públicos y privados
- Copias completas con `git clone --mirror`
- Actualización automática de espejos existentes
- Tarea semanal mediante el Programador de tareas de Windows
- Las ejecuciones omitidas se vuelven a intentar más tarde
- Icono de estado en la bandeja del sistema
- Protección contra múltiples iconos duplicados
- Un destino temporalmente no disponible no se considera una copia dañada
- Archivos de estado y registro

## Icono de estado

- 🟢 **Verde** — copia reciente y correcta
- 🟠 **Naranja** — en ejecución, antigua, nunca ejecutada o destino no disponible
- 🔴 **Rojo** — error real de copia

## Requisitos

- Windows 10 o Windows 11
- Windows PowerShell 5.1 o superior
- Git
- GitHub CLI (`gh`)
- Inicio de sesión único mediante:

```powershell
gh auth login
```

## Instalación interactiva

Abra PowerShell en la carpeta del proyecto extraído:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install.ps1
```

El instalador solicita:

- **Origen** — usuario u organización de GitHub, por ejemplo `Techraym`
- **Destino** — carpeta local o ruta de red, por ejemplo `D:\Backups\GitHub` o `\\NAS\Backups\GitHub`

## Instalación con parámetros

```powershell
.\Install.ps1 `
    -Source "Techraym" `
    -Destination "\\NAS\Backups\GitHub" `
    -RunNow
```

## Visibilidad de repositorios

Para copiar solo repositorios públicos:

```powershell
.\Install.ps1 -Source "ejemplo" -Destination "D:\GitHub" -Visibility public
```

Valores admitidos: `all`, `public`, `private`.

## ¿Por qué copias espejo?

`git clone --mirror` conserva referencias Git, ramas, etiquetas e historial del repositorio, no solo los archivos actuales.

## Destino temporalmente no disponible

Si un NAS o recurso de red no está accesible, la ejecución se omite de forma segura. La copia existente no se modifica, el icono pasa a naranja y la siguiente ejecución programada lo vuelve a intentar.

## Configuración

```text
%LOCALAPPDATA%\GitHubNASBackup\config.json
```

## Contribuir

Consulte [CONTRIBUTING.md](CONTRIBUTING.md).

## Seguridad

Consulte [SECURITY.md](SECURITY.md).

## Licencia

MIT — consulte [LICENSE](LICENSE).
