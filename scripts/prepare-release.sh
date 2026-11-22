#!/usr/bin/env bash
# Publish the metadata commit and its new tag together; never move an existing tag.
set -euo pipefail

tag=${1:?release tag required}
checksum=${2:?artifact checksum required}
source_sha=${3:?validated source commit required}
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]
[[ "$checksum" =~ ^[a-f0-9]{64}$ ]]
[[ "$source_sha" =~ ^[a-f0-9]{40}$ ]]
[[ "$(git rev-parse HEAD)" == "$source_sha" ]]
git diff --exit-code --quiet
git diff --cached --exit-code --quiet
[[ "$(git ls-remote origin refs/heads/main | cut -f1)" == "$source_sha" ]]
[[ -z "$(git ls-remote origin "refs/tags/$tag")" ]]

TAG="$tag" CHECKSUM="$checksum" python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path("Package.swift")
text = path.read_text()
for name, value in [("releaseTag", os.environ["TAG"]), ("releaseChecksum", os.environ["CHECKSUM"])]:
    text, count = re.subn(rf'let {name} = "[^"\n]+"', f'let {name} = "{value}"', text)
    if count != 1:
        raise SystemExit(f"Expected one {name} declaration, found {count}")
path.write_text(text)
PY
swift package dump-package >/dev/null
git add Package.swift
git commit -m "chore: prepare release $tag"
# A concurrent main update or conflicting tag rejects the entire atomic push.
git push --atomic origin HEAD:refs/heads/main "HEAD:refs/tags/$tag"
commit=$(git rev-parse HEAD)
[[ "$(git ls-remote origin "refs/tags/$tag" | cut -f1)" == "$commit" ]]
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'commit=%s\n' "$commit" >> "$GITHUB_OUTPUT"
fi
