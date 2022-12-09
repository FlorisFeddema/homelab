ARG BASE_IMAGE_VERSION="2"
FROM mcr.microsoft.com/devcontainers/universal:${BASE_IMAGE_VERSION}

ARG KUBESEAL_VERION="0.19.2"
RUN wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERION}/kubeseal-${KUBESEAL_VERION}-linux-amd64.tar.gz && \
  tar -xvzf kubeseal-${KUBESEAL_VERION}-linux-amd64.tar.gz kubeseal && \
  sudo install -m 755 kubeseal /usr/local/bin/kubeseal && \
  rm kubeseal-${KUBESEAL_VERION}-linux-amd64.tar.gz kubeseal
