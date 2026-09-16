# Agentic Server Platform 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Kubernetes Ready](https://img.shields.io/badge/Kubernetes-Ready-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Cloudflare Zero Trust](https://img.shields.io/badge/Cloudflare-Zero%20Trust-F38020?logo=cloudflare&logoColor=white)](https://www.cloudflare.com/zero-trust/)

**Agentic Server Platform** is a production-grade, self-hosted, multi-tenant server architecture designed to run autonomous AI coding agents, intelligent multi-model LLM routing, token quota governance, and workspace orchestration 24/7 with zero downtime.

---

## 🏛️ High-Level Architecture

```text
                                [ User / Browser / Desktop Client ]
                                                 │
                                                 ▼ HTTPS / WSS
                       ┌──────────────────────────────────────────────────┐
                       │           Cloudflare Zero Trust Ingress          │
                       │   (Zero Open Inbound Ports, DDoS & WAF Guard)    │
                       └─────────────────────────┬────────────────────────┘
                                                 │ Cloudflare Tunnel
                                                 ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Host / Cluster Environment (Ubuntu 26.04 LTS / Kubernetes)                                      │
│                                                                                                 │
│  ┌─────────────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────────┐  │
│  │      Multica Server     │   │      OmniRoute Gateway   │   │     Hermes Agent Runtime     │  │
│  │ ─────────────────────── │   │ ──────────────────────── │   │ ──────────────────────────── │  │
│  │ • Frontend UI (:3000)   │   │ • Token Metering & Quotas│   │ • Autonomous Code & Ops Exec │  │
│  │ • Backend API (:8080)   │──►│ • Multi-Key / Multi-Host │◄──│ • Built-in Python 3.11 Tools │  │
│  │ • PostgreSQL + pgvector │   │ • RTK Token Compression  │   │ • 58 Bundled Platform Skills │  │
│  │ • 24/7 Background Daemon│   │ • Smart Fallback Routing │   │ • Persistent Cross-Turn State│  │
│  └─────────────────────────┘   └─────────────┬────────────┘   └──────────────────────────────┘  │
│                                              │                                                  │
│                                              ▼ OpenAI / Anthropic Compatible Wire               │
│                                 ┌──────────────────────────────┐                                │
│                                 │ Multi-Provider Inference Pool│                                │
│                                 │ • Claude 3.5 / Opus 4.6      │                                │
│                                 │ • OpenAI GPT-4o / Codex      │                                │
│                                 │ • DeepSeek V3 / R1 / Groq    │                                │
│                                 │ • On-Prem Local vLLM (Alps)  │                                │
│                                 └──────────────────────────────┘                                │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 💡 Key Capabilities

### 1. Resilient LLM Gateway & Quota Engine (OmniRoute)
* **Automatic Failover:** Transparent model and provider fallback when encountering rate-limits (`429`) or provider outages.
* **Semantic Token Compression (RTK):** Up to 30-50% reduction in prompt tokens via intelligent deduplication and AST pruning.
* **Virtual API Keys:** Isolated keys per tenant/workspace with spend caps, daily limits, and monthly quota resets.

### 2. Multi-Tenant Workspace Orchestration (Multica)
* **Full Project & Issue Tracking:** Native support for long-running autonomous workflows, sub-issues, and multi-agent coordination.
* **Dedicated Daemon (24/7):** Run headless agent tasks, nightlies, ingestion jobs, and automated PR reviews without keeping local workstations powered on.
* **Pgvector Integration:** Vector-native PostgreSQL 17 storage for workspace memory and retrieval-augmented generation.

### 3. Native Agent Runtime (Hermes Agent)
* **Pre-bundled Toolkit:** Over 58 curated skills (refactoring, terminal sandboxes, web retrieval, git worktree isolation, system diagnosis).
* **Deterministic Execution:** Managed Python 3.11 environment with SQLite 3.53+ corruption-safe storage.

### 4. Zero-Trust Security & Hardening
* **Zero Public Port Exposure:** The server runs with standard ports blocked by UFW; all ingress routes via encrypted `cloudflared` QUIC tunnels.
* **SSH Hardening:** Strict key-only access (`ed25519`), root login disabled, fail2ban brute-force protection.

---

## 💳 SaaS & Business Model Blueprint (20€ / Month Tier)

The platform provides a plug-and-play credit allocation mechanism:

| Feature | Starter Tier (20 €/month) | Enterprise / Dedicated Tier |
|---|---|---|
| **Monthly Token Allocation** | 5,000,000 Tokens | Custom / Unlimited Quota |
| **Daily Hard Spend Cap** | $0.77 USD / day | Custom |
| **Concurrency & Rate Limit** | 60 req/min · 2,000 req/day | High Throughput Dedicated Pool |
| **Compression Engine** | Enabled (RTK Prompt Compressor) | Enabled + Custom Filtering |
| **Workspace Isolation** | Dedicated Workspace + Key | Multi-Workspace + Single Sign-On |
| **Inference Models** | Claude 3.5, GPT-4o, DeepSeek V3 | All Models + On-Prem Alps/vLLM |

Tenants can be provisioned in one command:
```bash
python3 scripts/manage_tenants.py create "Acme-Corp"
```

---

## 🚀 Quickstart & Deployment

### Prerequisites
* Linux Server (Ubuntu 24.04 / 26.04 LTS or Debian 12)
* Docker Engine 24+ & Docker Compose v2+
* Domain registered on Cloudflare (with Cloudflare Zero Trust active)

### 1. Bootstrap Server & Hardening
```bash
chmod +x scripts/bootstrap_vps.sh
./scripts/bootstrap_vps.sh
```

### 2. Launch Unified Docker Stack
```bash
cd docker
docker compose up -d
```

### 3. Connect Cloudflare Tunnel
```bash
sudo cloudflared service install <YOUR_TUNNEL_TOKEN>
```

---

## 📁 Repository Structure

```text
agentic-server-platform/
├── README.md                     # Platform documentation & architecture
├── LICENSE                       # MIT License
├── docs/
│   └── relazione_tecnica.md      # Detailed engineering report & migration log
├── docker/
│   ├── docker-compose.yml        # Multi-service stack (OmniRoute, Multica, Postgres)
│   └── omniroute/
│       ├── Dockerfile            # Container definition for OmniRoute gateway
│       └── entrypoint.sh         # Network bridge & entrypoint
├── scripts/
│   ├── bootstrap_vps.sh          # One-click Ubuntu server hardening & setup
│   ├── manage_tenants.py         # Tenant, credit, and Virtual Key manager
│   └── backup_restore.sh         # Snapshot and migration playbook
└── k8s/
    └── manifests/                # Kubernetes readiness manifests (Rancher/OpenShift)
```

---

## 📄 License
Licensed under the [MIT License](LICENSE). Built for enterprise scalability and sovereign agentic AI workloads.
