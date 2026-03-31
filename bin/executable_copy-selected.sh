#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <project_root> <comma-separated-paths>"
  echo
  echo "Example:"
  echo "  $0 /home/me/my-project \"composer.json,web/modules/custom,config/sync/core.extension.yml\""
  exit 1
}

if [[ $# -ne 2 ]]; then
  usage
fi

project_root="$1"
input_list="$2"

if [[ ! -d "$project_root" ]]; then
  echo "Error: project root does not exist or is not a directory: $project_root" >&2
  exit 1
fi

if [[ ! -d "$HOME/Downloads" ]]; then
  echo "Error: ~/Downloads does not exist." >&2
  exit 1
fi

project_root="$(cd "$project_root" && pwd)"
project_name="$(basename "$project_root")"

tmp_base="$(mktemp -d "/tmp/${project_name}.XXXXXX")"
target_root="${tmp_base}/${project_name}"

mkdir -p "$target_root"

IFS=',' read -r -a items <<< "$input_list"

for raw_item in "${items[@]}"; do
  item="$(echo "$raw_item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  if [[ -z "$item" ]]; then
    continue
  fi

  item="${item#/}"
  src="${project_root}/${item}"
  dest="${target_root}/${item}"

  if [[ ! -e "$src" ]]; then
    echo "Warning: path does not exist, skipping: $item" >&2
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
done

timestamp="$(date +%Y%m%d-%H%M%S)"
zip_name="${project_name}-${timestamp}.zip"
zip_tmp_path="${tmp_base}/${zip_name}"
zip_final_path="$HOME/Downloads/${zip_name}"

(
  cd "$tmp_base"
  zip -rq "$zip_tmp_path" "$project_name"
)

mv "$zip_tmp_path" "$zip_final_path"

rm -rf "$target_root"
rmdir "$tmp_base" 2>/dev/null || true

echo "ZIP created at:"
echo "$zip_final_path"

