FROM golang:1.26.2-bookworm

LABEL org.opencontainers.image.title="argo-workflows/go" \
      org.opencontainers.image.description="Go-based utility image for Argo Workflows tasks" \
      org.opencontainers.image.source="https://github.com/florisfeddema/homelab" \
      org.opencontainers.image.vendor="florisfeddema"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        make \
    && rm -rf /var/lib/apt/lists/*
