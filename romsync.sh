#!/bin/bash

# ROM Sync (romsync)
# Keep your ROMs folder and the external drive copy identical: in both
# directions without deleting, or in one direction as an exact copy

romsync() {
  local command="${1:-sync}"
  local local_dir="${ROMS_DIR:-$HOME/ROMs}"
  local drive_label="${ROMS_DRIVE_LABEL:-CarlosHD}"
  local drive_subdir="${ROMS_DRIVE_SUBDIR:-Backup/ROMs}"
  local drive_dir="${ROMS_DRIVE_DIR:-}"
  local show_all=false
  [[ "$2" == "--all" ]] && show_all=true

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
    # A folder given by hand replaces the drive, for tests and other disks
    [[ -n "$drive_dir" ]] && return 0

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

  # What a one-way run from $1 to $2 would do, as "kind<TAB>path" lines:
  # copy (missing in the destination), replace (different there) and delete
  # (not in the source). Extra rsync options follow. Nothing is changed.
  plan() {
    rsync "${base_opts[@]}" --delete -n --itemize-changes "${@:3}" \
      "$1/" "$2/" | awk '
        /^\*deleting / {
          path = substr($0, 13)
          if (path !~ /\/$/) print "delete\t" path
          next
        }
        /^>f\+/ { print "copy\t" substr($0, 13); next }
        /^>f/ { print "replace\t" substr($0, 13) }
      '
  }

  # Print the paths of one kind from a plan, under a title
  show_kind() {
    local paths count limit=20
    paths="$(awk -F'\t' -v kind="$2" '$1 == kind { print $2 }' <<<"$1")"
    [[ -z "$paths" ]] && return 0
    count="$(wc -l <<<"$paths")"

    echo -e "$3 ($count files):\033[0m"
    if [[ "$show_all" == true || "$count" -le "$limit" ]]; then
      sed 's/^/  /' <<<"$paths"
    else
      head -n "$limit" <<<"$paths" | sed 's/^/  /'
      echo "  ... and $((count - limit)) more ('--all' lists every file)"
    fi
  }

  # Make one side an exact copy of the other: $1 is "drive" or "laptop", the
  # side that is written. It shows what would change, asks, and only then
  # copies, replaces and deletes. The git clone and the junk files of the
  # excludes list are never touched on either side.
  mirror() {
    local from_dir to_dir from_name to_name
    if [[ "$1" == "drive" ]]; then
      from_dir="$local_dir" to_dir="$drive_dir"
      from_name="Laptop" to_name="$drive_label"
    else
      from_dir="$drive_dir" to_dir="$local_dir"
      from_name="$drive_label" to_name="Laptop"
    fi

    echo -e "\033[33mComparing by size and date: $to_name would become" \
      "an exact copy of $from_name...\033[0m"

    # An empty source would erase the whole destination: a drive mounted
    # wrong or a folder not yet filled must never do that
    if [[ -z "$(find "$from_dir" -type f -not -path '*/.git/*' \
      -print -quit)" ]]; then
      echo -e "\033[31m$from_name has no files. Refusing to erase" \
        "$to_name. Nothing was changed.\033[0m"
      return 1
    fi

    local changes newer
    changes="$(plan "$from_dir" "$to_dir")"
    if [[ -z "$changes" ]]; then
      echo -e "\033[32m$to_name is already an exact copy of" \
        "$from_name.\033[0m"
      return 0
    fi

    # Files that are newer in the destination: a replace that --update would
    # have skipped
    newer="$(comm -23 \
      <(awk -F'\t' '$1 == "replace" { print $2 }' <<<"$changes" | sort) \
      <(plan "$from_dir" "$to_dir" --update |
        awk -F'\t' '$1 == "replace" { print $2 }' | sort))"

    show_kind "$changes" copy "\033[32mCopy to $to_name"
    show_kind "$changes" replace "\033[33mReplace on $to_name"
    show_kind "$changes" delete "\033[31mDelete from $to_name"
    if [[ -n "$newer" ]]; then
      echo -e "\033[31mNewer on $to_name, would be lost" \
        "($(wc -l <<<"$newer") files):\033[0m"
      sed 's/^/  /' <<<"$newer"
    fi

    echo ""
    echo -e "\033[33mOn $to_name: $(grep -c '^copy' <<<"$changes") to copy," \
      "$(grep -c '^replace' <<<"$changes") to replace," \
      "$(grep -c '^delete' <<<"$changes") to delete.\033[0m"

    local answer
    read -r -p "Type 'yes' to make $to_name equal to $from_name: " answer
    if [[ "$answer" != "yes" ]]; then
      echo -e "\033[33mCancelled. Nothing was changed.\033[0m"
      return 1
    fi

    echo -e "\033[32mROMs: $from_name -> $to_name...\033[0m"
    rsync "${base_opts[@]}" --delete -h --info=name1,del1,progress2 \
      "$from_dir/" "$to_dir/" || return 1

    echo -e "\033[36mChecking that both sides match...\033[0m"
    if show_pending; then
      echo -e "\033[32mLaptop and $drive_label are identical.\033[0m"
    else
      echo -e "\033[31mBoth sides still differ (see the list above).\033[0m"
      return 1
    fi
  }

  execute_commands() {
    case "$command" in
    "to-drive")
      mirror drive
      ;;
    "to-laptop")
      mirror laptop
      ;;
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
      echo "  to-drive    - Make the drive an exact copy of the laptop"
      echo "  to-laptop   - Make the laptop an exact copy of the drive"
      echo "  status      - Show what differs, without copying"
      echo "  verify      - Compare file contents by checksum (slow)"
      echo "  open        - Open the drive's ROMs directory in file manager"
      echo ""
      echo "'sync' never deletes. 'to-drive' and 'to-laptop' replace and"
      echo "delete on the side they write, after showing the list and asking."
      echo "Add '--all' to list every file."
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
