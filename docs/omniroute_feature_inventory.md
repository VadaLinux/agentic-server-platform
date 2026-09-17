# Indice delle Funzionalità OmniRoute: Utilizzo Reale, Gap e Roadmap di Attivazione

Ricognizione approfondita della superficie di **OmniRoute v16.3.1** sull'installazione di produzione/locale `VadaLinux.lan`, con misurazione empirica di cosa è effettivamente in uso rispetto alle capacità nominali della piattaforma.

**Metodo:** Enumerazione dei comandi da `omniroute --help` e dai sottocomandi; stato d'uso misurato su `~/Sviluppo/.omniroute/storage.sqlite` (132 tabelle) e sui log applicativi. Nessuna funzionalità è descritta per sentito dire: dove non è presente una misura diretta, è indicato `[non verificato]`.

**Data rilevazione:** 2026-09-17  
**Versione:** CLI 3.8.50, Server v16.3.1  

---

## 1. Il Dato Chiave di Sintesi

| Misura | Valore |
|---|---|
| Comandi di primo livello CLI | **86** |
| Tabelle nel database SQLite | **132** |
| Tabelle **vuote** | **98 (74%)** |
| Chiamate registrate totali | **1394** |
| Di cui health-check interni (`model='connection-test'`) | **1078 (77%)** |
| **Traffico applicativo reale** | **316 chiamate** |

> **Osservazione architetturale:** La piattaforma opera oggi su una frazione minima del suo potenziale. Il 77% del traffico registrato consiste in auto-diagnostica e health-check interni. Questa asimmetria rappresenta un significativo margine di ottimizzazione e abilitazione funzionale a costo zero.

---

## 2. Funzionalità Attualmente in Uso (Misurate)

### 2.1 Routing Multi-Provider
Cinque provider risultano censiti in `provider_connections`: `claude`, `codex`, `antigravity`, `openrouter`, `opencode`.

La distribuzione del traffico reale è fortemente sbilanciata su un unico provider:
* **Antigravity (`gemini-3.7-flash-high`):** 277 chiamate — 69.9M token in / 104k token out.
* **Antigravity (`gemini-3.1-pro-low`):** 2 chiamate — 14k token.
* **Opencode (`big-pickle`):** 2 chiamate.
* **Auto (`auto/best-coding`):** 5 chiamate (routing dinamico esercitato).

Gli altri provider compaiono quasi esclusivamente in chiamate di `connection-test`.  
**Esito chiamate complessive:** 1376 `200 OK`, 9 `499`, 4 `429 Too Many Requests`, 2 `400 Bad Request`, 2 `403 Forbidden`, 1 `402 Payment Required`.

### 2.2 Server MCP Integrato
* `MCP server running (streamable-http)`: Canale attivo per l'esposizione di strumenti e diagnostica verso gli agenti.

### 2.3 Logging, Telemetria e Session Intelligence
Il sottosistema di telemetria è il più ricco e popolato:
* `call_logs` (1394 record), `proxy_logs` (1386 record), `usage_history` (308 record), `quota_snapshots` (964 record), `domain_cost_history` (273 record), `conversation_turn_nodes` (1788 record), `session_model_history` (550 record), `model_intelligence` (100 record).
* `audit_log` (14 record): attivo ma sottoutilizzato.

### 2.4 Job Schedulati Interni
| Job | Stato | Funzione |
|---|---|---|
| `budget_reset` | Abilitato | Reset periodico dei contatori di budget/quota |
| `token_health_check` | Abilitato | Verifica periodica della validità dei token provider (genera il 77% del volume log) |
| `warmup` | Disabilitato | Preriscaldamento delle connessioni upstream |

### 2.5 Resilienza e Circuit Breaker
Configurazione automatica attiva di default:
* **Rate limit:** 60 req/min.
* **Concorrenza:** 6 richieste concorrenti per slot.
* **Soglia Breaker:** 8 errori consecutivi su OAuth, 12 su API Key standard.
* Cooldown e accodamento su combo attivi.

### 2.6 Gestione Credenziali e Multi-Account
Gestione di credenziali distinte su `provider_connections` (account principale e secondario) e una master key in `api_keys` ("Chiave Master").

---

## 3. Matrice delle Funzionalità Disponibili Non Attive (per Priorità)

### 🔴 Priorità Alta: Alto Ritorno Immediato

1. **Caching Semantico (`cache` + `semantic_cache`):**
   * *Stato:* Tabella `semantic_cache` vuota; 100% delle chiamate registrate con `cache_source='upstream'`.
   * *Opportunità:* Con 69.9M token in ingresso su un singolo modello, il caching di prompt ripetitivi e turni di contesto idempotenti è l'ottimizzazione a maggior impatto economico e di latenza (<5ms).
