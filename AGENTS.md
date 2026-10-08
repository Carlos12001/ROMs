# Agent instructions

Repository with the ROM folder structure and the scripts that sync it with the
external drive `CarlosHD` and with the Android phone. It lives in `~/ROMs`.
`README.md` explains the usage; read it before changing anything.

## What is here and what is not

- Games and BIOS files sit in these folders but are **not** in Git: the
  `.gitignore` ignores everything and only allows `systeminfo.txt`,
  `systems.txt`, `README*.md`, `AGENTS.md`, `CLAUDE.md` and `romsync*`.
- Never add a ROM or a BIOS file to the repository. A new file that should be
  versioned needs its own `!pattern` exception in the `.gitignore`.
- `builtin/` is created by RetroArch and belongs neither to the repository nor
  to the copies.

## The scripts do not delete

`romsync` and `romsync-phone` only copy. Do not add deletion, `--delete` or
`/PURGE` unless the user asks: a mistake there removes games on both sides.

| Script | Destination | Compares by | If a file differs |
| --- | --- | --- | --- |
| `romsync.sh`, `romsync.ps1` | Drive `CarlosHD`, `backup/ROMs` | Size and date | Newest wins |
| `romsync-phone.sh` | Phone, `ROMs` in internal storage | Name and size | Largest wins |

- `romsync.sh` and `romsync.ps1` must offer the same commands and the same
  behavior.
- The phone is reached over MTP: it keeps no dates and has no rename, so `rsync`
  uses `--inplace --whole-file` and nothing is compared by date.
- Script messages are in English and use the same color style.

## Testing changes

```bash
bash -n romsync.sh romsync-phone.sh    # Syntax
./romsync.sh status                    # Copies nothing
./romsync-phone.sh status              # Copies nothing
```

- Always run `status` before `sync` and review the list.
- To test a copy, use a small temporary file and delete it on both sides
  afterwards.
- A full copy is ~31 GB to the drive and ~16 GB to the phone, which leaves out
  the systems in `ROMS_PHONE_SKIP`, and takes a while (about 45 minutes for
  31 GB over MTP). Start it as a detached process, not inside a command with a
  time limit. If its
  output must be kept, write it to a temporary file in the allowed locations of
  the global rules (never the home folder or this repository) and delete it when
  the copy ends.
- `verify` reads every file; do not run it while another copy is in progress.
- The scripts write no log files: progress goes to the terminal.
  `romsync-phone.sh` keeps its scratch lists in `$XDG_RUNTIME_DIR` and removes
  them on exit, even when interrupted. Keep it that way.
- `romsync.ps1` cannot be tested on Linux: if you change it, say so in the
  README and to the user.

## Commits

[Conventional Commits][cc], in English, lowercase, imperative mood, no scope, no
trailing period:

```text
<type>: <summary under 72 characters>
```

| Type | When |
| --- | --- |
| `feat` | New script feature or new console |
| `fix` | Bug fix |
| `docs` | READMEs and this file |
| `chore` | Cleanup and maintenance |

Work happens directly on `main` and is published with `git push`. Do not rewrite
history.

## Documentation

- `README.md` is in English and is the main README. `README.es.md` is its
  Spanish translation: update the English file first, then mirror the change in
  the Spanish one.
- Keep it concrete: tables, copy-paste commands, real paths.
- Every new package, command or variable is documented in the README in the same
  change.
- Anything untested is marked with a `> [!WARNING]` or `> [!NOTE]` note.
- Installing RetroArch, cores and BIOS files is documented in the [saves][saves]
  repository, not here.

[cc]: https://www.conventionalcommits.org/
[saves]: https://github.com/Carlos12001/saves
