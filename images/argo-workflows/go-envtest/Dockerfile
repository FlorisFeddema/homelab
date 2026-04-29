FROM golang:1.26.2-bookworm

ARG SETUP_ENVTEST_VERSION=release-0.22
ARG ENVTEST_K8S_VERSION=1.34.1

ENV KUBEBUILDER_ASSETS=/usr/local/kubebuilder/bin

LABEL org.opencontainers.image.title="argo-workflows/go-envtest" \
      org.opencontainers.image.description="Go-based envtest image for Argo Workflows tasks" \
      org.opencontainers.image.source="https://github.com/florisfeddema/homelab" \
      org.opencontainers.image.vendor="florisfeddema"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        git \
        make \
    && rm -rf /var/lib/apt/lists/*

RUN GOBIN=/usr/local/bin go install "sigs.k8s.io/controller-runtime/tools/setup-envtest@${SETUP_ENVTEST_VERSION}" \
    && mkdir -p "${KUBEBUILDER_ASSETS}" \
    && assets_dir="$(setup-envtest use -p path "${ENVTEST_K8S_VERSION}")" \
    && cp "${assets_dir}/"* "${KUBEBUILDER_ASSETS}/"
