# Relazione Tecnica: Progettazione, Implementazione e Deploy di "Agentic Server Platform"

**Data:** 16 Settembre 2026  
**Autore / Architetto:** Gabriele Vadalà (con l'assistenza dell'agente orchestratore Mika)  
**Ambiente:** VPS KVM 4 (Hostinger Datacenter Francoforte) & Kubernetes Ready (Rancher)  
**Dominio di Produzione:** `agentizzatori.com`  

---

## 1. Executive Summary & Obiettivi di Business

Il progetto **`agentic-server-platform`** nasce per risolvere in modo strutturale e definitivo le limitazioni operative legate al consumo dei token LLM (rate-limiting, saturazione dei tier commerciali Claude/OpenAI) e alla dipendenza dalla workstation locale per l'esecuzione di agenti autonomi.

L'architettura unifica tre componenti open-source ed enterprise in un unico stack scalabile:
1. **OmniRoute (LLM Gateway / Router):** Gestione intelligente dell'inferenza, failover trasparente multi-provider, accounting granulare dei token e compressione semantica.
2. **Multica (Piattaforma di Orchestrazione Workspace):** Gestione gerarchica di progetti, issue, sub-agenti specializzati e scheduler 24/7 tramite daemon persistente.
3. **Hermes Agent (Runtime Agentico Autonomo):** Esecutore operativo su Python 3.11 con supporto a 58 skill, sandboxing di codice, MCP e accesso shell.

È stato inoltre integrato un **modello di business SaaS a crediti** (es. base 20€/mese per 5.000.000 di token) con virtual key isolate per cliente.

---

## 2. Dettaglio delle Fasi di Implementazione

### Fase 1: Provisioning e Automazione VPS via Hostinger MCP
* **Infrastruttura:** Attivata una nuova VPS dedicata (ID `1984501`, Sottoscrizione `16CHMqVVMj7APset`) tramite chiamate dirette al server Hostinger MCP (`billing_createPurchaseOrderV1` e `VPS_setupPurchasedVirtualMachineV1`).
* **Specifiche Hardware:** Piano **KVM 4** (4 vCPU, 16 GB RAM, 200 GB NVMe, 300 Mbps) nel datacenter di **Francoforte (Germania)**.
* **Sistema Operativo:** **Ubuntu 26.04.1 LTS** con Kernel Linux 7.0.
* **Accesso Iniziale:** Iniezione automatica della chiave pubblica SSH `id_ed25519`.

---

### Fase 2: Hardening & Sicurezza del Server
1. **Aggiornamento Pacchetti:** Aggiornamento completo del repository e dei pacchetti di sistema.
2. **Creazione Utente Dedicato:** Creato l'utente di sistema `gavadala`, disabilitando l'accesso SSH diretto per l'utente `root` (`PermitRootLogin no`).
3. **Privilegi & Sudo:** Assegnati i permessi di amministrazione passwordless a `gavadala` (`/etc/sudoers.d/gavadala`) ed inclusione nel gruppo `docker`.
4. **SSH Security:** Autenticazione con password disabilitata (`PasswordAuthentication no`), accesso consentito solo via chiave pubblica `ed25519` per l'utente autorizzato (`AllowUsers gavadala`).
5. **Firewall UFW & Fail2ban:**
   * Policy di default: `deny incoming`, `allow outgoing`.
   * Porte aperte sul firewall locale: `22/tcp` (SSH), `81/tcp` (CasaOS).
   * Fail2ban attivo con monitoraggio tentativi brute-force.

---

### Fase 3: Backup Deterministico & Ripristino Dati Locali
Per garantire continuità operativa, lo stato locale è stato esportato e migrato sulla VPS:
* **Database Multica:** Eseguito dump PostgreSQL formato custom (`pg_dump -F c`) dal container locale `multica-postgres-1` e ripristinato sul nuovo container `pgvector/pgvector:pg17`.
* **Configurazioni e Profili:** Trasferite le directory `~/.multica` (workspace `VadaLinux`, token e sessioni) e `~/.omniroute` (`storage.sqlite`, regole di routing, connessioni a Claude, OpenAI, Antigravity, OpenRouter).

---

### Fase 4: Containerizzazione Docker dello Stack
Tutti i componenti sono stati unificati in `/opt/agentic-platform/stack/docker-compose.yml` su una rete bridge isolata `agentic-net`:

