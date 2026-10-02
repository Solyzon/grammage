#!/usr/bin/env bash
set -euo pipefail

image="$GRAMMAGE_REGISTRY/solyzon/products/grammage/grammage:$GRAMMAGE_VERSION"
printf '%s' "$GRAMMAGE_LICENSE" |
  docker login "$GRAMMAGE_REGISTRY" --username "$GRAMMAGE_REGISTRY_USERNAME" --password-stdin
docker pull --quiet "$image"

set +e
docker run --rm --network host --user "$(id -u):$(id -g)" \
  --volume "$GITHUB_WORKSPACE:/repo" --workdir /repo --env HOME=/tmp \
  --env GRAMMAGE_PLATFORM=github --env GRAMMAGE_COMMAND --env GRAMMAGE_URL --env GRAMMAGE_SITE \
  --env GRAMMAGE_SERVE_URL --env GRAMMAGE_SERVE_TIMEOUT --env GRAMMAGE_URLS_FILE \
  --env GRAMMAGE_MAX_PAGES --env GRAMMAGE_DEVICE --env GRAMMAGE_MODE --env GRAMMAGE_RUNS \
  --env GRAMMAGE_PARALLEL --env GRAMMAGE_CATEGORY --env GRAMMAGE_BUDGET \
  --env GRAMMAGE_FAIL_UNDER --env GRAMMAGE_HTTP_AUTH --env GRAMMAGE_LICENSE \
  --entrypoint grammage-ci "$image"
code=$?
set -e

echo "ran=true" >> "$GITHUB_OUTPUT"
echo "exit-code=$code" >> "$GITHUB_OUTPUT"
