# AI Supervisor Agent — Modul pre CloudOS

## Koncept

CloudOS AI Supervisor je nie "ešte jeden Docker kontajner", ale vrstva, ktorá **detekuje dostupné AI agenty** a dáva im kontext o CloudOS. Robí z CloudOS systému, ktorému AI rozumie a vie ho ovládať.

## Detekcia AI agentov

Pri `cloudos init` alebo `cloudos module add ai` sa spustí detekcia:

```
DETECTED AGENTS:
  ✓ Hermes Agent     (this session — CLI, cron jobs, skills)
  ✓ Docker AI plugin (docker-ai — Gordon CLI)
  ✗ OpenClaw         (not installed)
  ✗ Claude Code      (not installed)
  ✗ Copilot CLI      (not installed)
  ⚠ Ollama API       (running on :11434 — local LLM available)
```

### Čo detekujeme:
| Agent | Detekcia | API |
|-------|----------|-----|
| **Hermes Agent** | `hermes --version` | ACP protocol, cron, skills |
| **Docker Gordon** | `docker ai --help` | Docker AI plugin |
| **Ollama** | `curl :11434/api/tags` | REST API, local models |
| **Open WebUI** | `curl :3000/api/status` | REST API |
| **Claude Code** | `which claude` | CLI |
| **OpenClaw** | `which claw` | CLI |
| **Copilot CLI** | `which copilot` | ACP / CLI |

---

## Ako AI chápe CloudOS — "System Context Protocol"

Každý AI agent dostáva **štruktúrovaný kontext** o CloudOS, nie len "bež si čo chceš".

### 1. Mapa modulov (machine-readable)

```json
{
  "version": "0.1.0",
  "modules": {
    "base": { "status": "running", "services": ["netdata:9001", "cadvisor:8082", "watchtower"] },
    "auth": { "status": "running", "services": ["authentik:9000", "caddy:80", "postgres", "redis"] },
    "filesync": { "status": "running", "services": ["nextcloud:8081", "onlyoffice", "postgres"] },
    "search": { "status": "running", "services": ["searxng:4000", "meilisearch:7700"] },
    "dashboard": { "status": "running", "services": ["homer:8080"] },
    "ai": { "status": "stopped", "services": ["ollama:11434", "open-webui:3000"] },
    "photos": { "status": "stub", "services": [] }
  },
  "mesh": {
    "nodes": ["ubuntu (100.79.173.91)", "giganigga (100.77.7.48)", "rmx1911 (android)"],
    "syncthing": true
  }
}
```

Tento JSON sa generuje pri každom `cloudos status` a AI agent ho používa ako svoj "mozog".

### 2. Capabilities declaration

Každý modul deklaruje, čo AI môže robiť:

| Module | AI Capabilities |
|--------|----------------|
| `base` | Monitorovať health, reštartovať service-y, alertovať |
| `auth` | Spravovať používateľov, resetovať heslá, OIDC config |
| `filesync` | Spravovať súbory, zdieľania, používateľov |
| `search` | Indexovať, hľadať, spravovať search engines |
| `ai` | Volať Ollama modely, RAG, Hermes cron tasks |
| `photos` | Spravovať albumy, tagovať, vyhľadávať tváre |
| `dashboard` | Konfigurovať zobrazenie, pridávať služby |

### 3. Príkazový most (Command Bridge)

AI agent nepotrebuje SSH — komunikuje cez CloudOS API:

```bash
# Z pohľadu AI agenta:
cloudos module status photos         # "Je Immich hore?"
cloudos module logs photos           # "Ukáž mi chyby"
cloudos module restart photos        # "Reštartuj Immich"
cloudos supervisor diagnose          # "Čo je zlé?"
cloudos supervisor upgrade           # "Aktualizuj všetky moduly"
```

Hermes to už vie — stačí pridať `cloudos supervisor` subcommand.

---

## Architektúra

```
┌──────────────────────────────────────────────────────┐
│                    Hermes Agent                       │
│  (hlavný orchestrator — rozumie celej inštancii)     │
└──────────────────┬───────────────────────────────────┘
                   │ ACP / CLI
┌──────────────────▼───────────────────────────────────┐
│              CloudOS AI Supervisor                    │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │ Detector    │  │ Context Gen  │  │ Command    │  │
│  │ (agent scan)│  │ (system map) │  │ Dispatcher │  │
│  └─────────────┘  └──────────────┘  └────────────┘  │
└──────────────────┬───────────────────────────────────┘
                   │
    ┌──────────────┼──────────────────────┐
    ▼              ▼                      ▼
┌─────────┐  ┌──────────┐  ┌──────────────────────┐
│ Ollama  │  │ Docker   │  │ CloudOS moduly        │
│ (local  │  │ Gordon   │  │ (auth, filesync, ...) │
│  LLM)   │  │ (built-  │  │                      │
│         │  │  in AI)  │  │                      │
└─────────┘  └──────────┘  └──────────────────────┘
```

