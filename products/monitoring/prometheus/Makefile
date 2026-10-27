.PHONY: test-alerts

# Requires Helm dependencies (helm dependency build), yq v4, and promtool.
test-alerts:
	@set -eu; \
	workdir=$$(mktemp -d); \
	trap 'rm -rf "$$workdir"' EXIT; \
	helm template prometheus . --namespace prometheus --show-only templates/alerts.yaml > "$$workdir/rendered.yaml"; \
	yq '.spec' "$$workdir/rendered.yaml" > "$$workdir/rules.yaml"; \
	cp tests/thanos-upload-stalled.test.yaml "$$workdir/tests.yaml"; \
	promtool check rules "$$workdir/rules.yaml"; \
	promtool test rules "$$workdir/tests.yaml"
