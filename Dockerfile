# syntax=docker/dockerfile:1
FROM rust:1-slim-bookworm AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y pkg-config libssl-dev perl make && rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY xtask ./xtask
COPY agents ./agents
COPY packages ./packages
# Optional build args for dev environments to speed up compilation
ARG LTO=true
ARG CODEGEN_UNITS=1
ENV CARGO_PROFILE_RELEASE_LTO=${LTO} \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=${CODEGEN_UNITS}
RUN cargo build --release --bin openfang

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/target/release/openfang /usr/local/bin/
COPY --from=builder /build/agents /opt/openfang/agents

# Railway injects $PORT — map it to OPENFANG_LISTEN so the daemon binds correctly.
# OPENFANG_ALLOW_NO_AUTH=1 permits non-loopback traffic without an api_key configured.
ENV OPENFANG_HOME=/data \
    OPENFANG_ALLOW_NO_AUTH=1

EXPOSE 4200
VOLUME /data

ENTRYPOINT ["sh", "-c", "OPENFANG_LISTEN=0.0.0.0:${PORT:-4200} openfang start"]
