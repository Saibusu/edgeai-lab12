#!/usr/bin/env bash
# entrypoint.sh — runs at container start on the Jetson.
#
# 1. If best.engine is missing or older than best.pt, compile it with
#    yolo export format=engine (needs --runtime nvidia).
# 2. exec the Dockerfile CMD so SIGTERM from `docker stop` reaches Python directly.

set -euo pipefail

MODEL_DIR=/opt/models
WEIGHTS=${MODEL_DIR}/best.pt
ENGINE=${MODEL_DIR}/best.engine

if [ ! -f "${WEIGHTS}" ]; then
    echo "ERROR: ${WEIGHTS} not found. Did you copy best.pt into the image?" >&2
    exit 1
fi

if [ ! -f "${ENGINE}" ] || [ "${WEIGHTS}" -nt "${ENGINE}" ]; then
    echo "[entrypoint] Compiling TensorRT engine (this takes 5-8 min on first boot)..."
    (
        cd "${MODEL_DIR}"
        python3 -c "
from ultralytics import YOLO
YOLO('best.pt', task='detect').export(format='engine', imgsz=320, half=True, opset=19)
"
    )
    echo "[entrypoint] Engine compiled: $(ls -lh ${ENGINE} | awk '{print $5}')"
else
    echo "[entrypoint] Reusing cached engine: $(ls -lh ${ENGINE} | awk '{print $5}')"
fi

# exec replaces bash so SIGTERM from `docker stop` reaches Python (PID 1).
exec "$@"
