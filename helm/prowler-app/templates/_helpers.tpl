{{- define "prowler-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "prowler-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "prowler-app.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "prowler-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "prowler-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "prowler-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "prowler-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "prowler-app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "prowler-app.apiImage" -}}
{{- printf "%s:%s" .Values.images.api.repository .Values.images.api.tag -}}
{{- end -}}

{{- define "prowler-app.uiImage" -}}
{{- printf "%s:%s" .Values.images.ui.repository .Values.images.ui.tag -}}
{{- end -}}

{{- define "prowler-app.mcpImage" -}}
{{- printf "%s:%s" .Values.images.mcp.repository .Values.images.mcp.tag -}}
{{- end -}}

{{- define "prowler-app.valkeyHost" -}}
{{- if .Values.valkey.enabled -}}
{{- printf "%s-valkey" (include "prowler-app.fullname" .) -}}
{{- else -}}
{{- required "valkey.host is required when valkey.enabled=false" .Values.valkey.host -}}
{{- end -}}
{{- end -}}

{{- define "prowler-app.secretName" -}}
{{- if .Values.app.secrets.existingSecret -}}
{{- .Values.app.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" (include "prowler-app.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "prowler-app.postgresSecretName" -}}
{{- if .Values.postgres.existingSecret -}}
{{- .Values.postgres.existingSecret -}}
{{- else -}}
{{- required "postgres.existingSecret is required" .Values.postgres.existingSecret -}}
{{- end -}}
{{- end -}}
