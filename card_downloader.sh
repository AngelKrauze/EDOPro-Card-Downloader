#!/bin/sh
set -eu

edopro="/path/to/edopro/"
concurrency=8

if [ ! -d "$edopro" ]; then
  echo "EDOPro folder not found." >&2
  exit 1
fi

mkdir -p "$edopro/pics"

# Temporary files for processing
all_ids=$(mktemp)
missing_ids=$(mktemp)
trap 'rm -f "$all_ids" "$missing_ids"' EXIT

# 1. Collect all numeric IDs from all decks
for deck in "$edopro"/deck/*.ydk; do
  [ -f "$deck" ] || continue
  while IFS= read -r id || [ -n "$id" ]; do
    case "$id" in
      ''|*[!0-9]*) continue ;;
    esac
    echo "$id"
  done < "$deck"
done > "$all_ids"

# 2. Deduplicate IDs and filter out those already downloaded
sort -u "$all_ids" | while read -r id; do
  [ -f "$edopro/pics/$id.jpg" ] || echo "$id"
done > "$missing_ids"

# 3. Download the unique missing images in parallel
cat "$missing_ids" | xargs -P "$concurrency" -I {} sh -c '
  id="{}"
  out="'"$edopro"'/pics/$id.jpg"
  if curl -fsSL --connect-timeout 5 --max-time 15 -o "$out" "https://images.ygoprodeck.com/images/cards/$id.jpg"; then
    echo "Downloaded: $id"
  else
    echo "Failed: $id" >&2
  fi
'
