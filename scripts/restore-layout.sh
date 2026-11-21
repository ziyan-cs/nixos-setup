#!/usr/bin/env bash
set -euo pipefail

apply=false
if [[ "${1-}" == --apply ]]; then
  apply=true
  shift
fi
if (( $# > 1 )) || [[ "${1-}" == -* ]]; then
  printf 'Usage: %s [--apply] [existing-root]\n' "$0" >&2
  exit 2
fi

root=$(cd -- "${1:-$HOME}" && pwd -P)
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
missing=()
while IFS= read -r path; do
  [[ "$path" =~ ^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*$ ]] || {
    printf 'Invalid directory entry: %s\n' "$path" >&2
    exit 1
  }
  parent=$root
  IFS=/ read -r -a parts <<< "$path"
  for part in "${parts[@]}"; do
    parent=$parent/$part
    if [[ -L "$parent" || ( -e "$parent" && ! -d "$parent" ) ]]; then
      printf 'Path conflicts with a file or symlink: %s\n' "$parent" >&2
      exit 1
    fi
  done
  [[ -d "$parent" ]] || missing+=("$parent")
done < "$repo/manifests/storage-layout.txt"

if (( ! ${#missing[@]} )); then
  printf 'All layout directories already exist.\n'
elif "$apply"; then
  mkdir -pv -- "${missing[@]}"
else
  printf 'Would create: %s\n' "${missing[@]}"
fi
