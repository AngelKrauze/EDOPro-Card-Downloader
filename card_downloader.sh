#!/usr/bin/env bash
set -euo pipefail; shopt -s nullglob

# Yu-Gi-Oh! High Definition card downloader.
# Requirements: curl

# Check for curl dependency
command -v curl >/dev/null || { printf 'MISSING: curl command required' >&2; exit 1; }

readonly dir="/path/to/edopro/"

if [ -d "$dir" ]; then
	readonly decks_dir="$dir/deck"
	readonly decks=("$decks_dir"/*.ydk)
else
	printf 'WARNING: %s %s\n' "$dir" "does not exist"; exit 1
fi

# Exit if there are no deck files
[[ ${#decks[@]} -gt 0 ]] || { printf 'MISSING: No .ydk files found in %s\n' "$decks_dir" >&2; exit 1; }

mkdir -p "$dir/pics" || { printf 'WARNING: mkdir pics failed' >&2; exit 1; }

# Create tmpfs for incmplete downloads
tmp=$(mktemp -d "${TMPDIR:-/tmp}/edopro.XXXXXX") || { printf 'WARNING: mktemp failed' >&2; exit 1; }

# Clean tmpfs after exit or interrupted
trap '[[ -n "${tmp:-}" ]] && rm -rf "$tmp"' EXIT INT TERM HUP QUIT ABRT PIPE

for ydk in "${decks[@]}"; do

	while IFS= read -r card_id || [[ -n "$card_id" ]]; do
		# Cards ID's are numeric only (max. digits: 10)
		if [[ ! $card_id =~ ^[0-9]{1,10}$ ]]; then
			continue
		fi
		# Skip if file already exist
		if [[ -f "$dir/pics/$card_id.jpg" ]]; then
			continue
		fi
		# Download card JPEG using curl
		if curl -sS -f -C - --connect-timeout 5 --max-time 10 --retry 2 --retry-delay 1 --max-filesize 10485760 -o "$tmp/$card_id.jpg.tmp" https://images.ygoprodeck.com/images/cards/$card_id.jpg 2>/dev/null; then
			mv "$tmp/$card_id.jpg.tmp" "$dir/pics/$card_id.jpg" || { echo "mv failed for $card_id" >&2; continue; }
			printf 'Success: %s\n' "$card_id"
		else
			printf 'Failure: %s\n' "$card_id"
		fi
	done < "$ydk"
done
