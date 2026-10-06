# ROMs

*[English](README.md)*

Carpetas de ROMs (una por consola) y dos scripts que mantienen idéntica la copia de la PC con la del disco externo y la del teléfono.

| Script | Sincroniza `~/ROMs` con | Plataforma |
|---|---|---|
| `romsync.sh` / `romsync.ps1` | Disco externo **CarlosHD** | Linux / Windows |
| `romsync-phone.sh` | Teléfono Android por USB | Linux |

Este repositorio **no contiene juegos ni BIOS**: el `.gitignore` solo deja pasar los `systeminfo.txt`, `systems.txt`, los README, `AGENTS.md` y los scripts. Los juegos viajan por el disco o por USB, no por Git.

| | Ruta |
|---|---|
| Linux | `~/ROMs` |
| Windows | `%USERPROFILE%\ROMs` |
| Disco `CarlosHD` (exFAT) | `backup/ROMs` |
| Teléfono Android | `ROMs` en el almacenamiento interno (`/storage/emulated/0/ROMs`) |

- `<consola>/`: los juegos de cada sistema.
- `bios/`: respaldo de las BIOS de PS1, PS2 y DS. RetroArch no las lee de aquí; cómo instalarlas está en el repositorio [saves](https://github.com/Carlos12001/saves).

## Requisitos

```bash
sudo pacman -S --needed git openssh rsync udisks2 android-file-transfer
```

| Paquete | Para qué |
|---|---|
| `git`, `openssh` | Clonar y actualizar este repositorio por SSH |
| `rsync` | Copiar y comparar los archivos (los dos scripts de Linux) |
| `udisks2` | `romsync`: montar el disco externo sin root |
| `android-file-transfer` | `romsync-phone`: montar el teléfono por USB (`aft-mtp-mount`) |

En Windows no hay que instalar nada para `romsync.ps1`: usa `robocopy` y PowerShell, que vienen con el sistema. Solo hace falta [Git for Windows](https://git-scm.com/download/win) para clonar el repositorio.

# Disco externo: romsync

## Uso

Conecta el disco y ejecuta:

```bash
romsync
```

| Comando | Qué hace |
|---|---|
| `romsync` / `romsync sync` | Copia lo nuevo o actualizado en ambos sentidos y comprueba que quedaron iguales |
| `romsync status` | Lista qué difiere, sin copiar nada |
| `romsync verify` | Compara el contenido de cada archivo con checksum (varios minutos con ~31 GB) |
| `romsync open` | Abre la carpeta de ROMs del disco |
| `romsync help` | Muestra la ayuda y las rutas en uso |

## Cómo decide qué copiar

- Un archivo que solo está en un lado se copia al otro.
- Si está en ambos pero difiere en tamaño o fecha, gana el **más reciente**.
- **Nunca borra.** Para eliminar un juego, bórralo en los dos lados; si lo borras solo en uno, el siguiente `sync` lo restaura.
- `sync` y `status` comparan tamaño y fecha (rápido). Solo `verify` lee el contenido.

No se sincronizan `.git/`, `builtin/` (historial que crea RetroArch) ni archivos del sistema (`$RECYCLE.BIN`, `System Volume Information`, `.Trash-*`, `Thumbs.db`, `desktop.ini`, `.DS_Store`).

## Instalación

### Linux (Bash/Zsh)

Requiere `rsync` y `udisks2`. Si el disco está conectado pero sin montar, el script lo monta solo.

```bash
chmod +x ~/ROMs/romsync.sh
```

Agrega esto a `~/.bashrc` o `~/.zshrc` y abre una terminal nueva:

```bash
romsync() {
  command ~/ROMs/romsync.sh "$@"
}
```

### Windows (PowerShell)

Usa `robocopy`, incluido en Windows. Copia el contenido de `romsync.ps1` en tu perfil y recárgalo:

```powershell
notepad $PROFILE
. $PROFILE
```

Sin instalar también funciona: `.\romsync.ps1 status`.

> [!WARNING]
> `romsync.ps1` no se ha probado todavía en Windows; `romsync.sh` sí. La primera vez ejecuta `romsync status` y revisa la lista antes de `romsync sync`.

## Configuración

Las rutas se cambian con variables de entorno, sin editar los scripts:

| Variable | Por defecto | Qué es |
|---|---|---|
| `ROMS_DIR` | `~/ROMs` o `%USERPROFILE%\ROMs` | Carpeta de ROMs en la PC |
| `ROMS_DRIVE_LABEL` | `CarlosHD` | Etiqueta del disco |
| `ROMS_DRIVE_SUBDIR` | `backup/ROMs` | Carpeta dentro del disco |

```bash
ROMS_DIR=/mnt/juegos/ROMs romsync status
```

```powershell
$env:ROMS_DIR = "D:\ROMs"; romsync status
```

# Teléfono Android: romsync-phone

Solo para Linux. El teléfono se conecta por USB en modo **Transferencia de archivos** (MTP) y el script lo monta, sincroniza y desmonta solo.

## Uso

Conecta el teléfono, desbloquéalo, elige "Transferencia de archivos" en la notificación de USB y ejecuta:

```bash
romsync-phone
```

| Comando | Qué hace |
|---|---|
| `romsync-phone` / `romsync-phone sync` | Copia los ROMs que faltan en ambos sentidos y comprueba que quedaron iguales |
| `romsync-phone status` | Lista qué difiere, sin copiar nada |
| `romsync-phone verify` | Compara el contenido con checksum (lee toda la copia del teléfono, muy lento) |
| `romsync-phone mount` | Monta el teléfono en `$XDG_RUNTIME_DIR/romsync-phone` y lo deja montado |
| `romsync-phone unmount` | Lo desmonta |

La primera copia completa (~31 GB) tarda unos 45 minutos a ~11 MB/s. Si se corta o se desconecta el cable, vuelve a ejecutar `romsync-phone`: continúa donde quedó.

## Cómo decide qué copiar

MTP no conserva la fecha de los archivos, así que aquí se compara por **nombre y tamaño**, no por fecha:

- Un archivo que solo está en un lado se copia al otro.
- Si está en ambos con distinto tamaño, gana el **más grande** (el pequeño es casi siempre una copia interrumpida).
- **Nunca borra.** Para eliminar un juego, bórralo en los dos lados.

No se sincronizan `.git/`, `builtin/`, `.thumbnails/` ni los archivos que lleva Git (`systeminfo.txt`, `systems.txt`, `.gitignore`, `README*.md`, `AGENTS.md`, `CLAUDE.md`, `romsync*`).

## Instalación

```bash
sudo pacman -S android-file-transfer rsync
chmod +x ~/ROMs/romsync-phone.sh
```

Agrega esto a `~/.bashrc` o `~/.zshrc` y abre una terminal nueva:

```bash
romsync-phone() {
  command ~/ROMs/romsync-phone.sh "$@"
}
```

`ROMS_DIR` cambia la carpeta de la PC y `ROMS_PHONE_SUBDIR` (por defecto `ROMs`) la carpeta dentro del teléfono.

## Problemas conocidos

| Síntoma | Solución |
|---|---|
| `Error: no phone found` | Desbloquea el teléfono y elige "Transferencia de archivos"; prueba otro cable o puerto |
| La copia se corta a medias | El cable perdió conexión: reconecta y repite `romsync-phone` |
| Dolphin (el explorador de KDE) tiene abierto el teléfono | Ciérralo; MTP solo admite un programa a la vez |

## Git en el disco y en el teléfono

La carpeta del disco también es un clon de este repositorio. `romsync` copia los scripts y los README como archivos normales pero no toca `.git/`, así que ahí `git status` mostrará cambios hasta que hagas `git pull`. No afecta a los juegos.

`romsync-phone` no copia ningún archivo rastreado por Git: en el teléfono esos archivos se actualizan con `git pull`.

## Contribuir

Las convenciones del repositorio (formato de commits, qué no se toca, cómo probar) están en [AGENTS.md](AGENTS.md). Valen igual para personas y para agentes de IA; `CLAUDE.md` solo lo importa.
