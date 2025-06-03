ARG BASE_IMAGE_VERSION="3"
FROM mcr.microsoft.com/devcontainers/universal:${BASE_IMAGE_VERSION}

ARG KUBESEAL_VERION="0.19.2"
RUN wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERION}/kubeseal-${KUBESEAL_VERION}-linux-amd64.tar.gz && \
  tar -xvzf kubeseal-${KUBESEAL_VERION}-linux-amd64.tar.gz kubeseal && \
  sudo install -m 755 kubeseal /usr/local/bin/kubeseal && \
  rm -rf kubeseal-${KUBESEAL_VERION}-linux-amd64.tar.gz kubeseal

ARG VELERO_VERION="1.9.5"
RUN wget https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERION}/velero-v${VELERO_VERION}-linux-amd64.tar.gz && \
  tar -xvzf velero-v${VELERO_VERION}-linux-amd64.tar.gz && \
  sudo install -m 755 velero-v${VELERO_VERION}-linux-amd64/velero /usr/local/bin/velero && \
  rm -rf velero-v${VELERO_VERION}-linux-amd64/velero velero-v${VELERO_VERION}-linux-amd64.tar.gz
