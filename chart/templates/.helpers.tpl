{{- define "base.productName"  -}}
{{ default ( kebabcase .key ) .value.nameOverride }}
{{- end -}}
