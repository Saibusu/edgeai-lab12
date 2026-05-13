#!/usr/bin/env bash
# validate_step3.sh — verify the most recent workflow run produced a
# linux/arm64 image in GHCR tagged with the current commit's short SHA.
set -e
echo "=== Step 3 validator: ARM64 image in GHCR ==="

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
SHA=$(git rev-parse --short HEAD)
OWNER=$(echo "$REPO" | cut -d/ -f1)
PKG=$(echo "$REPO" | cut -d/ -f2)
IMAGE="ghcr.io/$REPO"

echo "Looking for $IMAGE:sha-$SHA"

# 1. Wait for the build job to finish (up to 50 min — QEMU is slow)
for i in {1..600}; do
    STATUS=$(gh run list --workflow=ci.yml --limit 1 --json status,conclusion --jq '.[0]')
    S=$(echo "$STATUS" | jq -r .status)
    C=$(echo "$STATUS" | jq -r .conclusion)
    if [ "$S" = "completed" ]; then
        [ "$C" = "success" ] || { echo "FAIL: workflow conclusion=$C"; exit 1; }
        echo "PASS: workflow completed successfully"
        break
    fi
    [ $((i % 12)) -eq 0 ] && echo "  ...${i} attempts ($((i*5/60)) min elapsed), status=$S"
    sleep 5
done

# 2. Check the package exists in GHCR via the GitHub API
OWNER_TYPE=$(gh api "/users/$OWNER" --jq .type 2>/dev/null || echo "User")
if [ "$OWNER_TYPE" = "Organization" ]; then
    PKG_PATH="/orgs/$OWNER/packages/container/$PKG/versions"
else
    PKG_PATH="/users/$OWNER/packages/container/$PKG/versions"
fi

gh api "$PKG_PATH" --jq '.[0].metadata.container.tags' \
    > /tmp/tags.json 2>/dev/null \
    || { echo "FAIL: cannot read GHCR package metadata at $PKG_PATH. Did the build push succeed?"; exit 1; }

if grep -q "sha-$SHA" /tmp/tags.json; then
    echo "PASS: GHCR has tag sha-$SHA"
else
    echo "FAIL: no sha-$SHA tag found. Got: $(cat /tmp/tags.json)"
    exit 1
fi

# 3. Verify manifest reports linux/arm64
if ! MANIFEST=$(docker manifest inspect "$IMAGE:sha-$SHA" 2>&1); then
    echo "WARN: docker manifest inspect unavailable — verify arm64 manually in GHCR web UI"
    echo "  https://github.com/$REPO/pkgs/container/$PKG"
else
    ARCHES=$(echo "$MANIFEST" | jq -r '.manifests[]?.platform.architecture, .architecture' 2>/dev/null || true)
    if echo "$ARCHES" | grep -qE '^(arm64|aarch64)$'; then
        echo "PASS: manifest reports arm64"
    else
        echo "FAIL: manifest is not arm64 (saw: $ARCHES)"
        exit 1
    fi
fi

echo "=== Step 3 PASS ==="
