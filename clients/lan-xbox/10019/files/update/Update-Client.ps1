<#
.SYNOPSIS
  Bring this client folder up to date, then get out of the way.

.DESCRIPTION
  Run by Play-OpenRSC.cmd before the game starts - which is the only moment
  nothing in the folder is open, and the reason it lives there rather than
  inside the client.

  Two things it must never do, and everything below is one of them:

    * leave the folder half-updated. Every file is downloaded and verified
      BEFORE any file is swapped. A bad hash, a short read or a lost network
      aborts the whole update, deletes staging, and starts the client that was
      already there.

    * stop somebody playing. An unreachable update server, a locked jar, a
      full disk - all of them say what happened and then launch the game.
      The only thing that exits non-zero is being asked to do something
      impossible on the command line.

  It never writes a file it is executing. Update-Client.ps1 and Launch.cmd are
  staged as .new and promoted by the frozen stub at the TOP of the next launch,
  because cmd.exe re-reads a running .cmd by byte offset and PowerShell holds
  its own script open. An updater fix therefore lands one launch late, which is
  the right trade for never corrupting a running script.

.PARAMETER Version
  Install this version instead of the newest. This is the rollback: making the
  folder equal manifest N is the same operation whichever direction N is in.

.PARAMETER Pin
  With -Version, also write it into update.conf so this folder stays there.

.PARAMETER Quiet
  Only speak when something happened.
#>
[CmdletBinding()]
param(
    [int]$Version = 0,
    [switch]$Pin,
    [switch]$Quiet
)

# The progress bar costs roughly 10x on Invoke-WebRequest in PowerShell 5.1,
# and 5.1 does not reliably default to TLS 1.2, which S3 requires.
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol
} catch { }

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot          # the folder, not update\
$UpdateDir = $PSScriptRoot
$Staging = Join-Path $UpdateDir 'staging'
$StateFile = Join-Path $UpdateDir 'state.json'
$LogFile = Join-Path $UpdateDir 'log.txt'
$LockFile = Join-Path $UpdateDir '.lock'
$ConfFile = Join-Path $Root 'update.conf'
$Jar = Join-Path $Root 'Open_RSC_Client.jar'

# Staged rather than swapped, because we are running them.
$SelfFiles = @('update/Update-Client.ps1', 'update/Launch.cmd')

$script:Spoke = $false

function Say($msg) {
    Write-Host "  $msg"
    $script:Spoke = $true
}

function Note($msg) {
    try {
        $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
        Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
        $item = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($item -and $item.Length -gt 200KB) {
            $keep = Get-Content -LiteralPath $LogFile -Tail 400
            Set-Content -LiteralPath $LogFile -Value $keep -Encoding UTF8
        }
    } catch { }
}

# --- the folder's own state -------------------------------------------------

function Read-Conf($path) {
    $out = @{}
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    foreach ($line in Get-Content -LiteralPath $path) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { continue }
        $out[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim()
    }
    return $out
}

function Get-JarVersion($jarPath) {
    # The jar is the truth. state.json can lie - somebody copies a folder and
    # its state travels with it, describing a jar that is no longer there.
    if (-not (Test-Path -LiteralPath $jarPath)) { return 0 }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        try {
            $entry = $zip.GetEntry('orsc/mod/build.properties')
            if (-not $entry) { return 0 }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $zip.Dispose() }
    } catch { return 0 }
    foreach ($line in ($text -split "`n")) {
        if ($line -match '^\s*client_version\s*=\s*(\d+)\s*$') {
            return [int]$Matches[1]
        }
    }
    return 0
}

function Get-Sha256($path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
}

function Read-Line($path) {
    # An EMPTY file is the case this exists for. Get-Content -Raw returns
    # $null for one, and $null.Trim() is a terminating error - so a friend
    # whose Cache\ip.txt had been emptied got "the updater hit a problem and
    # stopped" INSTEAD of the repair that would have fixed it. Reading is
    # allowed to find nothing. UPD-085.
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    $raw = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
    if (-not $raw) { return '' }
    return $raw.Trim()
}

