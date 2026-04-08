#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_DIR="${REPO_HELPER_CONFIG_DIR:-$SCRIPT_DIR/.config}"

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME --project=<name> [--backup-dir=<path>] [--project-root=<path>] [--config-dir=<path>]
  $SCRIPT_NAME --project-root=<project_root> --backup-dir=<backup_dir>

Config:
  By default, project presets are loaded from:
    $DEFAULT_CONFIG_DIR/<project>.conf

Options:
  --project=<name>         Load preset values from <config-dir>/<name>.conf
  --project-root=<path>    Path to the Git project root
  --backup-dir=<path>      Path to the backup directory
  --config-dir=<path>      Override config directory
  -h, --help               Show this help

Precedence:
  explicit CLI args > project config file > error
EOF
  exit 1
}

PROJECT_NAME=""
PROJECT_ROOT=""
BACKUP_DIR=""
CONFIG_DIR="$DEFAULT_CONFIG_DIR"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project=*)
      PROJECT_NAME="${1#*=}"
      shift
      ;;
    --project)
      [[ $# -ge 2 ]] || usage
      PROJECT_NAME="$2"
      shift 2
      ;;
    --project-root=*)
      PROJECT_ROOT="${1#*=}"
      shift
      ;;
    --project-root)
      [[ $# -ge 2 ]] || usage
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --backup-dir=*)
      BACKUP_DIR="${1#*=}"
      shift
      ;;
    --backup-dir)
      [[ $# -ge 2 ]] || usage
      BACKUP_DIR="$2"
      shift 2
      ;;
    --config-dir=*)
      CONFIG_DIR="${1#*=}"
      shift
      ;;
    --config-dir)
      [[ $# -ge 2 ]] || usage
      CONFIG_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      ;;
  esac
done

CONFIG_PROJECT_ROOT=""
CONFIG_BACKUP_DIR=""

load_project_config() {
  local project="$1"
  local config_file="$CONFIG_DIR/${project}.conf"

  if [[ ! -f "$config_file" ]]; then
    echo "Error: project config not found: $config_file" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$config_file"

  CONFIG_PROJECT_ROOT="${project_root:-}"
  CONFIG_BACKUP_DIR="${backup_dir:-}"
}

if [[ -n "$PROJECT_NAME" ]]; then
  load_project_config "$PROJECT_NAME"
fi

PROJECT_ROOT="${PROJECT_ROOT:-$CONFIG_PROJECT_ROOT}"
BACKUP_DIR="${BACKUP_DIR:-$CONFIG_BACKUP_DIR}"

[[ -n "$PROJECT_ROOT" && -n "$BACKUP_DIR" ]] || usage

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "Error: project root does not exist: $PROJECT_ROOT" >&2
  exit 1
fi

if ! git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: '$PROJECT_ROOT' is not inside a Git repository." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

CHANGED_FILE_LIST="$(mktemp)"
UNTRACKED_FILE_LIST="$(mktemp)"
ALL_FILE_LIST="$(mktemp)"
trap 'rm -f "$CHANGED_FILE_LIST" "$UNTRACKED_FILE_LIST" "$ALL_FILE_LIST"' EXIT

# Tracked files changed relative to HEAD (staged + unstaged), excluding deletions.
git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMRTUXB HEAD > "$CHANGED_FILE_LIST"

# Untracked files, excluding ignored files.
git -C "$PROJECT_ROOT" ls-files --others --exclude-standard > "$UNTRACKED_FILE_LIST"

# Merge + deduplicate safely for newline-based Git paths.
cat "$CHANGED_FILE_LIST" "$UNTRACKED_FILE_LIST" | awk '!seen[$0]++ && NF' > "$ALL_FILE_LIST"

if [[ ! -s "$ALL_FILE_LIST" ]]; then
  echo "No changed or new files found."
else
  while IFS= read -r relpath; do
    [[ -n "$relpath" ]] || continue

    src="$PROJECT_ROOT/$relpath"
    dst="$BACKUP_DIR/$relpath"

    if [[ -e "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp -pR "$src" "$dst"
      echo "Backed up: $relpath"
    else
      echo "Skipped deleted/missing path: $relpath"
    fi
  done < "$ALL_FILE_LIST"
fi

# Reset tracked changes.
git -C "$PROJECT_ROOT" reset --hard HEAD

# Remove untracked files/directories (but not ignored files).
git -C "$PROJECT_ROOT" clean -fd

echo
echo "Backup complete."
echo "Repository cleaned."
echo "Final git status:"
git -C "$PROJECT_ROOT" status --short
git -C "$PROJECT_ROOT" status
