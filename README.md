# Lab 12 — Edge AI CI/CD Pipeline

> Copyright (c) 2026 李軒杰 (I4A70) — Tatung University, I4210 AI實務

A complete GitHub Actions CI/CD pipeline that:
1. Runs **Ruff lint** + **Pytest smoke tests** on every push
2. Cross-compiles a **linux/arm64 Docker image** with QEMU/Buildx
3. Pushes to **GHCR** tagged with the commit SHA
4. Runs on **Jetson Orin Nano** — TensorRT engine compiled on first boot via `entrypoint.sh`

---

## Repository Structure

```
lab12/
├── .github/workflows/ci.yml   # CI/CD workflow (lint → test → build → push)
├── tests/
│   └── test_smoke.py          # CPU-only smoke tests (no GPU required)
├── Dockerfile.ci              # ARM64 image — engine compile deferred to runtime
├── entrypoint.sh              # Compiles TRT engine on first boot, reuses cache
├── inference_node.py          # YOLO TRT inference + MQTT publish
├── requirements.txt           # Python deps
├── best.pt                    # Fine-tuned YOLOv8 weights (committed to repo)
├── pyproject.toml             # PDM project config + ruff/pytest settings
├── .gitignore
├── validate_step0.sh          # Step validators (run on Jetson or laptop)
├── validate_step1.sh
├── validate_step2.sh
├── validate_step3.sh
├── validate_step4.sh
└── validate_step5.sh
```

---

## Quick Start

```bash
# Lint
pdm run lint

# Test (CPU-only, no GPU needed)
pdm run test

# Push to trigger CI
git push origin main
```

---

## Individual Reflection

### 李軒杰 (I4A70)

**What I worked on**

I designed and implemented the full CI/CD pipeline from scratch: the GitHub Actions workflow (`ci.yml`) with parallel lint and test jobs followed by a multi-architecture Docker build job using QEMU emulation. I also refactored the Dockerfile from Lab 10, removing the build-time `yolo export format=engine` command that required GPU access, and replaced it with `entrypoint.sh` which defers TensorRT engine compilation to container startup on the real Jetson hardware.

**Design decisions I made**

The key decision was where to place the TRT engine compilation. GitHub-hosted runners are x86 machines with no CUDA/GPU access, so calling `yolo export format=engine` inside a `RUN` layer would fail. Moving it to `entrypoint.sh` with a cache-check (`if best.engine doesn't exist or is older than best.pt → compile`) solves this cleanly: the first `docker run` on Jetson spends 5–8 minutes compiling, but every subsequent restart reuses the cached engine via a Docker volume (`lab12-models:/opt/models`). Using `exec "$@"` at the end of the entrypoint ensures SIGTERM reaches the Python process directly, enabling graceful shutdown.

**What surprised me or went wrong**

I initially underestimated how strict the QEMU cross-compilation path is. The `docker/build-push-action` must target `linux/arm64` explicitly, and the base image (`dustynv/pytorch:2.7-r36.4.0`) is roughly 7 GB, making the first CI build take 20–40 minutes even with layer caching. I also learned that `GITHUB_TOKEN` has package write permission by default but the published GHCR package starts as private — it must be manually set to Public (or the workflow policy adjusted) before the Jetson can `docker pull` without credentials.
