#!/usr/bin/env bash
# validate_step1.sh — verify the latest CI workflow run on main is green.
# Polls every 5 s for up to 3 min.
set -e
echo "=== Step 1 validator: workflow green ==="

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "Repo: $REPO"

for i in {1..36}; do
    STATUS=$(gh run list --workflow=ci.yml --limit 1 --json status,conclusion --jq '.[0]')
    S=$(echo "$STATUS" | jq -r .status)
    C=$(echo "$STATUS" | jq -r .conclusion)
    if [ "$S" = "completed" ]; then
        if [ "$C" = "success" ]; then
            echo "PASS: workflow conclusion = success"
            echo "=== Step 1 PASS ==="
            exit 0
        else
            echo "FAIL: workflow conclusion = $C"
            echo "  Open in browser: gh run view --web"
            exit 1
        fi
    fi
    echo "  attempt $i/36: status=$S, waiting 5 s..."
    sleep 5
done

echo "FAIL: workflow did not complete within 3 min"
exit 1
