# CloudOS — Audit a Návrh Zlepšení (v0.1.0 → v0.2.0)

Dátum: 2026-07-02
Audit: CLI, moduly, Docker, dokumentácia, architektúra

---

## 1. ČO JE ROZBITÉ / CHÝBA (technický dlh)

### 🔴 Kritické

| # | Problém | Dôsledok |
|---|---------|----------|
| 1 | **Legacy root dirs** (~/cloudos/ai/, auth/, ...) sú prázdne, ale CLI ich hľadá PRED modules/ | `cloudos module add` hľadá najprv legacy cestu, zbytočný kód |
| 2 | **`cloudos.yml` neukladá stav modulov** — `modules: {}` je vždy prázdne | CLI nevie povedať ktoré moduly sú naozaj deployed |
| 3 | **No Docker healthchecks** v auth, filesync, search, dashboard, photos compose | Immich healthcheck je, ale ostatné nie — kontajner môže byť "hore" ale nefunkčný |
| 4 | **Profiles.yml používá neštandardný YAML** — list namiesto mapy | Parser v cmd_profile je krkolomný, ľahko sa rozbije |

### 🟡 Dôležité

| # | Problém | Dôsledok |
|---|---------|----------|
| 5 | **`cloudos module add` stále preferuje legacy cesty** | Ak v budúcnosti vznikne modul v oboch cestách, legacy vyhrá |
| 6 | **Templates sú prázdne** — `templates/docker-compose/` je empty dir | Nikto nevie rýchlo vytvoriť nový modul |
| 7 | **Chýba `cloudos module remove`** | Modul sa nedá odinštalovať |
| 8 | **Chýba `cloudos module logs`** | Diagnostika = `docker logs` manuálne |
| 9 | **No resource limits v compose** — ani jeden modul nemá `deploy.resources.limits` | Jeden modul môže vyžrať všetku RAM |
| 10 | **No Docker labels na portoch** — dashboard/ auth/ filesync nemajú labels na všetkých service-och | Auto-discovery nefunguje spoľahlivo |

### 🟢 Kozmetické / Chýbajúce

| # | Problém |
|---|---------|
| 11 | README nemá logo, badge, ani "Quick start" sekciu |
| 12 | Žiadne `.github/workflows/` — CI/CD chýba |
| 13 | Žiadne `CONTRIBUTING.md` — nikto nevie ako pridať modul |
| 14 | `cloudos setup docker` na Windowse len píše "use Docker Desktop" — mohol by ho aj spustiť |
| 15 | Plánovacie dokumenty (PLAN.md, AI-SUPERVISOR.md) sú v koreni repo — mali by byť v `docs/` |
| 16 | Photos modul závisí na `auth` a `ai` — ale module.yml aj compose to ignorujú pri štarte |

---

## 2. NÁVRH: REFAKTORING NA v0.2.0

### Fáza 0 — Vyčistenie (30 min)

```bash
# 1. Zmazať prázdne legacy root dirs
rm -rf ai/ auth/ filesync/ photos/ search/

# 2. Premenovať cloudos → cloudos.sh (aby nekolidoval s cloudos.yml)
mv cloudos cloudos.sh

# 3. Presunúť plánovacie docs do docs/
mkdir -p docs
mv PLAN.md docs/
mv AI-SUPERVISOR.md docs/

# 4. Vytvoriť templates
cat > templates/docker-compose/module.yml << 'EOF'
name: "{{module_name}}"
description: "{{description}}"
version: "0.1.0"
depends: []
ports:
  - "{{port}}:{{port}}"
resources:
  min_ram_mb: 512
  min_disk_gb: 1
features:
  - {{feature}}
EOF
```

### Fáza 1 — CLI vylepšenia

#### 1.1 Odstrániť legacy cesty z CLI

V `cloudos.sh` v `cmd_module()` a `cmd_profile()`:
```
-  local module_lib="${CLOUDOS_ROOT}/${module}/setup.sh"   # ← ZMAZAŤ
+  local module_setup="${CLOUDOS_ROOT}/modules/${module}/setup.sh"
```

#### 1.2 Sledovať stav modulov v cloudos.yml

Po `module add` zapísať do `cloudos.yml`:
```yaml
modules:
  installed:
    photos:
      version: "0.1.0"
      status: running
      installed_at: "2026-07-02T20:00:00Z"
```

Potom `cloudos status` ukáže nielen Docker kontajnery, ale aj:
```
Modules:
  base      ✅ running
  auth      ✅ running
  photos    ✅ running (Immich v3.0.0)
  ai        ❌ not installed
```

#### 1.3 Nové príkazy

```bash
cloudos module remove photos    # docker compose down + vymaže z configu
cloudos module logs photos      # docker compose logs
cloudos module restart photos   # docker compose restart
cloudos module update photos    # docker compose pull + up -d
```

### Fáza 2 — Docker compose kvalita

#### 2.1 Pridať healthchecks do všetkých modulov

```yaml
# VZOR pre každý service:
healthcheck:
  test: curl -f http://localhost:PORT/ || exit 1
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

#### 2.2 Pridať resource limits

```yaml
deploy:
  resources:
    limits:
      memory: "2G"
    reservations:
      memory: "512M"
