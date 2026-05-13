#!/usr/bin/env bash
# validate_step4.sh — verify the GHCR image pulls, runs, and exposes a
# working TRT engine + inference loop. Run this on the Orin Nano.
#
# Usage:
#   GHCR_USER=<your-github-user> SHA=<short-sha> [TEST_VIDEO=<path>] ./validate_step4.sh
set -e
echo "=== Step 4 validator: image runs on Jetson ==="

GHCR_USER="${GHCR_USER:?set GHCR_USER to your GitHub username}"
SHA="${SHA:?set SHA to the short git SHA (e.g. SHA=abc1234)}"
TEST_VIDEO="${TEST_VIDEO:-$HOME/lab10/test_video.mp4}"
IMAGE="ghcr.io/${GHCR_USER}/edgeai-lab12:sha-${SHA}"

[ -f "$TEST_VIDEO" ] || { echo "FAIL: test video not found at $TEST_VIDEO. Set TEST_VIDEO=<path>."; exit 1; }
echo "PASS: test video found ($TEST_VIDEO)"

# 1. Image pulls
docker pull "$IMAGE" >/dev/null || { echo "FAIL: docker pull failed"; exit 1; }
echo "PASS: image pulled"

# 2. Architecture is arm64
ARCH=$(docker inspect "$IMAGE" --format='{{.Architecture}}')
[ "$ARCH" = "arm64" ] || { echo "FAIL: image arch is $ARCH, expected arm64"; exit 1; }
echo "PASS: arch = arm64"

# 3. Container starts and entrypoint compiles or reuses engine
docker volume create lab12-models >/dev/null
docker rm -f lab12-validate >/dev/null 2>&1 || true
docker run --runtime nvidia --network host \
    -v lab12-models:/opt/models \
    -v "$TEST_VIDEO":/opt/data/test_video.mp4:ro \
    --name lab12-validate -d "$IMAGE" >/dev/null \
    || { echo "FAIL: docker run failed"; exit 1; }

ENGINE_READY=""
for i in {1..144}; do
    if docker logs lab12-validate 2>&1 | grep -qE "Reusing cached engine|Engine compiled"; then
        ENGINE_READY=yes
        echo "PASS: entrypoint compiled or reused engine"
        break
    fi
    sleep 5
done
[ -n "$ENGINE_READY" ] || {
    echo "FAIL: no engine ready signal in 12 min"
    docker logs lab12-validate | tail -20
    docker stop lab12-validate >/dev/null 2>&1 || true
    docker rm -f lab12-validate >/dev/null 2>&1 || true
    exit 1
}

# 4. inference_node.py started processing
INFERENCE_OK=""
for i in {1..12}; do
    if docker logs lab12-validate 2>&1 | grep -qE "Running inference on|frames,.*FPS"; then
        INFERENCE_OK=yes
        echo "PASS: inference_node.py started and is processing the test video"
        break
    fi
    sleep 5
done
[ -n "$INFERENCE_OK" ] || {
    echo "FAIL: inference loop did not start within 60 s"
    docker logs lab12-validate | tail -20
    docker stop lab12-validate >/dev/null 2>&1 || true
    docker rm -f lab12-validate >/dev/null 2>&1 || true
    exit 1
}

docker stop lab12-validate >/dev/null 2>&1 || true
docker rm -f lab12-validate >/dev/null 2>&1 || true
echo "=== Step 4 PASS ==="
