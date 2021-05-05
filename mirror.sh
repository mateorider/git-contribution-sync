#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# mirror.sh — reflect your work commit activity onto your GitHub graph.
#
# Reads the author DATES of your commits from the private work repos listed in
# repos.conf and replays each one here as an empty commit (no code, no message,
# no diff). Push this repo to GitHub and your contribution graph lights up with
# the real cadence of your work — without exposing anything proprietary.
#
# Idempotent: every mirror commit records the source hash in a trailer, so
# re-running only imports commits that are new since last time.
#
#   ./mirror.sh            # import new commits
#   ./mirror.sh --dry-run  # show what would be imported, commit nothing
# ---------------------------------------------------------------------------
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

CONFIG="${CONFIG:-$here/repos.conf}"
if [[ ! -f "$CONFIG" ]]; then
  echo "error: config not found: $CONFIG" >&2
  exit 1
fi

# Defaults, overridable by the config file.
SOURCES=()
AUTHORS=()
SINCE=""
MIRROR_NAME="$(git config user.name  || true)"
MIRROR_EMAIL="$(git config user.email || true)"
# shellcheck source=/dev/null
source "$CONFIG"

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  echo "error: no SOURCES configured in $CONFIG" >&2
  exit 1
fi
if [[ ${#AUTHORS[@]} -eq 0 ]]; then
  echo "error: no AUTHORS configured in $CONFIG" >&2
  exit 1
fi
if [[ -z "$MIRROR_NAME" || -z "$MIRROR_EMAIL" ]]; then
  echo "error: MIRROR_NAME / MIRROR_EMAIL are empty (set them in $CONFIG)" >&2
  exit 1
fi

# --author flags OR together in git log.
author_args=()
for a in "${AUTHORS[@]}"; do author_args+=(--author="$a"); done

# Collect candidate commits across all source repos: epoch \t isodate \t hash
tmp="$(mktemp)"
seen="$(mktemp)"
trap 'rm -f "$tmp" "$seen"' EXIT

# Source hashes already mirrored, read straight from this repo's history so the
# ledger survives a fresh clone. (Empty repo => no log => empty set.)
# Kept in a file + grep rather than an associative array so this runs on the
# bash 3.2 that ships with macOS.
git log --pretty=%B 2>/dev/null | sed -n 's/^Source-Commit: //p' > "$seen" || true

missing=0
for repo in "${SOURCES[@]}"; do
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "warning: not a git repo, skipping: $repo" >&2
    missing=$((missing + 1))
    continue
  fi
  git -C "$repo" log --all --no-merges "${author_args[@]}" \
      ${SINCE:+--since="$SINCE"} \
      --pretty=format:'%at%x09%aI%x09%H' >> "$tmp" || true
  printf '\n' >> "$tmp"
done

# Chronological order so the mirrored history reads cleanly.
sort -n -o "$tmp" "$tmp"

new=0
skipped=0
while IFS=$'\t' read -r at iso hash; do
  [[ -z "${hash:-}" ]] && continue
  if grep -qxF "$hash" "$seen"; then
    skipped=$((skipped + 1))
    continue
  fi
  echo "$hash" >> "$seen"   # guard against the same source hash appearing twice
  new=$((new + 1))
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "would mirror  $iso  ${hash:0:12}"
    continue
  fi
  GIT_AUTHOR_NAME="$MIRROR_NAME"   GIT_AUTHOR_EMAIL="$MIRROR_EMAIL" \
  GIT_COMMITTER_NAME="$MIRROR_NAME" GIT_COMMITTER_EMAIL="$MIRROR_EMAIL" \
  GIT_AUTHOR_DATE="$iso"           GIT_COMMITTER_DATE="$iso" \
  git commit --allow-empty -q \
    -m "Work contribution" \
    -m "Source-Commit: $hash"
done < "$tmp"

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "dry run: $new new commit(s) would be mirrored, $skipped already present."
else
  echo "done: mirrored $new new commit(s), skipped $skipped already present."
fi
[[ $missing -gt 0 ]] && echo "($missing source path(s) skipped — see warnings above.)"
exit 0
