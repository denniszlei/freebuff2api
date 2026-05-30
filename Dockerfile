# syntax=docker/dockerfile:1

# ---- builder: install locked deps into /app/.venv ----------------------------
FROM python:3.13-slim AS builder

# Bring in the uv binary (pinned, multi-arch) just for dependency installation.
COPY --from=ghcr.io/astral-sh/uv:0.11.17 /uv /bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app

# Install third-party dependencies only (not the project itself) so this layer
# stays cached across source changes. Every dependency ships as a prebuilt wheel
# for both amd64 and arm64, so no build toolchain is needed.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

# ---- runtime: slim image with just the venv + source -------------------------
FROM python:3.13-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH" \
    FREEBUFF_HOST=0.0.0.0 \
    FREEBUFF_PORT=8000

WORKDIR /app

# Prebuilt virtualenv from the builder stage.
COPY --from=builder /app/.venv /app/.venv

# Application source — run directly via `python main.py` (CWD is on sys.path,
# so `freebuff2api.app:app` resolves without installing the project).
COPY main.py ./
COPY freebuff2api ./freebuff2api

EXPOSE 8000

# Auth-independent liveness check (works whether or not FREEBUFF_API_KEY is set).
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import os,socket; socket.create_connection(('127.0.0.1', int(os.environ.get('FREEBUFF_PORT','8000'))), timeout=3).close()"]

CMD ["python", "main.py"]
