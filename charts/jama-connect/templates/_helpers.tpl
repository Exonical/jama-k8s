{{/*
Expand the name of the chart.
*/}}
{{- define "jama.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name.
*/}}
{{- define "jama.fullname" -}}
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

{{- define "jama.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Namespace to deploy into.
*/}}
{{- define "jama.namespace" -}}
{{- if .Values.namespace.name -}}
{{- .Values.namespace.name -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "jama.labels" -}}
helm.sh/chart: {{ include "jama.chart" . }}
{{ include "jama.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: jama-connect
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels (instance-level).
*/}}
{{- define "jama.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jama.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Per-component labels. Call with (dict "ctx" $ "name" $componentName).
*/}}
{{- define "jama.componentLabels" -}}
{{ include "jama.labels" .ctx }}
app.kubernetes.io/component: {{ .name }}
{{- end -}}

{{/*
Per-component selector labels.
*/}}
{{- define "jama.componentSelectorLabels" -}}
{{ include "jama.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .name }}
{{- end -}}

{{/*
ServiceAccount name.
*/}}
{{- define "jama.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "jama.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Resolve a component image reference. Call with (dict "ctx" $ "image" $component.image).
Precedence: component tag -> global.imageTag -> .Chart.AppVersion.
Registry: global.imageRegistry prefix (if set and repo is not already fully qualified).
*/}}
{{- define "jama.image" -}}
{{- $ctx := .ctx -}}
{{- $img := .image -}}
{{- $registry := $ctx.Values.global.imageRegistry -}}
{{- $repo := $img.repository -}}
{{- $tag := $img.tag | default $ctx.Values.global.imageTag | default $ctx.Chart.AppVersion -}}
{{/* First path segment is a registry host if it has a "." or ":" or is "localhost". */}}
{{- $firstSegment := regexReplaceAll "/.*" $repo "" -}}
{{- $isQualified := or (contains "." $firstSegment) (contains ":" $firstSegment) (eq $firstSegment "localhost") -}}
{{- if and $registry (not $isQualified) -}}
{{- printf "%s/%s:%s" (trimSuffix "/" $registry) $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end -}}

{{/*
imagePullSecrets block. Combines global.imagePullSecrets with a created one.
*/}}
{{- define "jama.imagePullSecrets" -}}
{{- $secrets := list -}}
{{- range .Values.global.imagePullSecrets -}}
{{- $secrets = append $secrets .name -}}
{{- end -}}
{{- if .Values.imagePullSecret.create -}}
{{- $secrets = append $secrets .Values.imagePullSecret.name -}}
{{- end -}}
{{- if $secrets -}}
imagePullSecrets:
{{- range $secrets | uniq }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Resolve the StorageClass for a PVC. Call with (dict "ctx" $ "sc" $overrideStorageClass).
Returns a fully-formed storageClassName line or nothing (cluster default).
*/}}
{{- define "jama.storageClass" -}}
{{- $sc := .sc | default .ctx.Values.global.storageClass -}}
{{- if $sc -}}
storageClassName: {{ $sc }}
{{- end -}}
{{- end -}}

{{/*
Database JDBC host:port helper.
*/}}
{{- define "jama.dbEndpoint" -}}
{{- printf "%s:%v" .Values.database.host (.Values.database.port | toString) -}}
{{- end -}}