2. **Compressione del Contesto (`compression` / `context-eng` - Caveman, RTK):**
   * *Stato:* Zero record con `tokens_compressed > 0`.
   * *Opportunità:* Il rapporto asimmetrico input/output (69.9M in vs 104k out) rende l'AST code pruning e la sintassi Caveman ideali per abbattere i token in ingresso del 30-50%.
3. **Memoria Condivisa (`memory` - FTS5 + Vettoriale):**
   * *Stato:* Tabella `memories` a 0 righe (health check `working: true, latencyMs: 2`). Supporto a `factual`, `episodic`, `procedural`, `semantic`.
   * *Criticità aperta:* Bug su `omniroute memory add` da CLI (errore 400 per `api_key_id NOT NULL` non valorizzato dal client). L'estrazione automatica (`MEMORY_EXTRACTION`) resta attivabile a livello di gateway.
4. **Governance Quote e Crediti (`usage budget` / `quota`):**
   * *Stato:* `quota_pools`, `quota_allocations`, `token_ledger`, `api_key_token_limits` vuote.
   * *Opportunità:* Fornisce nativamente l'infrastruttura di gestione per il piano SaaS a 20€/mese (VDLP-57), evitando riscritture esterne.

### 🟡 Priorità Media: Scalabilità e Multi-Tenancy

* **`policy` (Autorizzazioni & RBAC):** Tabelle per valutazione granulare (`evaluate`), export/import di policy dichiarative.
* **`webhooks`:** Sistema di notifiche push asincrone per eventi di soglia quota, circuit break o completion.
* **`eval` (Benchmark Suite):** Modulo `eval_suites`, `eval_runs`, `eval_cases`, `scorecard` per misurare oggettivamente le prestazioni dei modelli sul codice.
* **`skills`:** Runtime di skill lato gateway (con sandbox e marketplace).
* **`sync` (Sincronizzazione Istanze):** Comandi `push`/`pull`/`diff`/`bundle` per allineare configurazioni tra server on-prem e VPS remota.
* **`tunnel` (Cloudflare Ingress):** Gestione integrata del demone `cloudflared` (PID attivo sul binario gestito).

### 🟢 Priorità Bassa / Moduli Specialistici

* `a2a` (Agent-to-Agent protocol server), `batches` (batch processing OpenAI-compatible), `files` (storage asset), `oneproxy` (upstream proxy pool), `radar`, `packs`, `plugin`, `tags`, `cloud`, `translator`, `pricing`, `nodes`.

### Supporto Integrazioni Tooling CLI
14 integrazioni presenti (`setup-claude`, `setup-codex`, `setup-opencode`, `setup-cline`, `setup-kilo`, `setup-continue`, `setup-cursor`, `setup-roo`, `setup-crush`, `setup-goose`, `setup-aider`, `setup-qwen`, `launch`, `run`).  
Rilevati installati sull'host: **Claude Code 2.1.274**, **Codex CLI 0.154.0**, **Hermes v0.21.3**.

---

## 4. Difetti Aperti Rilevati

1. **`omniroute memory add` CLI 400 Error:** Fallisce per mancata fornitura dell'attributo `api_key_id` richiesto dal vincolo SQLite `NOT NULL`.
2. **Token OAuth Claude non rinnovabile:** Errore `invalid_grant` ("Refresh token not found or invalid"). Richiede re-autenticazione manuale dell'account.
3. **Reporting cosmetico `omniroute status`:** Mostra `Version: unknown` e `Config Dir: Not found` pur con demone operativo.
4. **Interrogazione `cache status`:** Riporta `Cache stats not available` nonostante la presenza di record in `cache_metrics`.

---

## 5. Piano d'Azione Consigliato

1. **Instradamento Completo del Traffico Workspace:** Configurare tutti gli agenti Multica e Hermes per passare obbligatoriamente da `http://127.0.0.1:20128/v1` con Virtual API Keys dedicate.
2. **Abilitazione di Cache Semantica e Compressione RTK:** Monitorare l'abbattimento token su una settimana di carico reale.
3. **Risoluzione Anomalie Credenziali & CLI:** Re-autenticare il provider Claude e patchare/aggirare il parametro `api_key_id` su `memory add`.
4. **Allineamento VDLP-57:** Sfruttare lo schema nativo di `quota_pools` e `token_ledger` per l'implementazione del tier SaaS a 20€/mese.
