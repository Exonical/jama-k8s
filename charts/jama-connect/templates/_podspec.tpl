{{/*
Common environment variables injected into every Jama component.
Call with (dict "ctx" $ "name" $name "comp" $comp).
Operator note: exact env var NAMES expected by Jama images must be confirmed
against the rendered KOTS manifests. These follow common conventions and are
overridable per-component via comp.env.
*/}}
{{- define "jama.commonEnv" -}}
- name: JAMA_FQDN
  value: {{ .ctx.Values.global.fqdn | quote }}
- name: JAMA_BASE_URL
  value: {{ printf "https://%s" .ctx.Values.global.fqdn | quote }}
{{- if .ctx.Values.database.host }}
- name: DB_TYPE
  value: {{ .ctx.Values.database.type | quote }}
- name: DB_HOST
  value: {{ .ctx.Values.database.host | quote }}
- name: DB_PORT
  value: {{ .ctx.Values.database.port | quote }}
- name: DB_NAME
  value: {{ .ctx.Values.database.names.core | quote }}
- name: DB_NAME_OAUTH
  value: {{ .ctx.Values.database.names.oauth | quote }}
- name: DB_NAME_SAML
  value: {{ .ctx.Values.database.names.saml | quote }}
{{- if .ctx.Values.database.existingSecret }}
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .ctx.Values.database.existingSecret }}
      key: {{ .ctx.Values.database.usernameKey }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .ctx.Values.database.existingSecret }}
      key: {{ .ctx.Values.database.passwordKey }}
{{- end }}
{{- end }}
- name: ELASTICSEARCH_HOST
  value: "elasticsearch"
- name: ELASTICSEARCH_PORT
  value: "9200"
- name: ACTIVEMQ_HOST
  value: "activemq"
- name: HAZELCAST_HOST
  value: "hazelcast"
{{- if and .ctx.Values.smtp.enabled .ctx.Values.smtp.host }}
- name: SMTP_HOST
  value: {{ .ctx.Values.smtp.host | quote }}
- name: SMTP_PORT
  value: {{ .ctx.Values.smtp.port | quote }}
- name: SMTP_FROM
  value: {{ .ctx.Values.smtp.fromAddress | quote }}
- name: SMTP_TLS
  value: {{ .ctx.Values.smtp.tls | quote }}
{{- if and .ctx.Values.smtp.auth .ctx.Values.smtp.existingSecret }}
- name: SMTP_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .ctx.Values.smtp.existingSecret }}
      key: {{ .ctx.Values.smtp.usernameKey }}
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .ctx.Values.smtp.existingSecret }}
      key: {{ .ctx.Values.smtp.passwordKey }}
{{- end }}
{{- end }}
{{- if eq .name "elasticsearch" }}
- name: ES_JAVA_OPTS
  value: {{ printf "-Xms%s -Xmx%s" .ctx.Values.elasticsearch.heapSize .ctx.Values.elasticsearch.heapSize | quote }}
- name: discovery.seed_hosts
  value: "elasticsearch-discovery"
{{- end }}
{{- with .comp.env }}
{{ toYaml . }}
{{- end }}
{{- end -}}


{{/*
Whether this component mounts the Jama license (core tier).
*/}}
{{- define "jama.mountsLicense" -}}
{{- if and .ctx.Values.license.existingSecret (hasPrefix "core" .name) -}}true{{- end -}}
{{- end -}}


{{/*
Pod template block (the `template:` key for a StatefulSet/Deployment).
Call with (dict "ctx" $ "name" $name "comp" $comp).
*/}}
{{- define "jama.podTemplate" -}}
{{- $ctx := .ctx -}}
{{- $name := .name -}}
{{- $comp := .comp -}}
template:
  metadata:
    labels:
      {{- include "jama.componentSelectorLabels" (dict "ctx" $ctx "name" $name) | nindent 6 }}
    {{- with $comp.podAnnotations }}
    annotations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  spec:
    serviceAccountName: {{ include "jama.serviceAccountName" $ctx }}
    {{- include "jama.imagePullSecrets" $ctx | nindent 4 }}
    securityContext:
      {{- toYaml $ctx.Values.podSecurityContext | nindent 6 }}
    {{- with $comp.nodeSelector }}
    nodeSelector:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $comp.tolerations }}
    tolerations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $comp.affinity }}
    affinity:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if and (eq $name "elasticsearch") $comp.sysctlInitContainer }}
    initContainers:
      - name: sysctl
        image: busybox:1.36
        securityContext:
          privileged: true
          runAsNonRoot: false
        command: ["sh", "-c", "sysctl -w vm.max_map_count=262144 || true"]
    {{- end }}
    containers:
      - name: {{ $name }}
        image: {{ include "jama.image" (dict "ctx" $ctx "image" $comp.image) | quote }}
        imagePullPolicy: {{ $ctx.Values.global.imagePullPolicy }}
        securityContext:
          {{- toYaml $ctx.Values.securityContext | nindent 10 }}
        {{- with $comp.command }}
        command: {{ toYaml . | nindent 10 }}
        {{- end }}
        {{- with $comp.args }}
        args: {{ toYaml . | nindent 10 }}
        {{- end }}
        {{- with $comp.ports }}
        ports:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        env:
          {{- include "jama.commonEnv" (dict "ctx" $ctx "name" $name "comp" $comp) | nindent 10 }}
        envFrom:
          - configMapRef:
              name: {{ include "jama.fullname" $ctx }}-config
        {{- with $comp.readinessProbe }}
        readinessProbe:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $comp.livenessProbe }}
        livenessProbe:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $comp.startupProbe }}
        startupProbe:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $comp.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        volumeMounts:
          {{- if $comp.persistence.enabled }}
          - name: volume
            mountPath: {{ $comp.persistence.mountPath }}
          {{- end }}
          {{- if $comp.mountTenantfs }}
          - name: tenantfs
            mountPath: {{ $ctx.Values.sharedStorage.tenantfs.mountPath }}
          {{- end }}
          {{- if eq (include "jama.mountsLicense" (dict "ctx" $ctx "name" $name)) "true" }}
          - name: license
            mountPath: {{ $ctx.Values.license.mountPath }}
            readOnly: true
          {{- end }}
          {{- with $comp.extraVolumeMounts }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
    volumes:
      {{- if and $comp.persistence.enabled (eq $comp.kind "Deployment") }}
      - name: volume
        persistentVolumeClaim:
          claimName: volume-{{ $name }}-0
      {{- end }}
      {{- if $comp.mountTenantfs }}
      - name: tenantfs
        persistentVolumeClaim:
          claimName: {{ $ctx.Values.sharedStorage.tenantfs.existingClaim | default $ctx.Values.sharedStorage.tenantfs.name }}
      {{- end }}
      {{- if eq (include "jama.mountsLicense" (dict "ctx" $ctx "name" $name)) "true" }}
      - name: license
        secret:
          secretName: {{ $ctx.Values.license.existingSecret }}
      {{- end }}
      {{- with $comp.extraVolumes }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
{{- end -}}