function Clear-ReadOnly($path) {
    # uid.dat is created read-only (mudclient.java:14251) and Windows will not
    # unlink a read-only file. Nothing on the never-touch list should reach
    # here, but a general defence costs one line and the failure it prevents is
    # an abort halfway through a swap.
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if ($item.IsReadOnly) { $item.IsReadOnly = $false }
    }
}

function Test-JarWritable($jarPath) {
    # A second client running from this folder holds the jar open, and Windows
    # will not let it be replaced. Asked by trying, not by reading
    # discord_inuse.txt - a crash leaves that file saying "1" forever.
    if (-not (Test-Path -LiteralPath $jarPath)) { return $true }
    try {
        $fs = [System.IO.File]::Open($jarPath, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        return $true
    } catch { return $false }
}

# --- fetching ---------------------------------------------------------------

function Get-Json($url, $timeout) {
    $raw = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeout
    return ($raw.Content | ConvertFrom-Json)
}

function Save-File($url, $dest, $expectSize, $expectHash) {
    $dir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 300 -OutFile $dest
    $size = (Get-Item -LiteralPath $dest).Length
    if ($expectSize -and $size -ne $expectSize) {
        throw "short read: $size bytes, the manifest says $expectSize"
    }
    $hash = Get-Sha256 $dest
    if ($hash -ne $expectHash.ToLower()) {
        throw "hash mismatch: $($hash.Substring(0,16)) vs $($expectHash.Substring(0,16))"
    }
}

# --- applying ---------------------------------------------------------------

function Move-Into($from, $to) {
    $dir = Split-Path -Parent $to
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Clear-ReadOnly $to
    if (Test-Path -LiteralPath $to) {
        # Atomic on NTFS, and it hands back the previous content for free.
        $backup = "$to.bak"
        Clear-ReadOnly $backup
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
        [System.IO.File]::Replace($from, $to, $backup, $true)
        if ((Split-Path -Leaf $to) -ne 'Open_RSC_Client.jar') {
            Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        }
    } else {
        Move-Item -LiteralPath $from -Destination $to -Force
    }
}

function Merge-PadConf($padPath, $pairs) {
    # A KEY MERGE, never a file replace. pad.conf is half the player's:
    # PadBindings.saveSetting rewrites it on every rebind, so replacing it
    # would wipe somebody's bindings every time they played. Only the keys the
    # manifest names are touched, and only when they actually differ.
    if (-not (Test-Path -LiteralPath $padPath)) { return @() }
    $lines = [System.IO.File]::ReadAllLines($padPath)
    $changed = @()
    foreach ($key in $pairs.PSObject.Properties.Name) {
        $want = [string]$pairs.$key
        $pattern = '^(\s*)' + [regex]::Escape($key) + '(\s*=\s*)(\S+)'
        $hit = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].TrimStart().StartsWith('#')) { continue }
            $m = [regex]::Match($lines[$i], $pattern)
            if ($m.Success) {
                $hit = $true
                if ($m.Groups[3].Value -ne $want) {
                    $lines[$i] = $m.Groups[1].Value + $key + $m.Groups[2].Value + $want
                    $changed += "$key $($m.Groups[3].Value) -> $want"
                }
                break
            }
        }
        if (-not $hit) {
            $lines += ("{0} = {1}" -f $key, $want)
            $changed += "$key set to $want"
        }
    }
    if ($changed.Count) {
        Clear-ReadOnly $padPath
        [System.IO.File]::WriteAllLines($padPath, $lines)
    }
    return $changed
}

