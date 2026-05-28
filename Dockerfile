# ─────────────────────────────────────────────────────────────
# Crystal DevOps Demo — Multi-Stage Dockerfile
# Stage 1: Build  → crystal:latest  (compila o binário)
# Stage 2: Runtime → alpine          (imagem mínima ~50MB)
# ─────────────────────────────────────────────────────────────

# ── Build Stage ──────────────────────────────────────────────
FROM crystallang/crystal:1.14-build AS builder

WORKDIR /app

# Copy dependency manifest first (cache layer optimization)
COPY shard.yml shard.lock* ./

# Install dependencies
RUN shards install --production

# Copy source code
COPY src/ ./src/

# Compile release binary (strip + no debug)
RUN crystal build src/main.cr \
    --release \
    --static \
    --no-debug \
    -o crystal-devops-demo

# ── Runtime Stage ─────────────────────────────────────────────
FROM alpine:3.19 AS runtime

# Install runtime dependencies only
RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    tzdata \
    curl

WORKDIR /app

# Copy compiled binary from builder
COPY --from=builder /app/crystal-devops-demo .

# Create non-root user (security best practice)
RUN addgroup -S crystal && adduser -S crystal -G crystal
USER crystal

# Expose port
EXPOSE 3000

# Health check (Kubernetes-ready)
HEALTHCHECK \
    --interval=15s \
    --timeout=5s \
    --start-period=10s \
    --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Metadata labels (DevOps best practice)
LABEL \
    org.opencontainers.image.title="Crystal DevOps Demo" \
    org.opencontainers.image.description="High-performance API in Crystal Lang" \
    org.opencontainers.image.version="1.0.0" \
    org.opencontainers.image.source="https://github.com/devops/crystal-demo"

# Run the compiled binary
ENTRYPOINT ["./crystal-devops-demo"]
