{{/*
Return the effective nodeSelector for a workload — empty if nodeName is "".
Usage:  {{- include "vibekanban.nodeSelector" . | nindent 6 }}
*/}}
{{- define "vibekanban.nodeSelector" -}}
{{- if .Values.nodeName -}}
nodeSelector:
  kubernetes.io/hostname: {{ .Values.nodeName | quote }}
{{- end -}}
{{- end -}}
