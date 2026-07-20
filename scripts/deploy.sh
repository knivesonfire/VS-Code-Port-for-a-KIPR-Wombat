#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load config from script dir
if [[ -f "$SCRIPT_DIR/wombat_host.conf" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/wombat_host.conf"
  set +a
fi

# Ensure HOST default
HOST="${HOST:-kipr@192.168.125.1}"

SSH_CONTROL_PATH="/tmp/botball-ssh-${USER}-$$"
SSH_OPTS=(
  -o ControlMaster=auto
  -o ControlPersist=10m
  -o ControlPath="$SSH_CONTROL_PATH"
  -o ServerAliveInterval=30
)

cleanup() {
  ssh "${SSH_OPTS[@]}" -O exit "$HOST" >/dev/null 2>&1 || true
  rm -f "$SSH_CONTROL_PATH" >/dev/null 2>&1 || true
  if [[ -n "${STAGING_DIR:-}" ]]; then
    rm -rf "$STAGING_DIR" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

# Determine the remote build directory.
if [[ -n "${KISS_PROJECT:-}" ]]; then
  if [[ "${KISS_PROJECT}" == /* ]]; then
    REMOTE_DIR="$KISS_PROJECT"
    PROJECT_NAME="$(basename "$KISS_PROJECT")"
  else
    REMOTE_DIR="/home/kipr/KISS/projects/$KISS_PROJECT"
    PROJECT_NAME="$KISS_PROJECT"
  fi
  KISS_BIN="bin/$PROJECT_NAME"
else
  REMOTE_DIR="${REMOTE_DIR:-/home/kipr/dev/botball-vs}"
  KISS_BIN=""
fi

printf -v RSYNC_RSH 'ssh -o ControlMaster=auto -o ControlPersist=10m -o ControlPath=%q -o ServerAliveInterval=30' "$SSH_CONTROL_PATH"

# Escape spaces in the remote path so rsync's remote shell doesn't word-split.
RSYNC_REMOTE_DIR="${REMOTE_DIR// /\\ }"

echo "Deploying to $HOST:$REMOTE_DIR"

# Open one shared SSH session up front so the password is only requested once.
ssh "${SSH_OPTS[@]}" "$HOST" "true"

# Build a flattened staging area:
# - all .h files -> include/
# - all .c/.cpp files -> src/
STAGING_DIR="$(mktemp -d)"
STAGING_INCLUDE="$STAGING_DIR/include"
STAGING_SRC="$STAGING_DIR/src"
mkdir -p "$STAGING_INCLUDE" "$STAGING_SRC"

HEADER_MAP="$STAGING_DIR/.header_map"
SOURCE_MAP="$STAGING_DIR/.source_map"
: >"$HEADER_MAP"
: >"$SOURCE_MAP"

while IFS= read -r -d '' file; do
  base="$(basename "$file")"
  existing="$(awk -F '\t' -v b="$base" '$1==b { print $2; exit }' "$HEADER_MAP")"
  if [[ -n "$existing" ]]; then
    echo "ERROR: Duplicate header filename detected during flattening: $base" >&2
    echo "       Conflicts: $existing and $file" >&2
    exit 1
  fi
  printf '%s\t%s\n' "$base" "$file" >>"$HEADER_MAP"
  cp "$file" "$STAGING_INCLUDE/$base"
done < <(
  {
    find "$REPO_ROOT/include" -type f -name '*.h' -print0 2>/dev/null
    find "$REPO_ROOT/src" -type f -name '*.h' -print0 2>/dev/null
  }
)

while IFS= read -r -d '' file; do
  base="$(basename "$file")"
  existing="$(awk -F '\t' -v b="$base" '$1==b { print $2; exit }' "$SOURCE_MAP")"
  if [[ -n "$existing" ]]; then
    echo "ERROR: Duplicate source filename detected during flattening: $base" >&2
    echo "       Conflicts: $existing and $file" >&2
    exit 1
  fi
  printf '%s\t%s\n' "$base" "$file" >>"$SOURCE_MAP"
  cp "$file" "$STAGING_SRC/$base"
done < <(
  {
    find "$REPO_ROOT/src" -type f -name '*.c' -print0 2>/dev/null
    find "$REPO_ROOT/src" -type f -name '*.cpp' -print0 2>/dev/null
  }
)

# Ensure remote directory exists & set up KISS project metadata if needed.
if [[ -n "$KISS_PROJECT" ]]; then
  ssh "${SSH_OPTS[@]}" "$HOST" "
    sudo chown -R kipr:kipr '$REMOTE_DIR' || true
    mkdir -p '$REMOTE_DIR/bin' '$REMOTE_DIR/src' '$REMOTE_DIR/include'
    if [ ! -f '$REMOTE_DIR/project.manifest' ]; then
      echo '{\"language\":\"C\",\"user\":\"Default User\"}' > '$REMOTE_DIR/project.manifest'
    fi
  "
else
  ssh "${SSH_OPTS[@]}" "$HOST" "sudo chown -R kipr:kipr '$REMOTE_DIR' || true
    mkdir -p '$REMOTE_DIR'"
fi

# Sync flattened source, headers, and Makefile to the Wombat
rsync -av --delete \
  -e "$RSYNC_RSH" \
  "$STAGING_SRC/" \
  "$HOST:$RSYNC_REMOTE_DIR/src/"

rsync -av --delete \
  -e "$RSYNC_RSH" \
  "$STAGING_INCLUDE/" \
  "$HOST:$RSYNC_REMOTE_DIR/include/"

rsync -av \
  -e "$RSYNC_RSH" \
  "$REPO_ROOT/Makefile" \
  "$HOST:$RSYNC_REMOTE_DIR/"

# Build on the Wombat (Disabled so you can just compile via KIPR IDE)
# if [[ -n "$KISS_BIN" ]]; then
#   ssh "${SSH_OPTS[@]}" "$HOST" "cd '$REMOTE_DIR' && make KISS_BIN='$KISS_BIN'"
# else
#   ssh "${SSH_OPTS[@]}" "$HOST" "cd '$REMOTE_DIR' && make"
# fi

# Run immediately from SSH (good while testing)
# ssh "${SSH_OPTS[@]}" "$HOST" "cd '$REMOTE_DIR' && ./robot" || {
#   echo "Robot program exited with non-zero status."
# }

echo "Deploy complete."
