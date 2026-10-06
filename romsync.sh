#!/bin/bash

# ROM Sync (romsync)
# Keep your ROMs folder and the external drive copy identical, in both directions

romsync() {
  local command="${1:-sync}"
  local local_dir="${ROMS_DIR:-$HOME/ROMs}"
  local drive_label="${ROMS_DRIVE_LABEL:-CarlosHD}"
  local drive_subdir="${ROMS_DRIVE_SUBDIR:-backup/ROMs}"
  local drive_dir=""

  # Never synced: each side keeps its own git clone, and the rest is OS/RetroArch junk
  local excludes=(
    --exclude='.git/'
    --exclude='builtin/'
    --exclude='$RECYCLE.BIN/'
    --exclude='System Volume Information/'
    --exclude='.Trash-*/'
    --exclude='Thumbs.db'
    --exclude='desktop.ini'
    --exclude='.DS_Store'
  )

  # exFAT has no permissions/owners and coarse timestamps, so compare by size + time only
  local base_opts=(-rt --modify-window=2 "${excludes[@]}")

  find_drive() {
    local mount_point
    mount_point="$(findmnt -n -o TARGET -S "LABEL=$drive_label" 2>/dev/null | head -n1)"

    # Drive plugged in but not mounted: mount it (no root needed)
    if [[ -z "$mount_point" && -e "/dev/disk/by-label/$drive_label" ]]; then
      echo -e "\033[36mMounting $drive_label...\033[0m"
      udisksctl mount -b "/dev/disk/by-label/$drive_label" >/dev/null 2>&1
      mount_point="$(findmnt -n -o TARGET -S "LABEL=$drive_label" 2>/dev/null | head -n1)"
    fi

    if [[ -z "$mount_point" ]]; then
      echo -e "\033[31mError: drive '$drive_label' not found. Plug it in and try again.\033[0m"
      return 1
    fi

    drive_dir="$mount_point/$drive_subdir"
  }

  # List files that differ from $1 to $2 without copying anything
  pending() {
    rsync "${base_opts[@]}" -n "${@:3}" --out-format='%n' "$1/" "$2/" | grep -v '/$'
  }

  show_pending() {
    local to_drive to_local
    to_drive="$(pending "$local_dir" "$drive_dir" "$@")"
    to_local="$(pending "$drive_dir" "$local_dir" "$@")"

    if [[ -z "$to_drive" && -z "$to_local" ]]; then
      return 0
    fi

    if [[ -n "$to_drive" ]]; then
      echo -e "\033[33mLaptop -> $drive_label ($(wc -l <<<"$to_drive") files):\033[0m"
      sed 's/^/  /' <<<"$to_drive"
    fi
    if [[ -n "$to_local" ]]; then
      echo -e "\033[33m$drive_label -> Laptop ($(wc -l <<<"$to_local") files):\033[0m"
      sed 's/^/  /' <<<"$to_local"
    fi
    return 1
  }

  execute_commands() {
    case "$command" in
    "sync")
      echo -e "\033[32mCopying new/updated ROMs: Laptop -> $drive_label...\033[0m"
      rsync "${base_opts[@]}" --update -h --info=name1,progress2 "$local_dir/" "$drive_dir/" || return 1
      echo -e "\033[32mCopying new/updated ROMs: $drive_label -> Laptop...\033[0m"
      rsync "${base_opts[@]}" --update -h --info=name1,progress2 "$drive_dir/" "$local_dir/" || return 1

      echo -e "\033[36mChecking that both sides match...\033[0m"
      if show_pending; then
        echo -e "\033[32mLaptop and $drive_label are identical.\033[0m"
      else
        echo -e "\033[31mBoth sides still differ (see the list above).\033[0m"
        return 1
      fi
      ;;
    "status")
      echo -e "\033[33mComparing by size and date (nothing is copied)...\033[0m"
      if show_pending --update; then
        echo -e "\033[32mLaptop and $drive_label are identical.\033[0m"
      else
        echo -e "\033[33mRun 'romsync sync' to make both sides equal.\033[0m"
        return 1
      fi
      ;;
    "verify")
      echo -e "\033[33mComparing file contents by checksum (slow, nothing is copied)...\033[0m"
      if show_pending --checksum; then
        echo -e "\033[32mEvery file has the same content on both sides.\033[0m"
      else
        echo -e "\033[31mThe files above are missing or have different content.\033[0m"
        return 1
      fi
      ;;
    "open")
      echo -e "\033[36mOpening ROMs directory on $drive_label...\033[0m"
      xdg-open "$drive_dir" 2>/dev/null || echo "Could not open file manager"
      ;;
    *)
      echo -e "\033[35mROM Sync (romsync)\033[0m"
      echo "Usage: romsync [command]"
      echo ""
      echo -e "\033[33mCommands:\033[0m"
      echo "  sync        - Copy new/updated ROMs in both directions (default)"
      echo "  status      - Show what differs, without copying"
      echo "  verify      - Compare file contents by checksum (slow)"
      echo "  open        - Open the drive's ROMs directory in file manager"
      echo ""
      echo -e "\033[33mPaths:\033[0m"
      echo "  Laptop: $local_dir"
      echo "  Drive:  $drive_label:/$drive_subdir"
      ;;
    esac
  }

  if [[ "$command" == "help" || "$command" == "-h" || "$command" == "--help" ]]; then
    execute_commands
    return
  fi

  if [[ ! -d "$local_dir" ]]; then
    echo -e "\033[31mError: ROMs directory not found at: $local_dir\033[0m"
    return 1
  fi

  find_drive || return 1

  if [[ ! -d "$drive_dir" ]]; then
    echo -e "\033[33mCreating $drive_dir (first sync)...\033[0m"
    mkdir -p "$drive_dir" || return 1
  fi

  execute_commands
}

# If script is run directly (not sourced), execute the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  romsync "$@"
fi
