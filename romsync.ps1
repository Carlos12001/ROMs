function romsync {
    param (
        [string]$command = "sync"
    )

    # ROMs directory on this PC (override with $env:ROMS_DIR)
    $localDir = if ($env:ROMS_DIR) { $env:ROMS_DIR } else { Join-Path $HOME "ROMs" }

    # External drive, found by its label (override with $env:ROMS_DRIVE_LABEL / $env:ROMS_DRIVE_SUBDIR)
    $driveLabel = if ($env:ROMS_DRIVE_LABEL) { $env:ROMS_DRIVE_LABEL } else { "CarlosHD" }
    $driveSubdir = if ($env:ROMS_DRIVE_SUBDIR) { $env:ROMS_DRIVE_SUBDIR } else { "backup\ROMs" }

    # Never synced: each side keeps its own git clone, and the rest is OS/RetroArch junk
    $excludeDirs = @(".git", "builtin", '$RECYCLE.BIN', "System Volume Information")
    $excludeFiles = @("Thumbs.db", "desktop.ini", ".DS_Store")

    function Show-Usage {
        Write-Host "ROM Sync (romsync)" -ForegroundColor Magenta
        Write-Host "Usage: romsync [command]"
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Yellow
        Write-Host "  sync        - Copy new/updated ROMs in both directions (default)"
        Write-Host "  status      - Show what differs, without copying"
        Write-Host "  verify      - Compare file contents by checksum (slow)"
        Write-Host "  open        - Open the drive's ROMs directory in Explorer"
        Write-Host ""
        Write-Host "Paths:" -ForegroundColor Yellow
        Write-Host "  PC:    $localDir"
        Write-Host "  Drive: ${driveLabel}:\$driveSubdir"
    }

    # /XO keeps the newest copy of a file; /FFT tolerates exFAT's coarse timestamps
    function Invoke-Copy {
        param ([string]$source, [string]$destination, [switch]$listOnly)

        $options = @($source, $destination, "/E", "/XO", "/FFT", "/COPY:DAT", "/DCOPY:T",
            "/R:1", "/W:1", "/NP", "/NJH", "/NDL", "/XD") + $excludeDirs + @("/XF") + $excludeFiles
        if ($listOnly) {
            $options += @("/L", "/NJS")
        }

        robocopy @options | Where-Object { $_.Trim() -ne "" } | ForEach-Object { Write-Host $_ }

        # Robocopy exit codes: bit 0 = files copied (or pending with /L), 8 or more = failure
        return $LASTEXITCODE
    }

    function Get-RomFiles {
        param ([string]$root)

        $rootFull = (Resolve-Path $root).Path.TrimEnd("\")
        Get-ChildItem -Path $rootFull -Recurse -File -Force | Where-Object {
            $relative = $_.FullName.Substring($rootFull.Length + 1)
            $dirParts = @($relative.Split("\") | Select-Object -SkipLast 1)
            $inExcludedDir = @($dirParts | Where-Object { $excludeDirs -contains $_ }).Count -gt 0
            (-not $inExcludedDir) -and ($excludeFiles -notcontains $_.Name)
        } | ForEach-Object {
            [PSCustomObject]@{
                Relative = $_.FullName.Substring($rootFull.Length + 1)
                FullName = $_.FullName
            }
        }
    }

    if ($command -in @("help", "-h", "--help")) {
        Show-Usage
        return
    }

    if (-not (Test-Path $localDir)) {
        Write-Host "Error: ROMs directory not found at: $localDir" -ForegroundColor Red
        Write-Host "Set `$env:ROMS_DIR to the folder where you keep your ROMs." -ForegroundColor Yellow
        return
    }

    $volume = Get-Volume -FileSystemLabel $driveLabel -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $volume -or -not $volume.DriveLetter) {
        Write-Host "Error: drive '$driveLabel' not found. Plug it in and try again." -ForegroundColor Red
        return
    }
    $driveDir = Join-Path "$($volume.DriveLetter):\" $driveSubdir

    if (-not (Test-Path $driveDir)) {
        Write-Host "Creating $driveDir (first sync)..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $driveDir -Force | Out-Null
    }

    switch ($command) {
        "sync" {
            Write-Host "Copying new/updated ROMs: PC -> $driveLabel..." -ForegroundColor Green
            $toDrive = Invoke-Copy $localDir $driveDir
            Write-Host "Copying new/updated ROMs: $driveLabel -> PC..." -ForegroundColor Green
            $toLocal = Invoke-Copy $driveDir $localDir

            if ($toDrive -ge 8 -or $toLocal -ge 8) {
                Write-Host "Robocopy reported errors (see the output above)." -ForegroundColor Red
                return
            }

            Write-Host "Checking that both sides match..." -ForegroundColor Cyan
            $pendingDrive = Invoke-Copy $localDir $driveDir -listOnly
            $pendingLocal = Invoke-Copy $driveDir $localDir -listOnly
            if (($pendingDrive -band 1) -or ($pendingLocal -band 1)) {
                Write-Host "Both sides still differ (see the list above)." -ForegroundColor Red
            } else {
                Write-Host "PC and $driveLabel are identical." -ForegroundColor Green
            }
        }
        "status" {
            Write-Host "Comparing by size and date (nothing is copied)..." -ForegroundColor Yellow
            Write-Host "PC -> ${driveLabel}:" -ForegroundColor Yellow
            $pendingDrive = Invoke-Copy $localDir $driveDir -listOnly
            Write-Host "$driveLabel -> PC:" -ForegroundColor Yellow
            $pendingLocal = Invoke-Copy $driveDir $localDir -listOnly
            if (($pendingDrive -band 1) -or ($pendingLocal -band 1)) {
                Write-Host "Run 'romsync sync' to make both sides equal." -ForegroundColor Yellow
            } else {
                Write-Host "PC and $driveLabel are identical." -ForegroundColor Green
            }
        }
        "verify" {
            Write-Host "Comparing file contents by checksum (slow, nothing is copied)..." -ForegroundColor Yellow
            $localFiles = @{}
            Get-RomFiles $localDir | ForEach-Object { $localFiles[$_.Relative] = $_.FullName }
            $driveFiles = @{}
            Get-RomFiles $driveDir | ForEach-Object { $driveFiles[$_.Relative] = $_.FullName }

            $problems = 0
            foreach ($relative in ($localFiles.Keys | Sort-Object)) {
                if (-not $driveFiles.ContainsKey($relative)) {
                    Write-Host "  Missing on ${driveLabel}: $relative" -ForegroundColor Red
                    $problems++
                    continue
                }
                $localHash = (Get-FileHash -LiteralPath $localFiles[$relative] -Algorithm SHA256).Hash
                $driveHash = (Get-FileHash -LiteralPath $driveFiles[$relative] -Algorithm SHA256).Hash
                if ($localHash -ne $driveHash) {
                    Write-Host "  Different content: $relative" -ForegroundColor Red
                    $problems++
                }
            }
            foreach ($relative in ($driveFiles.Keys | Sort-Object)) {
                if (-not $localFiles.ContainsKey($relative)) {
                    Write-Host "  Missing on PC: $relative" -ForegroundColor Red
                    $problems++
                }
            }

            if ($problems -eq 0) {
                Write-Host "Every file has the same content on both sides." -ForegroundColor Green
            } else {
                Write-Host "$problems files are missing or have different content." -ForegroundColor Red
            }
        }
        "open" {
            Write-Host "Opening ROMs directory on $driveLabel..." -ForegroundColor Cyan
            explorer $driveDir
        }
        default {
            Show-Usage
        }
    }
}

# If the file is run directly (not dot-sourced or pasted into $PROFILE), execute the function
if ($MyInvocation.InvocationName -ne "." -and $MyInvocation.MyCommand.Path) {
    romsync @args
}
