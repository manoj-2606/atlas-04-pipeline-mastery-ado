# =============================================================================
# Multi-stage build — DevSecOps: non-root, minimal attack surface, < 100MB
# Build context: atlas-platform-app/ (pulled via multi-repo checkout)
# =============================================================================

# --- Stage 1: Build ---
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --timeout=120 --retries=10 \
    --target=/build/deps -r requirements.txt

# --- Stage 2: Runtime ---
FROM python:3.12-slim

# DevSecOps: non-root user
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /build/deps /usr/local/lib/python3.12/site-packages/

# Copy application code
COPY . .

# Own the app directory
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]