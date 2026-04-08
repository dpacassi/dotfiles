#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_DIR="${REPO_HELPER_CONFIG_DIR:-$SCRIPT_DIR/.config}"

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME --project=<name> [--project-root=<path>] [--paths=<paths>] [--ignore-paths=<paths>] [--config-dir=<path>]
  $SCRIPT_NAME --project-root=<project_root> --paths=<comma-separated-paths> [--ignore-paths=<comma-separated-ignore-paths>]

Config:
  By default, project presets are loaded from:
    $DEFAULT_CONFIG_DIR/<project>.conf

  Example config file:
    project_root="/Users/dpacassi/Coding/ubs-football-skills.ch"
    paths=".ddev,config,web/modules/custom,web/themes/custom,composer.json,composer.lock,README.md"
    ignore_paths="web/themes/custom/customer/dist,web/themes/custom/customer/node_modules,web/themes/custom/customer/src/media/videos"

Options:
  --project=<name>         Load preset values from <config-dir>/<name>.conf
  --project-root=<path>    Path to the project root
  --paths=<paths>          Comma-separated list of paths to include
  --ignore-paths=<paths>   Optional comma-separated list of paths to exclude
  --config-dir=<path>      Override config directory
  -h, --help               Show this help

Precedence:
  explicit CLI args > project config file > error
EOF
  exit 1
}

project_name=""
project_root=""
input_list=""
ignore_list=""
config_dir="$DEFAULT_CONFIG_DIR"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project=*)
      project_name="${1#*=}"
      shift
      ;;
    --project)
      [[ $# -ge 2 ]] || usage
      project_name="$2"
      shift 2
      ;;
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
    --config-dir=*)
      config_dir="${1#*=}"
      shift
      ;;
    --config-dir)
      [[ $# -ge 2 ]] || usage
      config_dir="$2"
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

config_project_root=""
config_paths=""
config_ignore_paths=""

load_project_config() {
  local project="$1"
  local config_file="$config_dir/${project}.conf"

  if [[ ! -f "$config_file" ]]; then
    echo "Error: project config not found: $config_file" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$config_file"

  config_project_root="${project_root:-}"
  config_paths="${paths:-}"
  config_ignore_paths="${ignore_paths:-}"
}

if [[ -n "$project_name" ]]; then
  load_project_config "$project_name"
fi

project_root="${project_root:-$config_project_root}"
input_list="${input_list:-$config_paths}"
ignore_list="${ignore_list:-$config_ignore_paths}"

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
resolved_project_name="$(basename "$project_root")"

tmp_base="$(mktemp -d "/tmp/${resolved_project_name}.XXXXXX")"
target_root="${tmp_base}/${resolved_project_name}"

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
zip_name="${resolved_project_name}-${timestamp}.zip"
zip_tmp_path="${tmp_base}/${zip_name}"
zip_final_path="$HOME/Downloads/${zip_name}"

(
  cd "$tmp_base"
  zip -rq "$zip_tmp_path" "$resolved_project_name"
)

mv "$zip_tmp_path" "$zip_final_path"

rm -rf "$tmp_base"

echo "ZIP created at:"
echo "$zip_final_path"
