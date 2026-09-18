{{- define "openvox.network.dns" -}}
- to:
    - namespaceSelector:
        {{- toYaml .Values.global.networkPolicy.dnsNamespaceSelector | nindent 8 }}
      podSelector:
        {{- toYaml .Values.global.networkPolicy.dnsPodSelector | nindent 8 }}
  ports:
    {{- range .Values.global.networkPolicy.dnsPorts }}
    - protocol: TCP
      port: {{ . }}
    - protocol: UDP
      port: {{ . }}
    {{- end }}
{{- end -}}

{{- define "openvox.network.router" -}}
- from:
    - namespaceSelector:
        {{- toYaml .root.Values.global.networkPolicy.routerNamespaceSelector | nindent 8 }}
      podSelector:
        {{- toYaml .root.Values.global.networkPolicy.routerPodSelector | nindent 8 }}
  ports:
    - protocol: TCP
      port: {{ .port }}
{{- end -}}
