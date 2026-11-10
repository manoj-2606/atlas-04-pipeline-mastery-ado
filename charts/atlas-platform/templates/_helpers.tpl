{{/*
Chart name — used as resource name prefix
*/}}
{{- define "atlas-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname — includes release name for uniqueness
*/}}
{{- define "atlas-platform.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Standard labels — applied to every resource
*/}}
{{- define "atlas-platform.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "atlas-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used in matchLabels (immutable after creation)
*/}}
{{- define "atlas-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atlas-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}