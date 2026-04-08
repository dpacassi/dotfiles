#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage:
  backup-and-clean-git-changes.sh --project-root=<project_root> --backup-dir=<backup_dir>

Options:
  --project-root=<path>   Path to the Git project root
  --backup-dir=<path>     Path to the backup directory
  -h, --help              Show this help
EOF
  exit 1
}

PROJECT_ROOT=""
BACKUP_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    -h|--help)
      usage
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      ;;
  esac
done

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
