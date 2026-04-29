FROM golang:1.26.2-bookworm

ARG HELM_VERSION=v3.20.2
ARG CT_VERSION=v3.14.0
ARG KUBECTL_VERSION=v1.35.4
ARG HELM_UNITTEST_VERSION=v1.0.3

LABEL org.opencontainers.image.title="argo-workflows/helm-test" \
      org.opencontainers.image.description="Helm chart validation and test image for Argo Workflows tasks" \
      org.opencontainers.image.source="https://github.com/florisfeddema/homelab" \
      org.opencontainers.image.vendor="florisfeddema"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        python3 \
        yamllint \
    && rm -rf /var/lib/apt/lists/*

RUN arch="$(dpkg --print-architecture)" \
    && case "${arch}" in \
        amd64) bin_arch="amd64" ;; \
        arm64) bin_arch="arm64" ;; \
        *) echo "unsupported architecture: ${arch}" >&2; exit 1 ;; \
      esac \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${bin_arch}.tar.gz" -o /tmp/helm.tgz \
    && tar -xzf /tmp/helm.tgz -C /tmp \
    && mv "/tmp/linux-${bin_arch}/helm" /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && curl -fsSL "https://github.com/helm/chart-testing/releases/download/${CT_VERSION}/chart-testing_${CT_VERSION#v}_linux_${bin_arch}.tar.gz" -o /tmp/chart-testing.tgz \
    && tar -xzf /tmp/chart-testing.tgz -C /tmp \
    && mv /tmp/ct /usr/local/bin/ct \
    && chmod +x /usr/local/bin/ct \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${bin_arch}/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && helm plugin install https://github.com/helm-unittest/helm-unittest.git --version "${HELM_UNITTEST_VERSION}" \
    && rm -rf /tmp/helm.tgz /tmp/chart-testing.tgz /tmp/linux-"${bin_arch}"
