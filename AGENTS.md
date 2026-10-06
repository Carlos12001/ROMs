# Instrucciones para agentes

Repositorio con la estructura de carpetas de ROMs y los scripts que la sincronizan con el disco externo `CarlosHD` y con el teléfono Android. Vive en `~/ROMs`. El README explica el uso; léelo antes de cambiar nada.

## Qué hay y qué no

- Los juegos y las BIOS están en estas carpetas pero **no** en Git: el `.gitignore` ignora todo y solo permite `systeminfo.txt`, `systems.txt`, los README, este archivo y `romsync*`.
- Nunca añadas un ROM o una BIOS al repositorio. Un archivo nuevo que sí deba versionarse necesita su excepción `!patrón` en el `.gitignore`.
- `builtin/` lo crea RetroArch y no pertenece al repositorio ni a las copias.

## Los scripts no borran

`romsync` y `romsync-phone` solo copian. No añadas borrado, `--delete` ni `/PURGE` sin que el usuario lo pida: un error ahí elimina juegos en los dos lados.

| Script | Destino | Compara por | Si un archivo difiere |
|---|---|---|---|
| `romsync.sh`, `romsync.ps1` | Disco `CarlosHD`, `backup/ROMs` | Tamaño y fecha | Gana el más reciente |
| `romsync-phone.sh` | Teléfono, `ROMs` en el almacenamiento interno | Nombre y tamaño | Gana el más grande |

- `romsync.sh` y `romsync.ps1` deben ofrecer los mismos comandos y el mismo comportamiento.
- El teléfono va por MTP: no conserva fechas ni admite renombrar, por eso `rsync` usa `--inplace --whole-file` y no se compara por fecha.
- Los mensajes de los scripts van en inglés y con el mismo estilo de colores.

## Probar cambios

```bash
bash -n romsync.sh romsync-phone.sh    # Sintaxis
./romsync.sh status                    # No copia nada
./romsync-phone.sh status              # No copia nada
```

- Ejecuta siempre `status` antes de `sync` y revisa la lista.
- Para probar una copia, usa un archivo temporal pequeño y bórralo en los dos lados al terminar.
- Una copia completa son ~31 GB y tarda (unos 45 minutos al teléfono). Lánzala como proceso independiente con registro en un archivo, no dentro de un comando con límite de tiempo.
- `verify` lee todos los archivos; no la ejecutes mientras otra copia está en curso.
- `romsync.ps1` no se puede probar en Linux: si lo cambias, dilo en el README y al usuario.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), en inglés, en minúscula, en imperativo, sin scope y sin punto final:

```text
<tipo>: <resumen de menos de 72 caracteres>
```

| Tipo | Cuándo |
|---|---|
| `feat` | Función nueva en los scripts o consola nueva |
| `fix` | Corrección de un error |
| `docs` | README y este archivo |
| `chore` | Limpieza y mantenimiento |

Se trabaja directamente sobre `main` y se sube con `git push`. No reescribas el historial.

## Documentación

- El README va en español, concreto: tablas, comandos para copiar y pegar, rutas reales.
- Cada paquete, comando o variable nueva se documenta en el README en el mismo cambio.
- Lo que no se ha probado se marca con una nota `> [!WARNING]` o `> [!NOTE]`.
- La instalación de RetroArch, cores y BIOS se documenta en el repositorio [saves](https://github.com/Carlos12001/saves), no aquí.
