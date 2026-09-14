FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG TARGETARCH
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.53.6
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.37.0
# renovate: datasource=github-releases depName=argoproj/argo-cd
ARG ARGOCD_VERSION=v3.5.3
# renovate: datasource=github-releases depName=siderolabs/talos
ARG TALOS_VERSION=v1.14.0
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v4.3.0
# renovate: datasource=github-releases depName=bitnami-labs/sealed-secrets
ARG KUBESEAL_VERSION=v0.40.0
# renovate: datasource=github-releases depName=ahmetb/kubectx
ARG KUBENS_VERSION=v0.11.0
# renovate: datasource=github-releases depName=stern/stern
ARG STERN_VERSION=v1.34.0
# renovate: datasource=github-releases depName=github/copilot-cli
ARG COPILOT_VERSION=v1.0.83
# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=v2.100.0

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*

RUN install -d --owner=vscode --group=vscode /home/vscode/.copilot \
    && ln -s /home/vscode/.config/homelab-devcontainer/mcp-config.json /home/vscode/.copilot/mcp-config.json

RUN install_script="$(mktemp)" \
    && curl --fail --location --silent --show-error \
        --output "${install_script}" \
        https://gh.io/copilot-install \
    && VERSION="${COPILOT_VERSION}" bash "${install_script}" \
    && rm -f "${install_script}"

RUN case "${TARGETARCH}" in \
        amd64) arch="amd64"; kubectx_arch="x86_64" ;; \
        arm64) arch="arm64"; kubectx_arch="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && temp_dir="$(mktemp -d)" \
    && curl --fail --location --silent --show-error \
        --output /usr/local/bin/yq \
        "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}" \
    && curl --fail --location --silent --show-error \
        --output /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" \
    && curl --fail --location --silent --show-error \
        --output /usr/local/bin/argocd \
        "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${arch}" \
    && curl --fail --location --silent --show-error \
        --output /usr/local/bin/talosctl \
        "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-${arch}" \
    && curl --fail --location --silent --show-error \
        --output "${temp_dir}/helm.tar.gz" \
        "https://get.helm.sh/helm-${HELM_VERSION}-linux-${arch}.tar.gz" \
    && tar --extract --gzip --file "${temp_dir}/helm.tar.gz" --directory "${temp_dir}" \
    && install "${temp_dir}/linux-${arch}/helm" /usr/local/bin/helm \
    && curl --fail --location --silent --show-error \
        --output "${temp_dir}/kubeseal.tar.gz" \
        "https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION#v}-linux-${arch}.tar.gz" \
    && tar --extract --gzip --file "${temp_dir}/kubeseal.tar.gz" --directory "${temp_dir}" \
    && install "${temp_dir}/kubeseal" /usr/local/bin/kubeseal \
    && curl --fail --location --silent --show-error \
        --output "${temp_dir}/kubens.tar.gz" \
        "https://github.com/ahmetb/kubectx/releases/download/${KUBENS_VERSION}/kubens_${KUBENS_VERSION}_linux_${kubectx_arch}.tar.gz" \
    && tar --extract --gzip --file "${temp_dir}/kubens.tar.gz" --directory "${temp_dir}" \
    && install "${temp_dir}/kubens" /usr/local/bin/kubens \
    && curl --fail --location --silent --show-error \
        --output "${temp_dir}/stern.tar.gz" \
        "https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#v}_linux_${arch}.tar.gz" \
    && tar --extract --gzip --file "${temp_dir}/stern.tar.gz" --directory "${temp_dir}" \
    && install "${temp_dir}/stern" /usr/local/bin/stern \
    && curl --fail --location --silent --show-error \
        --output "${temp_dir}/gh.tar.gz" \
        "https://github.com/cli/cli/releases/download/${GH_VERSION}/gh_${GH_VERSION#v}_linux_${arch}.tar.gz" \
    && tar --extract --gzip --file "${temp_dir}/gh.tar.gz" --directory "${temp_dir}" \
    && install "${temp_dir}/gh_${GH_VERSION#v}_linux_${arch}/bin/gh" /usr/local/bin/gh \
    && rm -rf "${temp_dir}" \
    && chmod +x /usr/local/bin/argocd /usr/local/bin/yq /usr/local/bin/kubectl /usr/local/bin/talosctl
