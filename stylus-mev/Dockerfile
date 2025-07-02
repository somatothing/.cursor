# Multi-stage build for Arbitrum Stylus MEV Bot
FROM rust:1.75-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libclang-dev \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install WASM target for Stylus
RUN rustup target add wasm32-unknown-unknown

# Install Stylus CLI tools
RUN cargo install --git https://github.com/OffchainLabs/cargo-stylus cargo-stylus

# Set working directory
WORKDIR /app

# Copy dependency manifests
COPY Cargo.toml Cargo.lock ./

# Create dummy main to cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release --target wasm32-unknown-unknown
RUN rm -rf src

# Copy source code
COPY src ./src

# Build the application
RUN cargo build --release --target wasm32-unknown-unknown

# Build native binary for monitoring/API
RUN cargo build --release --bin mev-monitor

# Production stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -r -s /bin/false -m -d /app mev

# Set working directory
WORKDIR /app

# Copy built artifacts
COPY --from=builder /app/target/wasm32-unknown-unknown/release/*.wasm ./contracts/
COPY --from=builder /app/target/release/mev-monitor ./bin/
COPY --from=builder /usr/local/cargo/bin/cargo-stylus ./bin/

# Copy configuration and scripts
COPY config ./config
COPY scripts ./scripts
COPY monitoring ./monitoring

# Create necessary directories
RUN mkdir -p logs data reports && \
    chown -R mev:mev /app

# Switch to app user
USER mev

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose ports
EXPOSE 8080 9090

# Default command
CMD ["./bin/mev-monitor"]