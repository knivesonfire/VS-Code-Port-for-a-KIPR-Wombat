#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load config from script dir
if [[ -f "$SCRIPT_DIR/wombat_host.conf" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/wombat_host.conf"
  set +a
fi

HOST="${HOST:-kipr@192.168.125.1}"

# Default password for KIPR Wombat controllers
WOMBAT_PASSWORD="botball"

echo "==> Checking for sshpass..."
if ! command -v sshpass &>/dev/null; then
  echo "ERROR: sshpass not found." >&2
  echo "       You are likely running on the KIPR robot network." >&2
  echo "       Switch to your development network (with internet access)" >&2
  echo "       and re-run this setup script, or install sshpass manually." >&2
  exit 1
else
  echo "    sshpass is already installed."
fi

SSH_KEY="$HOME/.ssh/id_rsa"
echo "==> Checking for SSH key at $SSH_KEY..."
if [[ -f "$SSH_KEY" ]]; then
  echo "    SSH key already exists — skipping generation."
else
  echo "    Generating new RSA-4096 SSH key..."
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N ""
  echo "    SSH key generated."
fi

echo "==> Copying SSH key to $HOST..."
sshpass -p "$WOMBAT_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=accept-new "$HOST"
echo "    SSH key copied."

echo "==> Verifying passwordless SSH connection to $HOST..."
if ssh -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "echo 'Connection successful'" 2>/dev/null; then
  echo "    Passwordless SSH is working!"
else
  echo "ERROR: Passwordless SSH connection failed." >&2
  echo "       Try running this script again or manually run: ssh-copy-id $HOST" >&2
  exit 1
fi

echo ""
echo "==> Setup complete. You can now deploy with: ./deploy.sh"
