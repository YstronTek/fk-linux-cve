#!/usr/bin/env bash
# Print a JSON array of kernel.org releases (mainline, stable, longterm; EOL
# branches skipped) that have no published GitHub release in $GH_REPO yet.
#
# Each element: {version, moniker, source, tag, prerelease, latest}
#   tag        GitHub release tag, "v<version>"
#   prerelease true for -rc versions
#   latest     true only for the newest stable version
set -euo pipefail

releases=$(curl -fsSL --retry 3 https://www.kernel.org/releases.json)

# Drafts are left behind by interrupted uploads; they do not count as built.
published=$(gh release list --limit 10000 --json tagName,isDraft \
  --jq '[.[] | select(.isDraft | not) | .tagName]')

jq -c --argjson published "$published" '
  (first(.releases[] | select(.moniker == "stable" and (.iseol | not))) | .version) as $newest_stable
  | [.releases[]
     | select(.moniker == "mainline" or .moniker == "stable" or .moniker == "longterm")
     | select(.iseol | not)
     | {version, moniker, source,
        tag: ("v" + .version),
        prerelease: (.version | contains("-rc")),
        latest: (.version == $newest_stable)}]
  | unique_by(.version)
  | map(select(.tag | IN($published[]) | not))
' <<<"$releases"
