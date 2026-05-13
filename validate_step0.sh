#!/usr/bin/env bash
# validate_step0.sh — confirm repo exists on GitHub with all required files.
# Run from inside ~/lab12 after Step 0.3.
set -e
echo "=== Step 0 validator: repo plumbing ==="

# 1. gh installed + authenticated
gh auth status >/dev/null 2>&1 || { echo "FAIL: gh not authenticated. Run 'gh auth login'."; exit 1; }
echo "PASS: gh authenticated"

# 2. origin is on github.com
ORIGIN=$(git remote get-url origin)
[[ "$ORIGIN" == *github.com* ]] || { echo "FAIL: origin is not github.com: $ORIGIN"; exit 1; }
echo "PASS: origin = $ORIGIN"

# 3. Repo is public
VIS=$(gh repo view --json visibility --jq .visibility)
[[ "$VIS" == "PUBLIC" ]] || { echo "FAIL: repo visibility is $VIS, must be PUBLIC"; exit 1; }
echo "PASS: repo is PUBLIC"

# 4. Required files present in the latest commit
for f in Dockerfile.ci inference_node.py requirements.txt best.pt; do
    git cat-file -e "HEAD:$f" 2>/dev/null || { echo "FAIL: $f missing from HEAD"; exit 1; }
    echo "PASS: $f present"
done

# 5. Optional PDM files
for f in pyproject.toml pdm.lock; do
    if [ -f "$f" ]; then
        git cat-file -e "HEAD:$f" 2>/dev/null \
            && echo "PASS: $f present (PDM)" \
            || echo "WARN: $f exists locally but is not committed — git add $f"
    fi
done

echo "=== Step 0 PASS ==="
