# ROMs

Carpetas de ROMs (una por consola) y `romsync`, que mantiene idénticas la copia de la PC y la del disco externo **CarlosHD**.

Este repositorio **no contiene juegos ni BIOS**: el `.gitignore` solo deja pasar los `systeminfo.txt`, `systems.txt`, este README y los scripts. Los juegos viajan entre equipos por el disco, no por Git.

| | Ruta |
|---|---|
| Linux | `~/ROMs` |
| Windows | `%USERPROFILE%\ROMs` |
| Disco `CarlosHD` (exFAT) | `backup/ROMs` |

- `<consola>/`: los juegos de cada sistema.
- `bios/`: respaldo de las BIOS de PS1, PS2 y DS. RetroArch no las lee de aquí; cómo instalarlas está en el repositorio [saves](https://github.com/Carlos12001/saves).

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

## Git en el disco

La carpeta del disco también es un clon de este repositorio. `romsync` copia los scripts y el README como archivos normales pero no toca `.git/`, así que ahí `git status` mostrará cambios hasta que hagas `git pull`. No afecta a los juegos.
