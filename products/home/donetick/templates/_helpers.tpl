{{- define "donetick.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "donetick.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "donetick.labels" -}}
app.kubernetes.io/name: {{ include "donetick.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: donetick
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "donetick.selectorLabels" -}}
app.kubernetes.io/name: {{ include "donetick.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "donetick.hostname" -}}
{{- required "route.hostnames must contain at least one hostname" (first .Values.route.hostnames) -}}
{{- end -}}

{{- define "donetick.publicHost" -}}
{{- default (printf "https://%s" (include "donetick.hostname" .)) .Values.server.publicHost -}}
{{- end -}}

{{- define "donetick.oidcRedirectUrl" -}}
{{- default (printf "%s/api/v1/auth/oauth2/callback" (include "donetick.publicHost" .)) .Values.oidc.redirectUrl -}}
{{- end -}}

{{- define "donetick.storageBasePath" -}}
{{- if .Values.storage.basePath -}}
{{- .Values.storage.basePath -}}
{{- else if eq .Values.storage.type "local" -}}
/data/uploads
{{- else -}}
donetick
{{- end -}}
{{- end -}}