1. **OmniRoute Container (`omniroute:local`):**
   * Immagine personalizzata basata su Node.js 22 Slim con supporto a toolchain nativa e proxy socat interno.
   * Esposizione porta `127.0.0.1:20128`.
   * Volume persistente `/data` agganciato a `/home/gavadala/.omniroute`.
2. **Multica PostgreSQL (`pgvector/pgvector:pg17`):**
   * Database relazionale e vettoriale per memoria e metadati, esposto solo su `127.0.0.1:5432`.
3. **Multica Backend (`ghcr.io/multica-ai/multica-backend:latest`):**
   * Motore REST, WebSocket e Daemon hub su porta `127.0.0.1:8080` (e `8081`).
   * Configurato per usare `http://omniroute:20128/v1` come provider LLM interno.
4. **Multica Web Frontend (`ghcr.io/multica-ai/multica-web:latest`):**
   * Interfaccia Next.js su porta `127.0.0.1:3000`.

---

### Fase 5: Ingress Zero Trust con Cloudflare Tunnel
È stato installato e configurato il demone `cloudflared` con routing su dominio **`agentizzatori.com`**:

| URL Pubblico | Servizio Interno | Funzionalità |
|---|---|---|
| **`https://multi-agent.agentizzatori.com`** | `http://localhost:3000` | Frontend Web Multica per interazione utente |
| **`https://multi-agent.agentizzatori.com/health`** | `http://localhost:8080` | Backend API & Daemon endpoint |
| **`https://multi-agent.agentizzatori.com/ws`** | `http://localhost:8080` | WebSocket per streaming task real-time |
| **`https://ai-router.agentizzatori.com`** | `http://localhost:20128` | Dashboard & Gateway API OmniRoute |

*Nessuna porta applicativa è aperta pubblicamente su internet; tutto il traffico attraversa i tunnel crittografati Cloudflare con protezione WAF, DDoS e possibilità di policy OIDC/Access.*

---

### Fase 6: Runtime Hermes & Daemon Autonomo 24/7
1. **Hermes Agent (v0.21.3):** Installato via installer ufficiale con interprete isolato **Python 3.11.16** e libreria **SQLite 3.53.1** (esente da bug di corruzione).
2. **Collegamento a OmniRoute:** `config.yaml` impostato con provider `custom`, endpoint `http://127.0.0.1:20128/v1` e modello `auto/best-coding`.
3. **Multica Daemon Systemd:** Creato il servizio `multica-daemon.service` che avvia il processo di polling continuo dei task e aggancia Hermes come runtime ACP.

---

### Fase 7: Modello di Governance Token & Multi-Tenancy (20€/mese)
Sviluppato lo strumento di gestione `/opt/agentic-platform/scripts/manage_tenants.py` per emettere Virtual API Key per ogni cliente:
* **Cap Mensile:** 5.000.000 di token con reset a cadenza mensile.
* **Budget Cap:** Limite di spesa bloccato a $20.00 USD/mese ($0.77/giorno).
* **Rate Limit:** 60 richieste/minuto, 2.000 richieste/giorno per prevenire abusi o loop infiniti.
* **Compressione Semantica (RTK):** Attiva di default per abbattere i costi di contesto del 30-50%.

---

## 3. Stato di Verifica e Risultati del Test

* **Healthcheck Backend Multica:** `{"status":"ok","pid":1,"started_at":"2026-09-16T09:21:20Z"}` via HTTPS.
* **Web UI Multica:** `HTTP/2 200 OK` su `https://multi-agent.agentizzatori.com`.
* **OmniRoute Dashboard:** `HTTP/2 307 Redirect` su `https://ai-router.agentizzatori.com`.
* **Test Inferenza Hermes:** Eseguito test one-shot con risposta corretta attraverso il gateway locale.
* **Tenant Demo:** Creata con successo la prima chiave cliente `Workspace-Cliente-Alpha`.

---

## 4. Roadmap di Evoluzione (Kubernetes / Rancher / Alps)

1. **Fase 2 K8s:** Traduzione del `docker-compose.yml` in Helm Chart per cluster Rancher / K3s su nodi multipli.
2. **Integrazione Alps CSCS:** Aggiunta di endpoint di inferenza on-premise (vLLM / Triton) nel pool di provider OmniRoute per instradare workload ad alte prestazioni direttamente su GPU Grace Hopper.
3. **Automazione Billing:** Integrazione webhook Stripe per la creazione automatica delle Virtual Key e rinnovo quote all'avvenuto pagamento.
