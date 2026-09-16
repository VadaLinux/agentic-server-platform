# OmniRoute Deep Dive & Brainstorming Tecnico 🧠⚡

> Analisi architetturale, catalogo funzionalità avanzate e piano di integrazione per **OmniRoute** all'interno dell'**Agentic Server Platform**.
> Riferimento upstream: [diegosouzapw/OmniRoute](https://github.com/diegosouzapw/OmniRoute)

---

## 1. Cos'è OmniRoute e Perché è il Cuore del Nostro Stack

**OmniRoute** non è un semplice reverse-proxy per API LLM: è un **AI Gateway di livello enterprise** con motore di routing euristico, ottimizzazione semantica del contesto e gestione granulare delle quote.

All'interno dell'**Agentic Server Platform**, OmniRoute risolve i 4 problemi critici degli agenti autonomi:
1. **Rate Limit & Token Cap Downtime:** Passaggio trasparente tra provider equivalenti quando Claude o OpenAI vanno in `429 Too Many Requests`.
2. **Costi e Finestra di Contesto:** Abbattimento dei token fino al **95%** tramite stacking di compressione **RTK + Caveman**.
3. **Multi-Tenancy & Monetizzazione (SaaS 20€/mese):** Virtual API Keys con hard budget caps e token bucket per isolare i clienti.
4. **Integrazione Multi-Tool & MCP:** Singolo endpoint compatibile con **Hermes Agent, Claude Code, Codex, Cursor, Cline, Copilot, Aider e OpenCode**.

---

## 2. Matrice delle Funzionalità Avanzate di OmniRoute

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             OMNIROUTE CORE ENGINE                                │
├────────────────────────┬────────────────────────┬────────────────────────────────┤
│   ROUTING & COMBOS     │ COMPRESSION & CACHING  │     GOVERNANCE & TENANTS       │
├────────────────────────┼────────────────────────┼────────────────────────────────┤
│ • 352 AI Providers     │ • RTK Prompt Pruner    │ • Virtual API Keys             │
│ • 1312+ Model IDs      │ • Caveman Syntax AST   │ • Monthly / Daily Spend Caps   │
│ • 150+ Free Tiers      │ • Semantic Response DB │ • Token Limit Reset Cycles     │
│ • Auto-Combos          │ • Reasoning Replay     │ • Multi-Workspace Quota Pools  │
│ • Health Circuit Break │ • Zero-Latency Cache   │ • Live Usage Telemetry         │
└────────────────────────┴────────────────────────┴────────────────────────────────┘
```

---

### 2.1 Catalogo Provider & Free-Tier Stacking (~1.47B Token Gratuiti/Mese)
* **352 Provider Integrati:** Copertura globale di provider commerciali (Anthropic, OpenAI, Google Gemini, Mistral, Moonshot Kimi, Zhipu GLM, DeepSeek, MiniMax, Groq, Cerebras) e server locali (vLLM, Ollama, Triton, LM Studio).
* **Stacking di Free Tier:** OmniRoute aggrega e deduplica 444 entry di tier gratuiti (Mistral, Groq, Nara, LLM7, ecc.), permettendo fino a **~1.47 Miliardi di token gratuiti al mese** utilizzabili come fallback prima di toccare le API a pagamento.

---

### 2.2 Motore di Auto-Combos e Routing Intelligente
OmniRoute espone endpoint virtuali "combo" che astraggono il singolo modello:

| Virtual Model ID | Comportamento & Selezione Modelli | Caso d'Uso Tipico |
|---|---|---|
| `auto/best-coding` | Seleziona dinamicamente il modello con i punteggi di benchmark più alti per generazione codice (es. Claude 3.5 Sonnet → GPT-4o → DeepSeek V3) | Agenti di sviluppo (Hermes / Multica) |
| `auto/best-reasoning` | Indirizza verso modelli dotati di catena di pensiero estesa / reasoning tokens (o1, DeepSeek R1, QwQ) | Architettura, analisi requisiti |
| `auto/best-fast` | Massimizza il throughput (token/s) tramite engine a bassissima latenza (Groq LPU, Cerebras, SambaNova) | Triage veloce, completamento inline |
| `auto/best-vision` | Routing automatico verso modelli multimodali con supporto nativo a OCR e analisi immagini | Analisi screenshot e diagrammi |
| `auto/pro-coding` | Routing esclusivo su modelli di fascia frontier con massimi effort di thinking | Refactoring critico e sicurezza |

---

### 2.3 Compressione Semantica del Contesto (RTK + Caveman)
Una delle funzionalità più potenti di OmniRoute è la **pipeline di compressione a due stadi**:

1. **RTK (Real-Time Knowledge / AST Pruning):**
   * Riconosce la struttura del codice sorgente e rimuove commenti ridondanti, spaziature non significative e porzioni di file duplicate nello storico dei messaggi.
2. **Caveman Compression:**
   * Comprime il linguaggio naturale eliminando parole di riempimento e sintetizzando le istruzioni del prompt mantenendo inalterata l'accuratezza semantica.
3. **Risultato Misurato:** Risparmio medio del **30-50% sui token di input** (con picchi fino all'**89-95%** su file di codice massivi), raddoppiando di fatto la capienza effettiva del piano abbonamento.

---

### 2.4 Caching Semantico & Reasoning Replay
* **Semantic Response Cache:** Se un prompt o un'interrogazione identica viene ripetuta da agenti diversi, OmniRoute restituisce la risposta dalla cache SQLite/Redis con **latenza <5ms e 0 costi token**.
* **Reasoning Replay:** Memorizzazione dei passaggi logici intermedi generati dai modelli di reasoning per evitare di ricalcolare catene di pensiero già esplorate.

---

### 2.5 Multi-Tenancy, Virtual Keys & SaaS Billing (20€/mese)
OmniRoute include una gestione completa di account e chiavi virtuali:
* **Virtual API Keys:** Emette token `sk-omni-...` associati a uno specifico cliente o workspace.
* **Hard & Soft Limits:** Blocco automatico al raggiungimento del budget mensile (es. $20.00 USD) o del massimale token (es. 5M token).
* **Rate-Limiting a livello di chiave:** Limitazione delle richieste al minuto per impedire attacchi DoS o loop ricorsivi degli agenti.
* **Restrizione Modelli:** Possibilità di concedere l'accesso solo a determinati modelli o a determinati provider per tier di prezzo.

---

### 2.6 Integrazione nativa CLI & Protocolli MCP / A2A
* **`omniroute run <tool>`:** Avvia all'istante qualsiasi CLI con le credenziali del gateway iniettate al volo nel processo:
  ```bash
  omniroute run claude --model auto/best-coding
  omniroute run codex --model auto/best-coding
  ```
* **Protocollo MCP (Model Context Protocol):** Espone strumenti per il monitoraggio token, la diagnostica e l'interrogazione dello stato dell'inferenza direttamente negli agenti.
* **Protocollo A2A (Agent-to-Agent):** Canale di comunicazione standardizzato per consentire a due o più agenti di coordinarsi attraverso il gateway.

---

## 3. Brainstorming: Nuove Funzionalità da Sviluppare & Condividere

Per estendere ulteriormente la nostra **Agentic Server Platform**, ecco le aree ad alto impatto identificate nel brainstorming:

### 🚀 Idea 1: Hybrid Routing Alps CSCS ↔ Cloud Fallback
* **Concetto:** Configurare un nodo locale (vLLM / Triton) in esecuzione sui supercomputer CSCS Alps (GPU Grace Hopper) come provider primario a costo zero e massima sovranità dati.
* **Comportamento:** Se la GPU locale è occupata o satura la coda SLURM, OmniRoute fa fallback automatico sui provider cloud (Claude 3.5 / OpenAI) per non interrompere il lavoro degli agenti.

### 💰 Idea 2: Automated Stripe Webhook Billing Engine
* **Concetto:** Esporre un micro-endpoint webhook legato a Stripe/Paddle:
  1. Il cliente sottoscrive il piano da **20€/mese**.
  2. Il webhook chiama lo script `/opt/agentic-platform/scripts/manage_tenants.py`.
  3. Viene istanziato un workspace Multica dedicato e generata la Virtual Key OmniRoute con quota 5M token.
  4. Alla scadenza del mese o al mancato rinnovo, la chiave viene sospesa automaticamente.

### 📊 Idea 3: Dashboard Unificata Consumi per il Cliente Finale
* **Concetto:** Esporre una pagina utente in cui il cliente vede in tempo reale:
  * Token consumati / Token rimanenti nel mese.
  * Risparmio ottenuto grazie alla compressione RTK.
  * Modelli utilizzati e tempo medio di risposta.

### 🛡️ Idea 4: Prompt Firewall & Guardrails
* **Concetto:** Aggiungere un middleware su OmniRoute per bloccare l'esfiltrazione accidentale di segreti (token API, password, dati sensibili) prima che vengano inviati ai modelli cloud esterni.

---

## 4. Conclusioni e Prossimi Passi

OmniRoute trasforma l'infrastruttura da una semplice serie di chiamate API a una **piattaforma di inferenza resiliente, economica e monetizzabile**.

Tutti i componenti sono già integrati in Docker e operativi sulla nostra VPS di produzione su `https://ai-router.agentizzatori.com`.
