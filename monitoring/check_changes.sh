#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# check_changes.sh
#
# Detect whether the watched branch (a mirror of upstream xai-org/x-algorithm)
# has changed since the last analyzed commit recorded in monitoring/state.json.
#
# Output is both human-readable and machine-parseable. The monitoring Routine
# reads the `CHANGED=` and `diff_range=` lines to decide whether to run a new
# code analysis, and uses the printed commit list / changed files / diffstat as
# the starting point for that analysis.
#
# Usage:
#   monitoring/check_changes.sh
#
# Exit codes:
#   0  -> ran successfully (see CHANGED=true|false in output)
#   1  -> error (e.g. state file missing, fetch failed)
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STATE="monitoring/state.json"
if [ ! -f "$STATE" ]; then
  echo "ERROR: $STATE not found (run from a checkout that contains the monitoring/ tooling)." >&2
  exit 1
fi

BRANCH="$(jq -r '.watched_branch' "$STATE")"
LAST="$(jq -r '.last_analyzed_sha' "$STATE")"

echo "repo=$(jq -r '.repo' "$STATE")"
echo "upstream=$(jq -r '.upstream' "$STATE")"
echo "watched_branch=$BRANCH"
echo "last_analyzed_sha=$LAST"

# Fetch the latest state of the watched branch.
if ! git fetch -q origin "$BRANCH"; then
  echo "ERROR: git fetch origin $BRANCH failed." >&2
  exit 1
fi
NEW="$(git rev-parse "origin/$BRANCH")"
echo "current_sha=$NEW"

if [ "$LAST" = "$NEW" ]; then
  echo "CHANGED=false"
  echo "No new commits on origin/$BRANCH since the last analysis. Nothing to do."
  exit 0
fi

echo "CHANGED=true"
echo "diff_range=${LAST}..${NEW}"

echo "----- new commits (${LAST:0:8}..${NEW:0:8}) -----"
git log --oneline --no-decorate "${LAST}..${NEW}" 2>/dev/null || \
  echo "(could not list commits; ${LAST:0:8} may not be an ancestor — treat as full re-analysis)"

echo "----- changed files -----"
git diff --name-status "${LAST}..${NEW}" 2>/dev/null || \
  echo "(could not diff ${LAST:0:8}..${NEW:0:8})"

echo "----- diffstat -----"
git diff --stat "${LAST}..${NEW}" 2>/dev/null || true
