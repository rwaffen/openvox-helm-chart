{{/* Keep Kubernetes defaults while allowing SCC-assigned identities. */}}
{{- define "openvox.securityContext" -}}
{{- $settings := .root.Values.global.securityContexts -}}
{{- if not (has .key $settings.omit) -}}
{{- $context := deepCopy .legacy -}}
{{- if eq $settings.profile "restricted" -}}
{{- $context = omit $context "runAsUser" "runAsGroup" "fsGroup" "supplementalGroups" "seLinuxOptions" -}}
{{- $_ := set $context "runAsNonRoot" true -}}
{{- $_ := set $context "seccompProfile" (dict "type" "RuntimeDefault") -}}
{{- if not .pod -}}
{{- $_ := set $context "allowPrivilegeEscalation" false -}}
{{- $_ := set $context "capabilities" (dict "drop" (list "ALL")) -}}
{{- end -}}
{{- else if ne $settings.profile "legacy" -}}
{{- fail "global.securityContexts.profile must be legacy or restricted" -}}
{{- end -}}
{{- $defaults := ternary $settings.pod $settings.container .pod -}}
{{- $context = mergeOverwrite $context (deepCopy $defaults) (deepCopy (index $settings.overrides .key | default dict)) -}}
{{- with $context.capabilities -}}
{{- range $field := list "add" "drop" -}}
{{- if hasKey $context.capabilities $field -}}
{{- $names := list -}}
{{- range index $context.capabilities $field -}}
{{- $names = append $names (trimPrefix "CAP_" (upper .)) -}}
{{- end -}}
{{- $_ := set $context.capabilities $field (uniq $names) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- with $context }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "openvox.security.rootInit" -}}
runAsUser: 0
runAsNonRoot: false
capabilities:
  drop:
    - ALL
  add:
    - CHOWN
    - SETUID
    - SETGID
    - DAC_OVERRIDE
    - AUDIT_WRITE
    - FOWNER
{{- end -}}

{{- define "openvox.security.identity" -}}
{{- if .Values.global.runAsNonRoot }}
runAsUser: {{ .Values.global.securityContext.runAsUser }}
runAsGroup: {{ .Values.global.securityContext.runAsGroup }}
{{- else }}
{}
{{- end }}
{{- end -}}

{{- define "openvox.security.waiter" -}}
allowPrivilegeEscalation: false
runAsUser: 1000
runAsGroup: 1000
runAsNonRoot: true
{{- end -}}

{{- define "openvox.security.database" -}}
{{- toYaml .Values.puppetdb.securityContext | nindent 0 }}
{{- end -}}

{{- define "openvox.security.puppetboard" -}}
{{- toYaml (mergeOverwrite (dict "runAsUser" .Values.global.securityContext.runAsUser "runAsGroup" .Values.global.securityContext.runAsGroup) (deepCopy .Values.puppetboard.securityContext)) -}}
{{- end -}}

{{- define "openvox.security.openvoxview" -}}
{{- toYaml (mergeOverwrite (dict "runAsUser" .Values.global.securityContext.runAsUser "runAsGroup" .Values.global.securityContext.runAsGroup) (deepCopy .Values.openvoxview.securityContext)) -}}
{{- end -}}

{{- define "openvox.security.crl" -}}
{{- toYaml (mergeOverwrite (dict "runAsUser" .Values.global.securityContext.runAsUser "runAsGroup" .Values.global.securityContext.runAsGroup) (deepCopy .Values.singleCA.crl.securityContext)) -}}
{{- end -}}

{{- define "openvox.security.databaseExporter" -}}
runAsUser: 999
runAsGroup: 999
runAsNonRoot: true
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
{{- end -}}

{{- define "openvox.security.r10kPod" -}}
{{- toYaml (mergeOverwrite (dict "runAsUser" .Values.global.securityContext.runAsUser "runAsGroup" 0 "fsGroup" .Values.global.securityContext.fsGroup) (deepCopy .Values.r10k.podSecurityContext)) -}}
{{- end -}}

{{- define "openvox.security.r10kContainer" -}}
{{- toYaml .Values.r10k.containerSecurityContext | nindent 0 }}
{{- end -}}

{{- define "openvox.security.server" -}}
{{- if .Values.global.runAsNonRoot }}
runAsUser: {{ .Values.global.securityContext.runAsUser }}
runAsGroup: {{ .Values.global.securityContext.runAsGroup }}
runAsNonRoot: true
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
{{- else }}
{{- toYaml .Values.puppetserver.securityContext | nindent 0 }}
{{- end }}
{{- end -}}

{{- define "openvox.security.r10kCode" -}}
{{- $pod := pick .Values.r10k.podSecurityContext "runAsUser" "runAsGroup" "runAsNonRoot" "seLinuxOptions" "seccompProfile" -}}
{{- toYaml (mergeOverwrite (dict "runAsUser" .Values.global.securityContext.runAsUser "runAsGroup" 0) (deepCopy $pod) (deepCopy .Values.r10k.containerSecurityContext)) -}}
{{- end -}}

{{- define "openvox.security.r10kHiera" -}}
{{- $pod := pick .Values.r10k.podSecurityContext "runAsUser" "runAsGroup" "runAsNonRoot" "seLinuxOptions" "seccompProfile" -}}
{{- toYaml (mergeOverwrite (dict "runAsUser" .Values.global.securityContext.runAsUser "runAsGroup" .Values.global.securityContext.runAsGroup) (deepCopy $pod) (deepCopy .Values.r10k.containerSecurityContext)) -}}
{{- end -}}

{{- define "openvox.security.jmx" -}}
runAsUser: 64604
runAsGroup: 64604
runAsNonRoot: true
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
{{- end -}}

{{- define "openvox.security.serverPod" -}}
fsGroup: {{ .Values.global.securityContext.fsGroup }}
{{- end -}}
