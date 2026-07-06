#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage: ./update-upstream.sh [git-ref]

Refresh the vendored upstream agent-sandbox chart files from
https://github.com/kubernetes-sigs/agent-sandbox/tree/main/helm.

The following files stay under local control and are not overwritten:
  - values.yaml
  - templates/servicemonitor.yaml

Everything else in this chart is refreshed from upstream, then the CRD
conversion webhook namespace is rewritten to this repo's deployed namespace
(`agent-sandbox`).
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

ref="${1:-main}"
repo="kubernetes-sigs/agent-sandbox"
archive_url="https://codeload.github.com/${repo}/tar.gz/${ref}"

script_dir=$(
  CDPATH= cd -- "$(dirname "$0")" && pwd
)
chart_dir="${script_dir}"

tmp_dir=$(mktemp -d)
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT INT TERM

archive_path="${tmp_dir}/agent-sandbox.tar.gz"
curl -fsSL "${archive_url}" -o "${archive_path}"
tar -xzf "${archive_path}" -C "${tmp_dir}"

upstream_root=$(find "${tmp_dir}" -mindepth 1 -maxdepth 1 -type d -name 'agent-sandbox-*' | head -n 1)
if [ -z "${upstream_root}" ]; then
  echo "Failed to locate extracted upstream archive for ref ${ref}" >&2
  exit 1
fi

upstream_chart="${upstream_root}/helm"
if [ ! -d "${upstream_chart}" ]; then
  echo "Upstream chart directory not found at ${upstream_chart}" >&2
  exit 1
fi

for required_path in Chart.yaml values.yaml crds templates files; do
  if [ ! -e "${upstream_chart}/${required_path}" ]; then
    echo "Upstream chart is missing ${required_path}; update script needs review" >&2
    exit 1
  fi
done

known_upstream_templates="
_controller-args.tpl
_helpers.tpl
clusterrolebinding-extensions.yaml
clusterrolebinding.yaml
deployment.yaml
extensions-rbac.generated.yaml
namespace.yaml
rbac.generated.yaml
role.yaml
rolebinding.yaml
service.yaml
serviceaccount.yaml
webhook-service.yaml
"

for template_path in "${upstream_chart}"/templates/*; do
  template_name=$(basename "${template_path}")
  case "${known_upstream_templates}" in
    *"
${template_name}
"*) ;;
    *)
      echo "Unhandled upstream template ${template_name}; review update-upstream.sh before continuing" >&2
      exit 1
      ;;
  esac
done

mkdir -p "${chart_dir}/crds" "${chart_dir}/files" "${chart_dir}/templates"
rm -rf "${chart_dir}/crds" "${chart_dir}/files"
mkdir -p "${chart_dir}/crds" "${chart_dir}/files"

cp "${upstream_chart}/Chart.yaml" "${chart_dir}/Chart.yaml"
cp -R "${upstream_chart}/crds/." "${chart_dir}/crds/"
cp -R "${upstream_chart}/files/." "${chart_dir}/files/"

for crd_path in "${chart_dir}"/crds/*.yaml; do
  tmp_crd="${tmp_dir}/$(basename "${crd_path}")"
  sed 's/namespace: agent-sandbox-system/namespace: agent-sandbox/g' "${crd_path}" > "${tmp_crd}"
  mv "${tmp_crd}" "${crd_path}"
done

copy_template() {
  upstream_name=$1
  local_name=$2
  cp "${upstream_chart}/templates/${upstream_name}" "${chart_dir}/templates/${local_name}"
}

copy_template "_controller-args.tpl" "_controller-args.tpl"
copy_template "_helpers.tpl" "_helpers.tpl"
copy_template "clusterrolebinding-extensions.yaml" "clusterrolebinding-extensions.yaml"
copy_template "clusterrolebinding.yaml" "clusterrolebinding.yaml"
copy_template "deployment.yaml" "deployment.yaml"
copy_template "extensions-rbac.generated.yaml" "extensions-rbac.yaml"
copy_template "namespace.yaml" "namespace.yaml"
copy_template "rbac.generated.yaml" "rbac.yaml"
copy_template "role.yaml" "role.yaml"
copy_template "rolebinding.yaml" "rolebinding.yaml"
copy_template "service.yaml" "service.yaml"
copy_template "serviceaccount.yaml" "serviceaccount.yaml"
copy_template "webhook-service.yaml" "webhook-service.yaml"

echo "Updated vendor-managed agent-sandbox chart files from ref ${ref}."
echo "Local overlay files were kept as-is:"
echo "  - values.yaml"
echo "  - templates/servicemonitor.yaml"
echo
echo "Recommended follow-up:"
echo "  1. Review git diff for values drift."
echo "  2. Run: helm template agent-sandbox ${chart_dir} --namespace agent-sandbox --include-crds >/dev/null"
