# Woow_k3s_vibekanban

**Helm chart** for deploying [Vibe Kanban](https://github.com/BloopAI/vibe-kanban) on K3s / Kubernetes.

This repository contains **only the K3s / Kubernetes deployment**. For other platforms, see the sibling repositories:

| Platform | Repository | Notes |
|---------|-----------|-------|
| **K3s / Kubernetes (this repo)** | `Woow_k3s_vibekanban` | Helm chart at repo root |
| **Podman on Ubuntu host** | [`Woow_podman_vibekanban`](https://github.com/WOOWTECH/Woow_podman_vibekanban) | systemd-managed containers |
| ~~Home Assistant add-on~~ | *(not available)* | Vibe Kanban is not shipped as an HA add-on |

[繁體中文說明 →](README_zh-TW.md)

---

## What you get

A single Helm release brings up the full Vibe Kanban stack on your cluster:

| Component | Image | Purpose |
|-----------|-------|---------|
| **vk-db** | `postgres:16-alpine` | PostgreSQL 16 with `wal_level=logical` (ElectricSQL requirement) |
| **vk-remote** | `localhost/vk-remote:v0.1.43` | Web UI + REST API (port 8081) |
| **vk-electric** | `electricsql/electric:1.4.13` | Real-time sync engine (port 3000) |
| **vk-relay** | `localhost/vk-relay:v0.1.43` | WebSocket relay for the host (port 8082) |
| **vk-host** | `localhost/vk-host:v0.1.43` | Vibe Kanban Host + Claude Code + OpenCode + 50 CLI tools |
| ├─ *sidecar* openchamber | `localhost/openchamber:latest` | OpenCode Web GUI (port 1920→3080) |
| └─ *sidecar* mcp-service | `localhost/vk-mcp:v1.0` | 33-tool MCP server + admin UI (ports 8000, 8080) |
| **vk-terminal** | `ubuntu:24.04` + ttyd | Browser terminal that `kubectl exec`s into the host (port 7681) |
| **vk-cloudflared** | `cloudflare/cloudflared:latest` | Cloudflare Tunnel |

Plus: NetworkPolicies isolating the DB, PVCs (`local-path` for stateful data, `nfs-data` for the workspace by default), an in-cluster `ServiceAccount` + `Role` for the terminal to exec into the host pod, and pre-built ConfigMaps carrying `install-tools.sh` (179 lines, verbatim from the original manifests) and the OpenCode provider config.

---

## Quick start

### Prerequisites

- Helm 3.x
- A K3s / Kubernetes cluster (1.24+)
- The private images pre-loaded on your node(s):
  - `localhost/vk-remote:v0.1.43`
  - `localhost/vk-relay:v0.1.43`
  - `localhost/vk-host:v0.1.43`
  - `localhost/openchamber:latest`
  - `localhost/vk-mcp:v1.0`

  Use `build-vk-images.sh` from the archived Kustomize tree (see git history), or your own build pipeline.

### Install straight from GitHub

```bash
helm install vibekanban \
  https://github.com/WOOWTECH/Woow_k3s_vibekanban/archive/refs/heads/main.tar.gz \
  --set secrets.vibekanbanRemoteJwtSecret="$(openssl rand -base64 48)" \
  --set secrets.electricRolePassword="$(openssl rand -base64 24)" \
  --set secrets.postgresPassword="$(openssl rand -base64 24)" \
  --set secrets.selfHostLocalAuthPassword="$YOUR_UI_PASSWORD" \
  --set secrets.cloudflareTunnelToken="$CF_TOKEN"
```

### Install from a local clone

```bash
git clone https://github.com/WOOWTECH/Woow_k3s_vibekanban.git
cd Woow_k3s_vibekanban
helm install vibekanban . -f your-overrides.yaml
```

Verify:

```bash
kubectl -n vibe-kanban get pods
kubectl -n vibe-kanban rollout status deploy/vk-remote
```

---

## Key values

Every default in [`values.yaml`](values.yaml) reproduces the original Kustomize deployment 1:1. Common knobs:

| Key | Default | Notes |
|---|---|---|
| `namespace.create` | `true` | Set to `false` if the namespace is managed elsewhere |
| `namespace.name` | `vibe-kanban` | **Kept as-is** for compatibility with the original deployment |
| `nodeName` | `woowtechcluster1-aorus-15p-xd` | Every workload is pinned here. Set to `""` to run wherever the scheduler chooses |
| `postgres.persistence.storageClassName` | `local-path` | K3s default |
| `postgres.persistence.size` | `10Gi` | |
| `host.workspace.persistence.storageClassName` | `nfs-data` | Override for clusters without NFS |
| `host.workspace.persistence.size` | `20Gi` | |
| `host.openchamber.enabled` | `true` | OpenCode Web GUI sidecar |
| `host.mcp.enabled` | `true` | MCP service sidecar |
| `terminal.enabled` | `true` | Browser ttyd shell |
| `cloudflared.enabled` | `true` | Cloudflare Tunnel |
| `networkPolicies.enabled` | `true` | DB isolation + per-service ingress |
| `config.publicBaseUrl` | `https://woowtechkxs-vibekanban.woowtech.io` | External URL routed via CF Tunnel |
| `config.relayPublicUrl` | `https://woowtechkxs-vibekanban-relay.woowtech.io` | External Relay URL |
| `secrets.*` | `<GENERATE_ME>` | Override with `--set` or a values file. Never commit real secrets |

Image tags follow the `<component>.image.tag` pattern (e.g. `remote.image.tag=v0.1.43`).

---

## Uninstall

```bash
helm uninstall vibekanban
# PVCs are NOT deleted automatically — remove them if you want to wipe state:
kubectl -n vibe-kanban delete pvc vk-db-pvc vk-workspace-pvc vk-electric-pvc
# If the namespace was created by the chart:
kubectl delete namespace vibe-kanban
```

---

## Migrating from the old Kustomize tree

The previous layout (`k8s-manifests/vibe-kanban/00-namespace.yaml` … `11-terminal.yaml` + `kustomization.yaml`) has been replaced by this Helm chart. The rendered manifests are semantically identical, with two intentional differences:

1. Helm injects `app.kubernetes.io/managed-by: Helm` and release metadata labels/annotations on every resource.
2. Every container now carries an explicit `imagePullPolicy` (Kubernetes would apply the same default; making it explicit avoids ambiguity).

Everything else — image tags, resource limits, volume mounts, environment variables, ports, the two 100+ line ConfigMap payloads (`install-tools.sh`, `opencode.json`) — is byte-identical.

---

## License

See [LICENSE](LICENSE).
