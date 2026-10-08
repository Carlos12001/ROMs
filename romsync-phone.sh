#!/bin/bash

# ROM Sync for Android (romsync-phone)
# Keep your ROMs folder and the copy on your phone identical, in both directions.
# The phone is reached over USB in "File transfer" (MTP) mode.

romsync_phone() {
  local command="${1:-sync}"
  local local_dir="${ROMS_DIR:-$HOME/ROMs}"
  local phone_subdir="${ROMS_PHONE_SUBDIR:-ROMs}"
  local mount_dir="${XDG_RUNTIME_DIR:-/tmp}/romsync-phone"
  local phone_dir=""
  local work_dir=""

  # Home consoles from the sixth generation on are too heavy for the phone:
  # their folders are left out on both sides, never copied and never deleted
  local skip_default="dreamcast gc ps2 xbox wii ps3 xbox360 wiiu ps4 switch"
  local skip_systems="${ROMS_PHONE_SKIP-$skip_default}"

  # Never synced: the git clone and the files it tracks travel through Git, the rest is junk
  local find_excludes=(
    -not -path './.git/*'
    -not -path './builtin/*'
    -not -path './.thumbnails/*'
    -not -name 'systeminfo.txt'
    -not -name 'systems.txt'
    -not -name '.gitignore'
    -not -name 'README*.md'
    -not -name 'AGENTS.md'
    -not -name 'CLAUDE.md'
    -not -name 'romsync*'
    -not -name '.nomedia'
    -not -name 'Thumbs.db'
    -not -name 'desktop.ini'
    -not -name '.DS_Store'
  )

  local rsync_skips=()
  local system
  for system in $skip_systems; do
    find_excludes+=(-not -path "./$system/*")
    rsync_skips+=(--exclude="/$system/")
  done

  mount_phone() {
    if ! command -v aft-mtp-mount >/dev/null 2>&1; then
      echo -e "\033[31mError: aft-mtp-mount not found. Install the 'android-file-transfer' package.\033[0m"
      return 1
    fi

    # A mount left behind by an unplugged phone no longer answers: drop it and mount again
    if is_mounted && ! ls "$mount_dir" >/dev/null 2>&1; then
      unmount_phone
    fi

    mkdir -p "$mount_dir"
    if ! is_mounted; then
      echo -e "\033[36mMounting phone...\033[0m"
      if ! aft-mtp-mount "$mount_dir" >/dev/null 2>&1; then
        rmdir "$mount_dir" 2>/dev/null
        echo -e "\033[31mError: no phone found.\033[0m"
        echo -e "\033[33mPlug it in, unlock it and choose 'File transfer' in the USB notification.\033[0m"
        return 1
      fi
    fi

    # The first folder of the mount is the phone's internal storage
    local storage
    storage="$(find "$mount_dir" -mindepth 1 -maxdepth 1 -type d | sort | head -n1)"
    if [[ -z "$storage" ]]; then
      echo -e "\033[31mError: the phone shows no storage. Unlock it and try again.\033[0m"
      return 1
    fi

    phone_dir="$storage/$phone_subdir"
  }

  # True while the kernel still lists the mount, even if the phone behind it is gone
  is_mounted() {
    grep -q " $mount_dir fuse" /proc/mounts
  }

  unmount_phone() {
    if is_mounted; then
      fusermount3 -u "$mount_dir" 2>/dev/null || fusermount -u "$mount_dir" 2>/dev/null
    fi
    # Remove the empty mount point too
    rmdir "$mount_dir" 2>/dev/null
  }

  # "size<TAB>path" for every file, sorted by path
  list_files() {
    (cd "$1" && find . -type f "${find_excludes[@]}" -printf '%s\t%P\n') | LC_ALL=C sort -t$'\t' -k2
  }

  # MTP cannot keep file dates, so files are compared by name and size only.
  # Writes the files each side needs into to_phone.txt and to_laptop.txt:
  # a file missing on one side, or smaller there (an interrupted copy), is taken from the other.
  compare() {
    list_files "$local_dir" >"$work_dir/laptop.txt"
    list_files "$phone_dir" >"$work_dir/phone.txt"

    awk -F'\t' -v out_phone="$work_dir/to_phone.txt" -v out_laptop="$work_dir/to_laptop.txt" '
      FNR == NR { laptop[$2] = $1; next }
      {
        phone[$2] = $1
        if (!($2 in laptop) || $1 + 0 > laptop[$2] + 0) print $2 > out_laptop
      }
      END {
        for (path in laptop)
          if (!(path in phone) || laptop[path] + 0 > phone[path] + 0) print path > out_phone
      }
    ' "$work_dir/laptop.txt" "$work_dir/phone.txt"

    touch "$work_dir/to_phone.txt" "$work_dir/to_laptop.txt"
    LC_ALL=C sort -o "$work_dir/to_phone.txt" "$work_dir/to_phone.txt"
    LC_ALL=C sort -o "$work_dir/to_laptop.txt" "$work_dir/to_laptop.txt"
  }

  show_pending() {
    compare

    if [[ ! -s "$work_dir/to_phone.txt" && ! -s "$work_dir/to_laptop.txt" ]]; then
      return 0
    fi

    if [[ -s "$work_dir/to_phone.txt" ]]; then
      echo -e "\033[33mLaptop -> Phone ($(wc -l <"$work_dir/to_phone.txt") files):\033[0m"
      sed 's/^/  /' "$work_dir/to_phone.txt"
    fi
    if [[ -s "$work_dir/to_laptop.txt" ]]; then
      echo -e "\033[33mPhone -> Laptop ($(wc -l <"$work_dir/to_laptop.txt") files):\033[0m"
      sed 's/^/  /' "$work_dir/to_laptop.txt"
    fi
    return 1
  }

  # --inplace and --whole-file because MTP has no rename and no partial updates
  copy_files() {
    rsync -r --inplace --whole-file --files-from="$1" -h --info=name1,progress2 "$2/" "$3/"
  }

  execute_commands() {
    case "$command" in
    "sync")
      compare

      if [[ -s "$work_dir/to_phone.txt" ]]; then
        echo -e "\033[32mCopying ROMs: Laptop -> Phone ($(wc -l <"$work_dir/to_phone.txt") files)...\033[0m"
        copy_files "$work_dir/to_phone.txt" "$local_dir" "$phone_dir" || return 1
      fi
      if [[ -s "$work_dir/to_laptop.txt" ]]; then
        echo -e "\033[32mCopying ROMs: Phone -> Laptop ($(wc -l <"$work_dir/to_laptop.txt") files)...\033[0m"
        copy_files "$work_dir/to_laptop.txt" "$phone_dir" "$local_dir" || return 1
      fi

      echo -e "\033[36mChecking that both sides match...\033[0m"
      if show_pending; then
        echo -e "\033[32mLaptop and phone are identical.\033[0m"
      else
        echo -e "\033[31mBoth sides still differ (see the list above).\033[0m"
        return 1
      fi
      ;;
    "status")
      echo -e "\033[33mComparing by name and size (nothing is copied)...\033[0m"
      if show_pending; then
        echo -e "\033[32mLaptop and phone are identical.\033[0m"
      else
        echo -e "\033[33mRun 'romsync-phone sync' to make both sides equal.\033[0m"
        return 1
      fi
      ;;
    "verify")
      echo -e "\033[33mComparing file contents by checksum (slow, reads the whole phone copy)...\033[0m"
      local differing
      differing="$(rsync -rn --checksum --out-format='%n' \
        --exclude='.git/' --exclude='builtin/' --exclude='.thumbnails/' \
        --exclude='systeminfo.txt' --exclude='systems.txt' --exclude='.gitignore' \
        --exclude='README*.md' --exclude='AGENTS.md' --exclude='CLAUDE.md' \
        --exclude='romsync*' --exclude='.nomedia' "${rsync_skips[@]}" \
        "$local_dir/" "$phone_dir/" | grep -v '/$')"
      if [[ -z "$differing" ]]; then
        echo -e "\033[32mEvery laptop file has the same content on the phone.\033[0m"
      else
        echo -e "\033[31mMissing or different on the phone:\033[0m"
        sed 's/^/  /' <<<"$differing"
        return 1
      fi
      ;;
    "mount")
      echo -e "\033[32mPhone mounted at: $mount_dir\033[0m"
      echo -e "\033[33mRun 'romsync-phone unmount' before unplugging it.\033[0m"
      ;;
    *)
      echo -e "\033[35mROM Sync for Android (romsync-phone)\033[0m"
      echo "Usage: romsync-phone [command]"
      echo ""
      echo -e "\033[33mCommands:\033[0m"
      echo "  sync        - Copy missing ROMs in both directions (default)"
      echo "  status      - Show what differs, without copying"
      echo "  verify      - Compare file contents by checksum (slow)"
      echo "  mount       - Mount the phone and leave it mounted"
      echo "  unmount     - Unmount the phone"
      echo ""
      echo -e "\033[33mPaths:\033[0m"
      echo "  Laptop: $local_dir"
      echo "  Phone:  Internal storage/$phone_subdir"
      echo ""
      echo -e "\033[33mSystems left out (ROMS_PHONE_SKIP):\033[0m"
      echo "  ${skip_systems:-none}"
      ;;
    esac
  }

  case "$command" in
  "sync" | "status" | "verify" | "mount") ;;
  "unmount")
    unmount_phone
    echo -e "\033[32mPhone unmounted.\033[0m"
    return
    ;;
  *)
    execute_commands
    return
    ;;
  esac

  if [[ ! -d "$local_dir" ]]; then
    echo -e "\033[31mError: ROMs directory not found at: $local_dir\033[0m"
    return 1
  fi

  # A dead mount does not count: it is replaced and removed again afterwards
  local was_mounted=false
  is_mounted && ls "$mount_dir" >/dev/null 2>&1 && was_mounted=true

  mount_phone || return 1

  if [[ ! -d "$phone_dir" ]]; then
    echo -e "\033[33mCreating $phone_subdir on the phone (first sync)...\033[0m"
    mkdir -p "$phone_dir" || return 1
  fi

  # Scratch lists go in the per-user runtime directory. On any exit, including
  # Ctrl+C or a lost connection, they are removed and the phone is left as it
  # was found, so nothing is left behind.
  cleanup() {
    [[ -n "$work_dir" ]] && rm -rf "$work_dir"
    if [[ "$command" != "mount" && "$was_mounted" == false ]]; then
      unmount_phone
    fi
  }
  trap cleanup EXIT
  trap 'exit 130' INT TERM HUP

  work_dir="$(mktemp -d "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/romsync-phone-work.XXXXXX")" || return 1

  execute_commands
  local result=$?

  cleanup
  trap - EXIT INT TERM HUP

  return $result
}

# If script is run directly (not sourced), execute the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  romsync_phone "$@"
fi
