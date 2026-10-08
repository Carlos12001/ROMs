# ROMs

*[Español](README.es.md)*

ROM folders (one per console) and two scripts that keep the PC copy identical to
the copy on the external drive and on the phone.

| Script | Syncs `~/ROMs` with | Platform |
| --- | --- | --- |
| `romsync.sh` / `romsync.ps1` | External drive **CarlosHD** | Linux / Windows |
| `romsync-phone.sh` | Android phone over USB | Linux |

This repository **contains no games or BIOS files**: the `.gitignore` only lets
through the `systeminfo.txt` files, `systems.txt`, the READMEs, `AGENTS.md` and
the scripts. Games travel on the drive or over USB, not through Git.

| | Path |
| --- | --- |
| Linux | `~/ROMs` |
| Windows | `%USERPROFILE%\ROMs` |
| Drive `CarlosHD` (exFAT) | `backup/ROMs` |
| Android phone | `ROMs` in internal storage (`/storage/emulated/0/ROMs`) |

- `<console>/`: the games for each system.
- `bios/`: backup of the PS1, PS2 and DS BIOS files. RetroArch does not read
  them from here; how to install them is in the [saves][saves] repository.

## Requirements

```bash
sudo pacman -S --needed git openssh rsync udisks2 android-file-transfer
```

| Package | What for |
| --- | --- |
| `git`, `openssh` | Clone and update this repository over SSH |
| `rsync` | Copy and compare files (both Linux scripts) |
| `udisks2` | `romsync`: mount the external drive without root |
| `android-file-transfer` | `romsync-phone`: mount the phone over USB (`aft-mtp-mount`) |

On Windows nothing needs installing for `romsync.ps1`: it uses `robocopy` and
PowerShell, which ship with the system. Only [Git for Windows][git-win] is
needed to clone the repository.

## External drive: romsync

### Usage

Plug in the drive and run:

```bash
romsync
```

| Command | What it does |
| --- | --- |
| `romsync` / `romsync sync` | Copies new or updated files in both directions and checks both sides match |
| `romsync status` | Lists what differs, without copying |
| `romsync verify` | Compares every file's content by checksum (several minutes with ~31 GB) |
| `romsync open` | Opens the drive's ROMs folder |
| `romsync help` | Shows the help and the paths in use |

### How it decides what to copy

- A file that exists on one side only is copied to the other.
- If it exists on both but differs in size or date, the **newest** wins.
- **It never deletes.** To remove a game, delete it on both sides; if you delete
  it on one only, the next `sync` restores it.
- `sync` and `status` compare size and date (fast). Only `verify` reads the
  content.

Not synced: `.git/`, `builtin/` (history created by RetroArch) and system files
(`$RECYCLE.BIN`, `System Volume Information`, `.Trash-*`, `Thumbs.db`,
`desktop.ini`, `.DS_Store`).

### Installation

#### Linux (Bash/Zsh)

Needs `rsync` and `udisks2`. If the drive is plugged in but not mounted, the
script mounts it.

```bash
chmod +x ~/ROMs/romsync.sh
```

Add this to `~/.bashrc` or `~/.zshrc` and open a new terminal:

```bash
romsync() {
  command ~/ROMs/romsync.sh "$@"
}
```

#### Windows (PowerShell)

Uses `robocopy`, included in Windows. Copy the content of `romsync.ps1` into
your profile and reload it:

```powershell
notepad $PROFILE
. $PROFILE
```

It also runs without installing: `.\romsync.ps1 status`.

> [!WARNING]
> `romsync.ps1` has not been tested on Windows yet; `romsync.sh` has. The first
> time, run `romsync status` and review the list before `romsync sync`.

### Configuration

Paths are changed with environment variables, without editing the scripts:

| Variable | Default | What it is |
| --- | --- | --- |
| `ROMS_DIR` | `~/ROMs` or `%USERPROFILE%\ROMs` | ROMs folder on the PC |
| `ROMS_DRIVE_LABEL` | `CarlosHD` | Drive label |
| `ROMS_DRIVE_SUBDIR` | `backup/ROMs` | Folder inside the drive |

```bash
ROMS_DIR=/mnt/games/ROMs romsync status
```

```powershell
$env:ROMS_DIR = "D:\ROMs"; romsync status
```

