Param(
    [string]$ConfigFile = "$PSScriptRoot/wombat_host.conf"
)

# Default values
$HOST = "kipr@192.168.125.1"
$KISS_PROJECT = ""

if (Test-Path $ConfigFile) {
    Get-Content $ConfigFile | ForEach-Object {
        if ($_ -match "^HOST=(.+)$") { $HOST = $Matches[1] }
        elseif ($_ -match "^KISS_PROJECT=(.+)$") { $KISS_PROJECT = $Matches[1] }
    }
}

Write-Host "Using host: $HOST"

$pub = "$env:USERPROFILE\.ssh\id_rsa.pub"

if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    Write-Host "ssh-keygen not found. Please install OpenSSH client (Windows 10+ has it optional)." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $pub)) {
    Write-Host "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa" -N "" | Out-Null
    Write-Host "SSH key generated at $pub"
} else {
    Write-Host "SSH public key already exists: $pub"
}

if (Get-Command ssh-copy-id -ErrorAction SilentlyContinue) {
    Write-Host "Using ssh-copy-id to install key on remote host..."
    & ssh-copy-id $HOST
    Write-Host "Done."
    exit 0
}

if (-not (Test-Path $pub)) {
    Write-Error "Public key not found at $pub"
    exit 1
}

Write-Host "No ssh-copy-id found; using scp+ssh fallback. You will be prompted for the Wombat password (default: kipr)."

$remoteTemp = "/tmp/$(Get-Random)-wombat-key.pub"
scp "$pub" "$HOST:$remoteTemp"

$appendCmd = "mkdir -p ~/.ssh && cat $remoteTemp >> ~/.ssh/authorized_keys && rm -f $remoteTemp && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
ssh $HOST $appendCmd

Write-Host "Public key installed. Verifying passwordless SSH..."

if (ssh -o BatchMode=yes -o ConnectTimeout=10 $HOST "echo connected" 2>$null) {
    Write-Host "Passwordless SSH worked."
} else {
    Write-Error "Passwordless SSH failed. Please run the script again or use ssh-copy-id manually."
    exit 1
}