```

#### 2.3 Jednotné labels

```yaml
labels:
  cloudos.module: "auth"
  cloudos.service: "authentik-server"
  cloudos.port: "9000"
  cloudos.icon: "authentik"
```

### Fáza 3 — Setup.sh štandardizácia

Každý `setup.sh` by mal:

| Krok | Čo | Príklad |
|------|----|---------|
| 1 | Detekovať či už beží | `docker ps --filter name=cloudos-*` |
| 2 | Generovať .env ak chýba | `openssl rand ...` |
| 3 | Pull images | `docker compose pull` |
| 4 | Spustiť | `docker compose up -d` |
| 5 | Počkať na healthcheck | `curl --retry 10 ...` |
| 6 | Zaregistrovať do cloudos.yml | `yq write ...` |
| 7 | Vytvoriť admin účet (cez API) | `curl -X POST /api/auth/signup` |

**Photos setup.sh momentálne robí 1-5, chýba 6-7.**

### Fáza 4 — Profily

#### 4.1 Opraviť profiles.yml na štandardný YAML

```yaml
profiles:
  mini:
    description: "Minimal setup — RPi Zero 2"
    ram: 1
    modules: [base]
  
  household:
    description: "Full home cloud"
    ram: 8
    modules: [base, auth, filesync, photos]
```

Parsovanie potom:
```bash
yq eval '.profiles.mini.modules[]' profiles.yml
# Namiesto: while IFS= read -r line; do ...
```

### Fáza 5 — AI Supervisor (z AI-SUPERVISOR.md)

#### 5.1 CLI: `cloudos supervisor`

```bash
cloudos supervisor scan      # Detekcia AI agentov (Hermes, Ollama, Docker Gordon...)
cloudos supervisor context   # JSON system map pre AI agentov
cloudos supervisor diagnose  # Health check všetkých modulov
```

#### 5.2 Hermes cron heartbeat

```bash
hermes cron create \
  --name cloudos-heartbeat \
  --schedule "every 15m" \
  --prompt "Skontroluj CloudOS, ak je niečo zlé, reportuj"
```

#### 5.3 Detekcia v `cloudos init`

```
AI Agents:
  ✓ Hermes Agent     (ACP, cron, skills)
  ✓ Ollama           (localhost:11434)
  ✓ Docker Gordon    (docker ai)
  ✗ OpenClaw
  ✗ Claude Code
```

### Fáza 6 — Windows DX

```bash
cloudos setup docker
# Namiesto: "use Docker Desktop" → skutočne ho spustí:
# "/c/Program Files/Docker/Docker/Docker Desktop.exe"
# a počká kým je docker responsive
```

```bash
cloudos setup autostart
# Pridá Docker Desktop do Windows Startup
```

---

## 3. PRIORITY A ODHAD ČASU

| Priorita | Čo | Čas | Závisí na |
|----------|----|-----|-----------|
| 🔴 P0 | Vyčistenie legacy dirs + templates | 30 min | — |
| 🔴 P0 | Odstrániť legacy cesty z CLI | 15 min | P0.1 |
| 🔴 P0 | Healthchecks do compose (auth, filesync, search) | 20 min | — |
| 🟡 P1 | `module remove` + `module logs` + `module restart` | 1h | P0.2 |
| 🟡 P1 | Sledovanie stavu v cloudos.yml | 1h | P0.2 |
| 🟡 P1 | Resource limits do compose | 30 min | — |
| 🟡 P1 | Profiles.yml na štandardný YAML | 30 min | — |
| 🟢 P2 | Setup.sh API auto-config (Immich admin, ...) | 2h | — |
| 🟢 P2 | `cloudos supervisor scan` | 1h | — |
| 🟢 P2 | Windows DX: docker autostart | 30 min | — |
| 🔵 P3 | CI/CD (GitHub Actions) | 1h | — |
| 🔵 P3 | Logo + README refresh | 30 min | — |
| 🔵 P3 | docs/ organizácia | 15 min | — |

---

## 4. ČO NEROBÍME (vedomé rozhodnutia)

| Vec | Prečo nie |
|-----|-----------|
| **Web UI** | Zatiaľ stačí Homer/Homepage dashboard. Web UI = ďalší projekt |
| **Vlastný package manager** | Docker compose je dosť. Žiadny Helm/Ansible |
| **CloudOS DSL** | Bash + YAML je univerzálny, netreba custom jazyk |
| **Android app** | Syncthing + Immich app už existujú |
| **Cross-platform inštalátor** | `cloudos setup docker` + `git clone` je dosť jednoduché |

---

## 5. OKAMŽITÉ KROKY (čo spravím hneď)

1. **Zmazať legacy root dirs** — žiadny kód v nich nie je
2. **Odstrániť legacy cesty z CLI** — `cmd_module` a `cmd_profile` nech hľadajú len `modules/`
3. **Pridať healthchecks** do auth, filesync, search compose
4. **Pridať resource limits** do všetkých compose
5. **Presunúť docs** do `docs/`
6. **Spraviť `module remove`** (základná verzia)

Chceš aby som začal? Alebo chceš najprv diskutovať niektorý bod?
