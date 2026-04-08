#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  copy-selected.sh --project-root=<project_root> --paths=<comma-separated-paths> [--ignore-paths=<comma-separated-ignore-paths>]

Examples:
  copy-selected.sh --project-root=/home/me/my-project --paths="composer.json,web/modules/custom,config/sync/core.extension.yml"

Options:
  --project-root=<path>    Path to the project root
  --paths=<paths>          Comma-separated list of paths to include
  --ignore-paths=<paths>   Optional comma-separated list of paths to exclude
  -h, --help               Show this help
EOF
  exit 1
}

project_root=""
input_list=""
ignore_list=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root=*)
      project_root="${1#*=}"
      shift
      ;;
    --project-root)
      [[ $# -ge 2 ]] || usage
      project_root="$2"
      shift 2
      ;;
    --paths=*)
      input_list="${1#*=}"
      shift
      ;;
    --paths)
      [[ $# -ge 2 ]] || usage
      input_list="$2"
      shift 2
      ;;
    --ignore-paths=*)
      ignore_list="${1#*=}"
      shift
      ;;
    --ignore-paths)
      [[ $# -ge 2 ]] || usage
      ignore_list="$2"
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

[[ -n "$project_root" && -n "$input_list" ]] || usage

if [[ ! -d "$project_root" ]]; then
  echo "Error: project root does not exist or is not a directory: $project_root" >&2
  exit 1
fi

if [[ ! -d "$HOME/Downloads" ]]; then
  echo "Error: ~/Downloads does not exist." >&2
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "Error: zip command not found." >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "Error: rsync command not found." >&2
  exit 1
fi

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

normalize_rel_path() {
  local path
  path="$(trim "$1")"

  # Make relative to project root.
  path="${path#/}"

  # Remove trailing slashes.
  while [[ -n "$path" && "$path" == */ ]]; do
    path="${path%/}"
  done

  printf '%s' "$path"
}

is_ignored() {
  local path="$1"
  local raw_ignore ignore

  for raw_ignore in "${ignore_items[@]-}"; do
    ignore="$(normalize_rel_path "$raw_ignore")"
    [[ -z "$ignore" ]] && continue

    if [[ "$path" == "$ignore" || "$path" == "$ignore/"* ]]; then
      return 0
    fi
  done

  return 1
}

project_root="$(cd "$project_root" && pwd)"
project_name="$(basename "$project_root")"

tmp_base="$(mktemp -d "/tmp/${project_name}.XXXXXX")"
target_root="${tmp_base}/${project_name}"

mkdir -p "$target_root"

items=()
ignore_items=()

IFS=',' read -r -a items <<< "$input_list"

if [[ -n "$ignore_list" ]]; then
  IFS=',' read -r -a ignore_items <<< "$ignore_list"
fi

for raw_item in "${items[@]-}"; do
  item="$(normalize_rel_path "$raw_item")"

  [[ -z "$item" ]] && continue

  if is_ignored "$item"; then
    echo "Skipping ignored path: $item" >&2
    continue
  fi

  src="${project_root}/${item}"
  dest="${target_root}/${item}"

  if [[ ! -e "$src" ]]; then
    echo "Warning: path does not exist, skipping: $item" >&2
    continue
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -d "$src" ]]; then
    rsync_args=(-a)

    for raw_ignore in "${ignore_items[@]-}"; do
      ignore="$(normalize_rel_path "$raw_ignore")"
      [[ -z "$ignore" ]] && continue

      # Only apply ignore rules that are inside this included directory.
      if [[ "$ignore" == "$item/"* ]]; then
        rel_ignore="${ignore#"$item"/}"
        rsync_args+=(--exclude="$rel_ignore")
      fi
    done

    mkdir -p "$dest"
    rsync "${rsync_args[@]}" "$src"/ "$dest"/
  else
    cp -a "$src" "$dest"
  fi
done

if [[ -z "$(find "$target_root" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
  echo "Error: nothing was copied, aborting ZIP creation." >&2
  rm -rf "$tmp_base"
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
zip_name="${project_name}-${timestamp}.zip"
zip_tmp_path="${tmp_base}/${zip_name}"
zip_final_path="$HOME/Downloads/${zip_name}"

(
  cd "$tmp_base"
  zip -rq "$zip_tmp_path" "$project_name"
)

mv "$zip_tmp_path" "$zip_final_path"

rm -rf "$tmp_base"

echo "ZIP created at:"
echo "$zip_final_path"