function Remove-Listed($names) {
    # Constrained hard on purpose: this list arrives over the network. Relative
    # paths only, no traversal, must resolve inside the folder, files only,
    # never a directory and never recursive.
    $gone = @()
    foreach ($name in $names) {
        if (-not $name) { continue }
        if ($name -match '^[A-Za-z]:' -or $name.StartsWith('/') -or $name.StartsWith('\')) { continue }
        $parts = ($name -replace '\\', '/') -split '/'
        if ($parts -contains '..' -or $parts -contains '.') { continue }
        $target = Join-Path $Root ($parts -join [System.IO.Path]::DirectorySeparatorChar)
        $full = [System.IO.Path]::GetFullPath($target)
        $rootFull = [System.IO.Path]::GetFullPath($Root)
        if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        Clear-ReadOnly $full
        Remove-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
        $gone += ($parts -join '/')
    }
    return $gone
}

# --- main -------------------------------------------------------------------

$conf = Read-Conf $ConfFile
if ($null -eq $conf) {
    # No update.conf means this folder does not follow a channel, and that is
    # the whole opt-in. client\ (the dev copy) and lan-client.nocontroller\
    # stay inert with no special case anywhere.
    exit 0
}

$lock = $null
try {
    $lock = [System.IO.File]::Open($LockFile, 'OpenOrCreate', 'ReadWrite', 'None')
} catch {
    exit 0    # another launcher is already doing this
}

$installed = Get-JarVersion $Jar

try {
    $channel = $conf['channel']
    $base = $conf['base']
    if (-not $channel -or -not $base) {
        Say "update.conf is missing a channel or a base URL - not updating."
        exit 0
    }
    if (-not $base.EndsWith('/')) { $base += '/' }
    $chanBase = "$base$channel/"

    if ($Version -le 0 -and $conf.ContainsKey('pin') -and $conf['pin']) {
        $Version = [int]$conf['pin']
    }

    # What this folder believed it had after its last successful update. Only
    # ever used to decide whether to LOOK; the jar and the files themselves are
    # what any decision is actually made on.
    $knownContent = ''
    if (Test-Path -LiteralPath $StateFile) {
        try {
            $knownContent = [string]((Get-Content -LiteralPath $StateFile -Raw |
                                      ConvertFrom-Json).content)
        } catch { }
    }

    # --- what is published ---------------------------------------------------
    $want = $Version
    $label = ''
    $wantContent = ''
    try {
        if ($want -le 0) {
            $pointer = Get-Json ($chanBase + 'latest.json') 8
            $want = [int]$pointer.client_version
            $label = [string]$pointer.label
            $wantContent = [string]$pointer.content
        }
    } catch {
        # Availability beats freshness. Name the version they have so the
        # message is useful next to a server saying the client is out of date.
        Say "could not reach the update server - starting the client you have ($installed)."
        Note "offline: $($_.Exception.Message)"
        exit 0
    }

    if ($want -eq $installed -and $wantContent -and $wantContent -eq $knownContent) {
        # The fast path: one ~200 byte request and no hashing at all. Both
        # halves have to match. The version alone is not enough - it comes from
        # the jar, so a publish that changed only Launch.cmd or the updater
        # would leave it identical and the fix would never reach anybody.
        if (-not $Quiet) { Say "client $installed, up to date." }
        Note "up to date at $installed"
        exit 0
    }

    if ($want -lt $installed -and $Version -le 0) {
        # An S3 restore of an old object, or a half-finished publish, would
        # otherwise silently downgrade a folder into a version the server
        # refuses. Going backwards has to be asked for.
        Say "the update server offers $want and this folder is $installed - not going backwards."
        Say "  (Update-Client.ps1 -Version $want if that is really what you want.)"
        Note "refused downgrade $installed -> $want"
        exit 0
    }

    try {
        $manifest = Get-Json ($chanBase + "$want/manifest.json") 20
    } catch {
        Say "could not read the manifest for $want - starting the client you have ($installed)."
        Note "manifest fetch failed: $($_.Exception.Message)"
        exit 0
    }
    if ([int]$manifest.client_version -ne $want -or $manifest.channel -ne $channel) {
        Say "the published manifest does not match its pointer - not updating."
        Note "manifest/pointer mismatch"
        exit 0
    }
    if (-not $label) { $label = [string]$manifest.label }

    # --- what has to change --------------------------------------------------
    $needed = @()
    foreach ($entry in $manifest.files) {
        $local = Join-Path $Root ($entry.path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $local)) { $needed += $entry; continue }
        if ((Get-Item -LiteralPath $local).Length -ne [long]$entry.size) { $needed += $entry; continue }
        if ((Get-Sha256 $local) -ne ([string]$entry.sha256).ToLower()) { $needed += $entry }
    }

    if (-not $needed.Count) {
        if (-not $Quiet) { Say "client $installed, up to date." }
    } else {
        $bytes = ($needed | Measure-Object -Property size -Sum).Sum
        if ($want -eq $installed) {
            # Same client, changed payload - a launcher or updater fix.
            Say ("refreshing {0}{1}" -f $installed,
                 $(if ($label) { " - $label" } else { '' }))
        } else {
            Say ("updating {0} -> {1}{2}" -f $installed, $want,
                 $(if ($label) { " - $label" } else { '' }))
        }

        # --- preflight, before a single byte is downloaded -------------------
        if (-not (Test-JarWritable $Jar)) {
            Say "another client is running from this folder - close it and run this again."
            Say "nothing was changed."
            Note "aborted: jar is locked"
            exit 0
        }
        try {
            $drive = Get-PSDrive -Name ((Get-Item -LiteralPath $Root).PSDrive.Name)
            if ($drive.Free -and $drive.Free -lt ($bytes * 3)) {
                Say "not enough free space for $([math]::Round($bytes/1MB,1)) MB - nothing was changed."
                Note "aborted: low disk"
                exit 0
            }
        } catch { }

        # --- download and verify EVERYTHING, then swap ------------------------
        if (Test-Path -LiteralPath $Staging) {
            Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $Staging -Force | Out-Null

        $started = Get-Date
        $ok = $true
        foreach ($entry in $needed) {
            $url = $chanBase + "$want/files/" + $entry.path
            $dest = Join-Path $Staging ($entry.path -replace '/', '\')
            $done = $false
            foreach ($attempt in 1, 2) {
                try {
                    Save-File $url $dest ([long]$entry.size) ([string]$entry.sha256)
                    $done = $true
                    break
                } catch {
                    $why = $_.Exception.Message
                    if ($attempt -eq 2) {
                        Say "failed on $($entry.path): $why"
                        Note "download failed $($entry.path): $why"
                    }
                }
            }
            if (-not $done) { $ok = $false; break }
        }

        if (-not $ok) {
            Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction SilentlyContinue
            Say "the update was abandoned and nothing in this folder was touched."
            Say "starting the client you have ($installed)."
            Note "aborted: a file would not verify"
            exit 0
        }

        # Everything is downloaded and every hash is right. Only now does
        # anything in the folder move. The jar goes last, and the two files we
        # are running are staged as .new for the stub to promote next launch.
        $swapped = 0
        $deferred = @()
        foreach ($entry in $needed) {
            if ($entry.path -eq 'Open_RSC_Client.jar') { continue }
            $from = Join-Path $Staging ($entry.path -replace '/', '\')
            if ($SelfFiles -contains $entry.path) {
                $to = (Join-Path $Root ($entry.path -replace '/', '\')) + '.new'
                Clear-ReadOnly $to
                Move-Item -LiteralPath $from -Destination $to -Force
                $deferred += $entry.path
            } else {
                Move-Into $from (Join-Path $Root ($entry.path -replace '/', '\'))
            }
            $swapped++
        }
        $jarEntry = $needed | Where-Object { $_.path -eq 'Open_RSC_Client.jar' }
        if ($jarEntry) {
            Move-Into (Join-Path $Staging 'Open_RSC_Client.jar') $Jar
            $swapped++
        }
        Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction SilentlyContinue

        $secs = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
        Say ("{0} file(s), {1} MB, {2}s" -f $swapped, [math]::Round($bytes/1MB, 1), $secs)
        if ($deferred.Count) {
            Say "the launcher itself updates on the next run."
        }
    }

    # --- the parts that are not files ---------------------------------------
    if ($manifest.pad_conf) {
        $changed = Merge-PadConf (Join-Path $Root 'pad.conf') $manifest.pad_conf
        foreach ($c in $changed) { Say "pad.conf: $c" }
    }
    if ($manifest.delete) {
        $gone = Remove-Listed $manifest.delete
        foreach ($g in $gone) { Say "removed $g" }
    }

    $state = $null
    if (Test-Path -LiteralPath $StateFile) {
        try { $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json } catch { }
    }
    if ($manifest.server -and $manifest.server.host) {
        # The ONLY per-machine files this ever writes, and there are two rules
        # for them because there are two kinds of folder.
        #
        # A LAN folder can legitimately be pointed somewhere else, so its
        # address is followed only while the player has not chosen for
        # themselves: Set-Server.cmd always wins.
        #
        # A PINNED channel has one world and no Set-Server.cmd - so the address
        # is not a preference to be respected, it is part of the payload, and
        # an empty or edited one is damage to be repaired. That is the whole
        # cure for "Cache\ip.txt is missing or empty", which cost a friend an
        # evening. UPD-084.
        $ipFile = Join-Path $Root 'Cache\ip.txt'
        $portFile = Join-Path $Root 'Cache\port.txt'
        $current = Read-Line $ipFile
        $managed = if ($state) { [string]$state.managed_host } else { '' }
        $pinned = [bool]$manifest.server.pinned

        if ($pinned) {
            if ($current -ne [string]$manifest.server.host) {
                Clear-ReadOnly $ipFile
                [System.IO.File]::WriteAllText(
                    $ipFile, [string]$manifest.server.host + "`n")
                Say $(if ($current) {
                        "server address restored to $($manifest.server.host)"
                      } else {
                        "server address set to $($manifest.server.host)"
                      })
            }
            if ($manifest.server.port) {
                if ((Read-Line $portFile) -ne [string]$manifest.server.port) {
                    Clear-ReadOnly $portFile
                    [System.IO.File]::WriteAllText(
                        $portFile, [string]$manifest.server.port + "`n")
                }
            }
        }
        elseif ($current -and $managed -and $current -eq $managed -and $current -ne $manifest.server.host) {
            Clear-ReadOnly $ipFile
            [System.IO.File]::WriteAllText($ipFile, [string]$manifest.server.host + "`n")
            Say "server address moved to $($manifest.server.host)"
        }
    }

    # state.json LAST. Everything above re-derives truth from the folder's own
    # hashes, so a machine that dies mid-update simply redoes the work next
    # launch rather than believing a lie.
    $newState = [ordered]@{
        client_version = $want
        content        = [string]$manifest.content
        channel        = $channel
        label          = $label
        updated        = (Get-Date).ToString('s')
        managed_host   = $(if ($manifest.server) { [string]$manifest.server.host } else { '' })
    }
    [System.IO.File]::WriteAllText(
        $StateFile, (ConvertTo-Json $newState -Depth 6), (New-Object Text.UTF8Encoding $false))

    if ($Pin -and $Version -gt 0) {
        Add-Content -LiteralPath $ConfFile -Value "pin = $Version"
        Say "pinned to $Version"
    }
    Note "updated $installed -> $want"

} catch {
    # Anything unforeseen: say it, log it, and still start the game.
    Say "the updater hit a problem and stopped: $($_.Exception.Message)"
    Say "starting the client you have."
    Note "unexpected: $($_.Exception)"
    try {
        if (Test-Path -LiteralPath $Staging) {
            Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch { }
} finally {
    if ($lock) { $lock.Close() }
}

exit 0
