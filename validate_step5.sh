#!/usr/bin/env bash
# validate_step5.sh — (Stretch) verify a self-hosted Jetson runner is online
# and the jetson-smoke job ran green on it.
#
# Usage:
#   REPO=<owner>/<repo> ./validate_step5.sh
set -e
echo "=== Step 5 validator: self-hosted runner ==="

if [ -n "${REPO:-}" ]; then
    echo "Using REPO=$REPO (env override)"
elif REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null); then
    echo "Using REPO=$REPO (from current git remote)"
else
    echo "FAIL: cannot determine repo. Set REPO=<owner>/<repo> or run from inside a github.com clone."
    exit 1
fi

gh auth status >/dev/null 2>&1 || { echo "FAIL: gh not authenticated. Run 'gh auth login'."; exit 1; }
echo "PASS: gh authenticated"

# 1. Runner is registered and online
ONLINE=$(gh api "/repos/$REPO/actions/runners" \
    --jq '.runners[] | select(.status=="online") | .name' | wc -l)
[ "$ONLINE" -ge 1 ] || { echo "FAIL: no online self-hosted runners on $REPO"; exit 1; }
echo "PASS: $ONLINE self-hosted runner(s) online"

# 2. Latest workflow run included a jetson-smoke job
RUN_ID=$(gh api "/repos/$REPO/actions/runs?per_page=1" --jq '.workflow_runs[0].id')
[ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ] \
    || { echo "FAIL: no workflow runs found on $REPO"; exit 1; }

JOB=$(gh api "/repos/$REPO/actions/runs/$RUN_ID/jobs" \
    --jq '.jobs[] | select(.name=="Smoke test on Jetson")')
[ -n "$JOB" ] || { echo "FAIL: no 'Smoke test on Jetson' job in latest run ($RUN_ID)"; exit 1; }

CONC=$(echo "$JOB" | jq -r .conclusion)
[ "$CONC" = "success" ] || { echo "FAIL: jetson-smoke conclusion=$CONC"; exit 1; }
echo "PASS: jetson-smoke ran green on self-hosted runner"

echo "=== Step 5 PASS ==="