## Android phone: romsync-phone

Linux only. The phone connects over USB in **File transfer** (MTP) mode and the
script mounts it, syncs and unmounts it.

### Phone: usage

Plug in the phone, unlock it, choose "File transfer" in the USB notification and
run:

```bash
romsync-phone
```

| Command | What it does |
| --- | --- |
| `romsync-phone` / `romsync-phone sync` | Copies missing ROMs in both directions and checks both sides match |
| `romsync-phone status` | Lists what differs, without copying |
| `romsync-phone verify` | Compares content by checksum (reads the whole phone copy, very slow) |
| `romsync-phone mount` | Mounts the phone at `$XDG_RUNTIME_DIR/romsync-phone` and leaves it mounted |
| `romsync-phone unmount` | Unmounts it |

The first full copy took about 45 minutes at ~11 MB/s when it was ~31 GB; with
the heavy consoles left out it is ~16 GB. If it is interrupted or the cable
disconnects, run `romsync-phone` again: it continues where it stopped.

### Phone: how it decides what to copy

MTP does not keep file dates, so files are compared by **name and size**, not by
date:

- A file that exists on one side only is copied to the other.
- If it exists on both with a different size, the **largest** wins (the small
  one is almost always an interrupted copy).
- **It never deletes.** To remove a game, delete it on both sides.

Not synced: `.git/`, `builtin/`, `.thumbnails/` and the files Git carries
(`systeminfo.txt`, `systems.txt`, `.gitignore`, `README*.md`, `AGENTS.md`,
`CLAUDE.md`, `romsync*`).

### Phone: systems left out

The phone gets every console up to the fifth generation (NES, SNES, Mega Drive,
PS1, N64, Saturn and older) and every handheld (Game Boy, GBA, DS, PSP, 3DS,
PS Vita). Home consoles from the sixth generation on are too heavy for it, so
their folders are left out:

| Left out | Folder |
| --- | --- |
| Dreamcast | `dreamcast` |
| GameCube, Wii, Wii U, Switch | `gc`, `wii`, `wiiu`, `switch` |
| PlayStation 2, 3 and 4 | `ps2`, `ps3`, `ps4` |
| Xbox, Xbox 360 | `xbox`, `xbox360` |

- A folder that is left out is ignored on both sides: nothing in it is copied,
  compared or deleted. Games of those consoles already on the phone stay there
  until you delete them by hand.
- `bios/` is still copied whole.
- `ROMS_PHONE_SKIP` replaces the list, with folder names separated by spaces.
  An empty value syncs everything:

  ```bash
  ROMS_PHONE_SKIP="gc wii ps2" romsync-phone status
  ROMS_PHONE_SKIP="" romsync-phone status
  ```

> [!NOTE]
> The list was added on 2026-10-07 and has not been run against the phone yet.

### Phone: installation

```bash
sudo pacman -S android-file-transfer rsync
chmod +x ~/ROMs/romsync-phone.sh
```

Add this to `~/.bashrc` or `~/.zshrc` and open a new terminal:

```bash
romsync-phone() {
  command ~/ROMs/romsync-phone.sh "$@"
}
```

`ROMS_DIR` changes the PC folder, `ROMS_PHONE_SUBDIR` (default `ROMs`) the
folder inside the phone and `ROMS_PHONE_SKIP` the systems left out.

### Known problems

| Symptom | Fix |
| --- | --- |
| `Error: no phone found` | Unlock the phone and choose "File transfer"; try another cable or port |
| The copy stops halfway | The cable lost connection: reconnect and run `romsync-phone` again |
| Dolphin (KDE's file manager) has the phone open | Close it; MTP allows one program at a time |

## Git on the drive and on the phone

The drive's folder is also a clone of this repository. `romsync` copies the
scripts and the READMEs as ordinary files but does not touch `.git/`, so
`git status` there shows changes until you run `git pull`. It does not affect
the games.

`romsync-phone` copies no file tracked by Git: on the phone those files are
updated with `git pull`.

## Contributing

The repository conventions (commit format, what must not be touched, how to
test) are in [AGENTS.md](AGENTS.md). They apply to people and to AI agents
alike; `CLAUDE.md` only imports it.

[saves]: https://github.com/Carlos12001/saves
[git-win]: https://git-scm.com/download/win
