# ROMs

Estructura de carpetas de ROMs (una por consola) y `romsync`, la herramienta que mantiene iguales la copia de la PC y la del disco externo **CarlosHD**.

Este repositorio **no contiene ROMs ni BIOS**: el `.gitignore` solo deja pasar los `systeminfo.txt`, `systems.txt`, este README y los scripts. Los juegos viajan entre equipos por el disco externo, no por Git.

## 📁 Dónde está cada cosa

| Lugar | Ruta |
|-------|------|
| Linux | `~/ROMs` |
| Windows | `%USERPROFILE%\ROMs` |
| Disco externo (etiqueta `CarlosHD`, exFAT) | `backup/ROMs` |

Carpetas con contenido propio:

- `bios/`: respaldo de las BIOS (PS1, PS2, melonDS DS). RetroArch no las lee de aquí; hay que copiarlas a su carpeta `system` (ver el README del repositorio de saves).
- `<consola>/`: los juegos de cada sistema, con su `systeminfo.txt`.

## 🔄 ¿Qué hace romsync?

- Copia al disco lo que solo está en la PC, y a la PC lo que solo está en el disco.
- Si un archivo existe en ambos lados pero cambió, se queda la versión **más reciente**.
- Al terminar comprueba que ambos lados quedaron iguales.
- **Nunca borra nada.** Para eliminar un juego hay que borrarlo en los dos lados; si se borra solo en uno, el siguiente `sync` lo vuelve a copiar.

No se sincronizan: `.git/` (cada lado tiene su propio clon), `builtin/` (historial que crea RetroArch) ni archivos del sistema (`$RECYCLE.BIN`, `System Volume Information`, `Thumbs.db`, `desktop.ini`, `.DS_Store`).

## 🚀 Instalación

### Linux (Bash/Zsh)

Requiere `rsync` y `udisks2` (para montar el disco sin root).

1. Dale permisos de ejecución al script:

   ```bash
   chmod +x ~/ROMs/romsync.sh
   ```

2. Agrega un wrapper a tu `~/.bashrc` o `~/.zshrc`:

   ```bash
   romsync() {
     command ~/ROMs/romsync.sh "$@"
   }
   ```

3. Recarga tu shell:

   ```bash
   source ~/.bashrc   # o source ~/.zshrc
   ```

### Windows (PowerShell)

Usa `robocopy`, que ya viene con Windows.

1. Abre tu perfil de PowerShell:

   ```powershell
   notepad $PROFILE
   ```

2. Copia el contenido de `romsync.ps1` en ese archivo y recarga:

   ```powershell
   . $PROFILE
   ```

También se puede ejecutar sin instalar: `.\romsync.ps1 status`.

> [!WARNING]
> `romsync.ps1` todavía no se ha probado en Windows; la versión de Linux sí. La primera vez ejecuta `romsync status` y revisa la lista antes de hacer `romsync sync`.

## 📝 Uso

```bash
romsync           # Igual que 'romsync sync'
romsync sync      # Copia lo nuevo/actualizado en ambos sentidos y comprueba el resultado
romsync status    # Muestra qué difiere, sin copiar nada
romsync verify    # Compara el contenido archivo por archivo con checksum (lento)
romsync open      # Abre la carpeta de ROMs del disco
romsync help      # Muestra la ayuda y las rutas en uso
```

### Flujo típico

```bash
# Conecta el disco CarlosHD
romsync status    # Opcional: ver qué va a cambiar
romsync sync      # Dejar PC y disco iguales
```

`status` y `sync` comparan por tamaño y fecha, que es rápido. `verify` lee todos los archivos de ambos lados (varios minutos con ~31 GB), así que solo hace falta de vez en cuando o si sospechas de una copia dañada.

En Linux el script monta el disco solo si está conectado pero sin montar.

## ⚙️ Configuración

Las rutas se pueden cambiar con variables de entorno, sin editar los scripts:

| Variable | Valor por defecto | Qué es |
|----------|-------------------|--------|
| `ROMS_DIR` | `~/ROMs` (Linux), `%USERPROFILE%\ROMs` (Windows) | Carpeta de ROMs en la PC |
| `ROMS_DRIVE_LABEL` | `CarlosHD` | Etiqueta del disco externo |
| `ROMS_DRIVE_SUBDIR` | `backup/ROMs` | Carpeta dentro del disco |

```bash
ROMS_DIR=/mnt/juegos/ROMs romsync status
```

```powershell
$env:ROMS_DIR = "D:\ROMs"; romsync status
```

## 🧩 Git en el disco externo

La carpeta del disco también es un clon de este repositorio. Como `romsync` copia los scripts y el README como archivos normales pero no toca `.git/`, ahí `git status` mostrará cambios hasta que hagas `git pull`. No afecta a los juegos.
