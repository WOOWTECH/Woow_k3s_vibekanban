> [!WARNING]
> **已停用 / Deprecated（2026-09-12）**：這個 repo 已不再維護，也不再部署在 WOOWTECH 的叢集上，僅保留作為歷史參考。
> This repository is no longer maintained or deployed on WOOWTECH clusters and is kept for reference only.

# Woow_k3s_vibekanban

在 K3s / Kubernetes 上部署 [Vibe Kanban](https://github.com/BloopAI/vibe-kanban) 的 **Helm chart**。

本 repo **只放 K3s / Kubernetes 部署**。其他平台請看對應的姊妹 repo：

| 平台 | Repository | 說明 |
|---------|-----------|-------|
| **K3s / Kubernetes（本 repo）** | `Woow_k3s_vibekanban` | Helm chart 放在 repo root |
| **Ubuntu host 上的 Podman** | [`Woow_podman_vibekanban`](https://github.com/WOOWTECH/Woow_podman_vibekanban) | 由 systemd 管理的容器 |
| ~~Home Assistant add-on~~ | *(沒有)* | Vibe Kanban 不做成 HA add-on |

[English README →](README.md)

---

## 你會拿到什麼

一次 `helm install`，整套 Vibe Kanban 就會在 cluster 上啟起來：

| 元件 | Image | 用途 |
|-----------|-------|---------|
| **vk-db** | `postgres:16-alpine` | PostgreSQL 16，`wal_level=logical`（ElectricSQL 需要） |
| **vk-remote** | `localhost/vk-remote:v0.1.43` | Web UI + REST API（port 8081） |
| **vk-electric** | `electricsql/electric:1.4.13` | 即時同步引擎（port 3000） |
| **vk-relay** | `localhost/vk-relay:v0.1.43` | Host 用的 WebSocket relay（port 8082） |
| **vk-host** | `localhost/vk-host:v0.1.43` | Vibe Kanban Host + Claude Code + OpenCode + 50 個 CLI 工具 |
| ├─ *sidecar* openchamber | `localhost/openchamber:latest` | OpenCode Web GUI（port 1920→3080） |
| └─ *sidecar* mcp-service | `localhost/vk-mcp:v1.0` | 33 個工具的 MCP server + admin UI（ports 8000, 8080） |
| **vk-terminal** | `ubuntu:24.04` + ttyd | 瀏覽器 terminal，用 `kubectl exec` 進 host（port 7681） |
| **vk-cloudflared** | `cloudflare/cloudflared:latest` | Cloudflare Tunnel |

另外還有：隔離 DB 的 NetworkPolicy、PVC（stateful 資料用 `local-path`、workspace 預設用 `nfs-data`）、給 terminal 用來 exec 進 host pod 的 in-cluster `ServiceAccount` + `Role`，以及兩份大 ConfigMap（`install-tools.sh` 179 行、`opencode.json`）都跟原本 manifest 一模一樣。

---

## 快速開始

### 前置需求

- Helm 3.x
- K3s / Kubernetes cluster（1.24 以上）
- 節點上要先有以下 private image：
  - `localhost/vk-remote:v0.1.43`
  - `localhost/vk-relay:v0.1.43`
  - `localhost/vk-host:v0.1.43`
  - `localhost/openchamber:latest`
  - `localhost/vk-mcp:v1.0`

  可以用舊 Kustomize tree 裡的 `build-vk-images.sh`（在 git 歷史中），或你自己的 build pipeline。

### 直接從 GitHub 安裝

```bash
helm install vibekanban \
  https://github.com/WOOWTECH/Woow_k3s_vibekanban/archive/refs/heads/main.tar.gz \
  --set secrets.vibekanbanRemoteJwtSecret="$(openssl rand -base64 48)" \
  --set secrets.electricRolePassword="$(openssl rand -base64 24)" \
  --set secrets.postgresPassword="$(openssl rand -base64 24)" \
  --set secrets.selfHostLocalAuthPassword="$YOUR_UI_PASSWORD" \
  --set secrets.cloudflareTunnelToken="$CF_TOKEN"
```

### 從 local clone 安裝

```bash
git clone https://github.com/WOOWTECH/Woow_k3s_vibekanban.git
cd Woow_k3s_vibekanban
helm install vibekanban . -f your-overrides.yaml
```

驗證：

```bash
kubectl -n vibe-kanban get pods
kubectl -n vibe-kanban rollout status deploy/vk-remote
```

---

## 常用 values

[`values.yaml`](values.yaml) 的所有預設值都跟原本的 Kustomize 部署 1:1 對齊。常改的：

| Key | 預設值 | 說明 |
|---|---|---|
| `namespace.create` | `true` | 如果 namespace 由其他地方管，設 `false` |
| `namespace.name` | `vibe-kanban` | **保留原名**，跟舊部署相容 |
| `nodeName` | `woowtechcluster1-aorus-15p-xd` | 每個 workload 都 pin 在這個節點。設成 `""` 就交給 scheduler |
| `postgres.persistence.storageClassName` | `local-path` | K3s 預設 |
| `postgres.persistence.size` | `10Gi` | |
| `host.workspace.persistence.storageClassName` | `nfs-data` | 沒有 NFS 的 cluster 要改 |
| `host.workspace.persistence.size` | `20Gi` | |
| `host.openchamber.enabled` | `true` | OpenCode Web GUI sidecar |
| `host.mcp.enabled` | `true` | MCP service sidecar |
| `terminal.enabled` | `true` | 瀏覽器 ttyd shell |
| `cloudflared.enabled` | `true` | Cloudflare Tunnel |
| `networkPolicies.enabled` | `true` | DB 隔離 + 各 service ingress 規則 |
| `config.publicBaseUrl` | `https://woowtechkxs-vibekanban.woowtech.io` | 走 CF Tunnel 的對外 URL |
| `config.relayPublicUrl` | `https://woowtechkxs-vibekanban-relay.woowtech.io` | Relay 對外 URL |
| `secrets.*` | `<GENERATE_ME>` | 用 `--set` 或 values file 覆蓋。**永遠不要 commit 真的密碼** |

Image tag 用 `<component>.image.tag` 的形式覆蓋（例如 `remote.image.tag=v0.1.43`）。

---

## 移除

```bash
helm uninstall vibekanban
# PVC 不會被自動刪除 — 要清資料就自己動手：
kubectl -n vibe-kanban delete pvc vk-db-pvc vk-workspace-pvc vk-electric-pvc
# 如果 namespace 是 chart 建的：
kubectl delete namespace vibe-kanban
```

---

## 從舊 Kustomize tree 遷移

舊的結構（`k8s-manifests/vibe-kanban/00-namespace.yaml` … `11-terminal.yaml` + `kustomization.yaml`）已經被這個 Helm chart 取代。渲染出來的 manifest 語意上是等價的，只有兩個刻意的差別：

1. Helm 會在每個 resource 加上 `app.kubernetes.io/managed-by: Helm` 及 release 相關的 label / annotation。
2. 所有 container 現在都明寫 `imagePullPolicy`（Kubernetes 本來也會套用一樣的 default，明寫只是避免混淆）。

其他都沒改 — image tag、resource limits、volume mounts、環境變數、ports、兩份 100 行以上的 ConfigMap payload（`install-tools.sh`、`opencode.json`）— 都 byte-identical。

---

## License

見 [LICENSE](LICENSE)。
