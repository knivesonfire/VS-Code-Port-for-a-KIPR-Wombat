Param(
    [string]$ConfigFile = "$PSScriptRoot/wombat_host.conf"
)

$ErrorActionPreference = "Stop"

# Default values
$HOST = "kipr@192.168.125.1"
$REMOTE_DIR = "/home/kipr/dev/botball-vs"
$KISS_PROJECT = ""

if (Test-Path $ConfigFile) {
    Get-Content $ConfigFile | ForEach-Object {
        if ($_ -match "^HOST=(.+)$") { $HOST = $Matches[1] }
        elseif ($_ -match "^REMOTE_DIR=(.+)$") { $REMOTE_DIR = $Matches[1] }
        elseif ($_ -match "^KISS_PROJECT=(.+)$") { $KISS_PROJECT = $Matches[1] }
    }
}

function New-FlatStagingDir {
    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("botball-deploy-" + [System.Guid]::NewGuid().ToString("N"))
    $stagingInclude = Join-Path $stagingRoot "include"
    $stagingSrc = Join-Path $stagingRoot "src"

    New-Item -ItemType Directory -Path $stagingInclude -Force | Out-Null
    New-Item -ItemType Directory -Path $stagingSrc -Force | Out-Null

    $headerNames = @{}
    @("include", "src") | ForEach-Object {
        if (Test-Path $_) {
            Get-ChildItem -Path $_ -Recurse -File -Filter *.h | ForEach-Object {
                $name = $_.Name
                if ($headerNames.ContainsKey($name)) {
                    throw "Duplicate header filename detected during flattening: $name`nConflicts: $($headerNames[$name]) and $($_.FullName)"
                }
                $headerNames[$name] = $_.FullName
                Copy-Item $_.FullName (Join-Path $stagingInclude $name)
            }
        }
    }

    $sourceNames = @{}
    if (Test-Path "src") {
        Get-ChildItem -Path "src" -Recurse -File | Where-Object {
            $_.Extension.ToLowerInvariant() -in @('.c', '.cpp')
        } | ForEach-Object {
            $name = $_.Name
            if ($sourceNames.ContainsKey($name)) {
                throw "Duplicate source filename detected during flattening: $name`nConflicts: $($sourceNames[$name]) and $($_.FullName)"
            }
            $sourceNames[$name] = $_.FullName
            Copy-Item $_.FullName (Join-Path $stagingSrc $name)
        }
    }

    return @{
        Root = $stagingRoot
        Include = $stagingInclude
        Src = $stagingSrc
    }
}

Write-Host "Deploying to $HOST"

$staging = New-FlatStagingDir

try {
    if ($KISS_PROJECT -ne "") {
        if ($KISS_PROJECT.StartsWith('/')) {
            $REMOTE_PROJECT_DIR = $KISS_PROJECT
            $PROJECT_NAME = [System.IO.Path]::GetFileName($KISS_PROJECT)
        }
        else {
            $REMOTE_PROJECT_DIR = "/home/kipr/KISS/projects/$KISS_PROJECT"
            $PROJECT_NAME = $KISS_PROJECT
        }

        Write-Host "Deploying directly into KISS project: $REMOTE_PROJECT_DIR"

        ssh $HOST "mkdir -p '$REMOTE_PROJECT_DIR/bin' '$REMOTE_PROJECT_DIR/src' '$REMOTE_PROJECT_DIR/include'"

        scp -r "$($staging.Src)/." $HOST:"$REMOTE_PROJECT_DIR/src/"
        scp -r "$($staging.Include)/." $HOST:"$REMOTE_PROJECT_DIR/include/"
        scp Makefile $HOST:"$REMOTE_PROJECT_DIR/"

        $manifestCmd = "if [ ! -f '$REMOTE_PROJECT_DIR/project.manifest' ]; then echo '{\"language\":\"C\",\"user\":\"Default User\"}' > '$REMOTE_PROJECT_DIR/project.manifest'; fi"
        ssh $HOST $manifestCmd

        ssh $HOST "cd '$REMOTE_PROJECT_DIR' && make KISS_BIN='bin/$PROJECT_NAME'"
        ssh $HOST "cd '$REMOTE_PROJECT_DIR' && ./robot"
    }
    else {
        Write-Host "Deploying into remote dir: $REMOTE_DIR"
        ssh $HOST "mkdir -p '$REMOTE_DIR/include' '$REMOTE_DIR/src'"

        scp -r "$($staging.Src)/." $HOST:"$REMOTE_DIR/src/"
        scp -r "$($staging.Include)/." $HOST:"$REMOTE_DIR/include/"
        scp Makefile $HOST:"$REMOTE_DIR/"

        ssh $HOST "cd '$REMOTE_DIR' && make"
        ssh $HOST "cd '$REMOTE_DIR' && ./robot"
    }

    Write-Host "Deploy complete."
}
finally {
    if ($staging -and (Test-Path $staging.Root)) {
        Remove-Item -Recurse -Force $staging.Root
    }
}