---

## Hermes cron — "Heartbeat" supervisor

```yaml
# Hermes cron job (definícia)
name: cloudos-heartbeat
schedule: "every 15m"
prompt: >
  Skontroluj CloudOS na Ubuntu 100.79.173.91:
  1. SSH a zisti, či všetky Docker kontajnery bežia
  2. Ak niečo padlo → reštartuj
  3. Skontroluj disk a RAM
  4. Ak je všetko OK → nič nehlás
  5. Ak je problém → napíš alert
```

A **Hermes skill** pre CloudOS operácie:

```
cloudos-deployment (skill) → obsahuje:
  - Presné príkazy na SSH, docker compose, healthcheck
  - Známe problémy a riešenia
  - Port mapping a credentials
```

---

## Ako to zapadá do CloudOS

### `modules/ai/` — už existuje, ale chýba supervisor logika

```yaml
# V modules/ai/docker-compose.yml už je:
services:
  ollama:          # ✅ local LLM
  open-webui:      # ✅ chat UI
  hermes-supervisor:  # ❌ STUB — treba dodefinovať
```

### Čo treba pridať:

1. **CloudOS CLI: `cloudos supervisor`**
   - `cloudos supervisor status` — stav všetkých AI agentov
   - `cloudos supervisor scan` — detekcia dostupných AI
   - `cloudos supervisor context` — vygeneruje JSON context mapu
   - `cloudos supervisor diagnose` — health check + self-heal

2. **`cloudos context` — JSON endpoint pre AI agentov**
   - Vracia kompletný system map (moduly, status, porty, credentials refs)
   - AI agenti ho čítajú pred každou operáciou

3. **Hermes skill: cloudos-supervisor**
   - Obsahuje: detekcia agentov, context generovanie, command bridge

4. **Ollama MCP / Function Calling** (voliteľné)
   - Ollama modelu dať tool definition pre `cloudos_*` funkcie
   - AI cez Open WebUI môže rovno commandovať CloudOS

---

## Príklad: čo spraví AI supervisor

```
User: "Pridaj fotky z Androidu do cloudu"

1. AI supervisor zistí:
   - Photos modul je "stub" — len module.yml
   - Ubuntu node má dosť miesta (468GB disk)
   
2. AI spustí:
   cloudos module add photos      # docker compose up
   
3. Po spustení:
   - Skontroluje Immich health
   - Otvorí port 2283
   - Povie userovi: "Immich beží na http://100.79.173.91:2283
     Nainštaluj Immich mobile app a zadaj server URL"
```

```
User: "Prečo mi nefunguje Nextcloud?"

1. AI supervisor zistí:
   - Nextcloud kontajner beží
   - Ale OIDC login vracia 500
   
2. Diagnóza:
   - user_oidc provider je zlý redirect URI
   
3. Fix:
   cloudos oidc fix --module nextcloud
   
4. Report:
   "Nextcloud OIDC mal zlý redirect URI. Opravené."
```

---

## Detekcia v `cloudos init`

Keď pustíš `cloudos init`, teraz by malo detekovať aj AI agenty:

```
CloudOS — Environment Detection

OS:        windows (amd64)
RAM:       31GB
GPU:       none
Docker:    running (v28.0.1)
Tailscale: 100.77.7.48
Services:  postgresql:5432, syncthing:8384, ...

AI Agents:
  ✓ Hermes Agent     (running — CLI + cron)
  ✓ Docker Gordon    (docker ai plugin)
  ✓ Ollama           (available on :11434)
  ✗ OpenClaw
  ✗ Claude Code

→ AI Supervisor capabilities: HERMES, DOCKER, OLLAMA
```

---

## Zhrnutie

| Layer | Čo | Stav |
|-------|----|------|
| **Detector** | Skener AI agentov v prostredí | ❌ Chýba |
| **Context** | JSON system map pre AI agentov | ❌ Chýba |
| **Supervisor CLI** | `cloudos supervisor {status,scan,diagnose}` | ❌ Chýba |
| **Hermes Skill** | Skill pre operácie CloudOS | ✅ exists (cloudos-deployment) |
| **Cron heartbeat** | Pravidelný healthcheck cez Hermes | ❌ Chýba |
| **Ollama MCP** | Funkcie pre local LLM | ❌ Chýba |
