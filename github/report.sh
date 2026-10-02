#!/usr/bin/env bash
set -euo pipefail

dir="$GITHUB_WORKSPACE/grammage"
prefix=grammage
[ "$GRAMMAGE_COMMAND" = source ] && prefix=grammage-source

if [ -f "$dir/$prefix-annotations.txt" ]; then
  cat "$dir/$prefix-annotations.txt"
fi

summary="$dir/grammage-summary.md"
if [ "$GRAMMAGE_COMMAND" = source ] || [ ! -f "$summary" ]; then
  exit 0
fi
cat "$summary" >> "$GITHUB_STEP_SUMMARY"

if [ "$GRAMMAGE_COMMENT" != true ] || [ "$GRAMMAGE_COMMAND" != audit ] || [ -z "$GRAMMAGE_PR" ]; then
  exit 0
fi

marker='<!-- grammage -->'
body="$marker"$'\n'"$(cat "$summary")"
comments="repos/$GITHUB_REPOSITORY/issues/$GRAMMAGE_PR/comments"
id=$(gh api "$comments" --paginate --jq ".[] | select(.body | startswith(\"$marker\")) | .id" | head -n 1)

if [ -n "$id" ]; then
  gh api --method PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$id" --field body="$body" > /dev/null
else
  gh api "$comments" --field body="$body" > /dev/null
fi
