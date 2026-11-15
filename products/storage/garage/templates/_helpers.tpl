{{- define "garage.labels" -}}
app.kubernetes.io/name: garage
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "garage.selectorLabels" -}}
app.kubernetes.io/name: garage
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
